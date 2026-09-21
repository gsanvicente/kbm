import 'http/kbm_backend_client.dart';
import 'models/card_network.dart';
import 'models/card_status.dart';
import 'models/cardholder_session.dart';
import 'models/ledger_entry_type.dart';
import 'models/ledger_movement.dart';
import 'models/payment_card.dart';
import 'models/shared/auth_exception.dart';
import 'models/shared/insufficient_funds_exception.dart';
import 'models/shared/too_many_failed_attempts_exception.dart';
import '../features/auth/cardholder_auth_repository.dart';
import '../features/cards/card_repository.dart';
import '../features/transfer/transfer_repository.dart';

/// Implementación real de las tres interfaces (auth, tarjetas,
/// transferencias) contra el backend compartido con `admin/` — ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
/// Reemplaza a `FakeCardholderBackend`, que sigue viviendo en el árbol
/// para los widget tests (`flutter test` intercepta todo `HttpClient` y
/// siempre responde 400 — un backend real es imposible de ejercer ahí,
/// ver `app/app.dart`).
///
/// El PAN completo viaja en claro hacia `/v1/transfers/resolve` — el
/// backend calcula su HMAC ahí, esta clase ya no lo hace (a diferencia
/// de `FakeCardholderBackend`, que sí lo simulaba en Dart). Ver
/// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md.
class HttpCardholderBackend implements CardholderAuthRepository, CardRepository, TransferRepository {
  HttpCardholderBackend(this.client);

  final KbmBackendClient client;

  PaymentCard _fromCardJson(Map<String, dynamic> json, {required double balance, required String currency}) {
    return PaymentCard(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      cardholderId: json['cardholderId'] as String,
      maskedPan: json['maskedPan'] as String,
      network: CardNetwork.values.byName(json['network'] as String),
      expiryMonth: json['expiryMonth'] as int,
      expiryYear: json['expiryYear'] as int,
      status: CardStatus.values.byName(json['status'] as String),
      balance: balance,
      currency: currency,
    );
  }

  @override
  Future<CardholderSession> login({required String email, required String password}) async {
    try {
      final json = await client.post('/v1/cardholder-sessions', {'email': email, 'password': password})
          as Map<String, dynamic>;
      // Ver docs/adr/0013-jwt-session-authentication.md — todo request
      // subsiguiente al backend exige este token.
      client.accessToken = json['accessToken'] as String;
      return CardholderSession(
        cardholderId: json['cardholderId'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
      );
    } on KbmBackendException catch (e) {
      if (e.statusCode == 401) throw const AuthException();
      rethrow;
    }
  }

  @override
  void logout() {
    client.accessToken = null;
  }

  @override
  Future<List<PaymentCard>> listMine(String cardholderId) async {
    final cardsJson = await client.get('/v1/cards?cardholder_id=$cardholderId') as List<dynamic>;
    final cards = await Future.wait(cardsJson.map((json) async {
      final cardMap = json as Map<String, dynamic>;
      final ledger = await client.get('/v1/cards/${cardMap['id']}/ledger') as Map<String, dynamic>;
      return _fromCardJson(
        cardMap,
        balance: (ledger['balance'] as num).toDouble(),
        currency: ledger['currency'] as String,
      );
    }));
    return cards;
  }

  @override
  Future<PaymentCard> setFrozen(String cardholderId, String cardId, bool freeze) async {
    try {
      final cardJson = await client.post('/v1/cards/$cardId/self-freeze', {
        'cardholderId': cardholderId,
        'frozen': freeze,
      }) as Map<String, dynamic>;
      final ledger = await client.get('/v1/cards/$cardId/ledger') as Map<String, dynamic>;
      return _fromCardJson(
        cardJson,
        balance: (ledger['balance'] as num).toDouble(),
        currency: ledger['currency'] as String,
      );
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) throw StateError('Tarjeta $cardId no encontrada.');
      if (e.statusCode == 409) {
        throw StateError(
          freeze
              ? 'Solo se puede aplicar un bloqueo temporal a una tarjeta activa.'
              : 'Esta tarjeta no tiene un bloqueo temporal que quitar.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<LedgerMovement>> listMovements(String cardId) async {
    final json = await client.get('/v1/cards/$cardId/ledger') as Map<String, dynamic>;
    final movements = (json['entries'] as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return LedgerMovement(
        id: map['id'] as String,
        type: (map['type'] as String) == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
        amount: (map['amount'] as num).toDouble(),
        balanceAfter: (map['balanceAfter'] as num).toDouble(),
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return movements;
  }

  @override
  Future<ResolvedTransferDestination?> resolveDestination({
    required String cardholderId,
    required String originCardId,
    required String pan,
  }) async {
    try {
      final json = await client.post('/v1/transfers/resolve', {
        'cardholderId': cardholderId,
        'originCardId': originCardId,
        'pan': pan,
      }) as Map<String, dynamic>;
      final card = PaymentCard(
        id: json['cardId'] as String,
        clientId: '',
        cardholderId: '',
        maskedPan: json['maskedPan'] as String,
        network: CardNetwork.visa,
        expiryMonth: 1,
        expiryYear: 2000,
        status: CardStatus.active,
        balance: 0,
      );
      return ResolvedTransferDestination(card: card, cardholderName: json['cardholderName'] as String);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      if (e.statusCode == 429) throw const TooManyFailedAttemptsException();
      rethrow;
    }
  }

  @override
  Future<void> transfer({
    required String originCardId,
    required String destinationCardId,
    required double amount,
  }) async {
    try {
      await client.post('/v1/transfers/execute', {
        'originCardId': originCardId,
        'destinationCardId': destinationCardId,
        'amount': amount,
      });
    } on KbmBackendException catch (e) {
      if (e.statusCode == 402) {
        throw InsufficientFundsException(currentBalance: 0, requestedAmount: amount);
      }
      rethrow;
    }
  }

  @override
  void resetFailedAttempts(String cardholderId) {
    // El backend cuenta los intentos fallidos por Tarjetahabiente en
    // memoria del lado del servidor y los reinicia él mismo en cada
    // login exitoso — no hay nada que hacer aquí. Ver
    // docs/security/threat-model.md punto 12.
  }
}
