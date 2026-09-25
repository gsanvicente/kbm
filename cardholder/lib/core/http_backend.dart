import 'http/kbm_backend_client.dart';
import 'models/account_ledger.dart';
import 'models/beneficiary.dart';
import 'models/card_network.dart';
import 'models/card_status.dart';
import 'models/cardholder_session.dart';
import 'models/claim_status.dart';
import 'models/ledger_entry_type.dart';
import 'models/ledger_movement.dart';
import 'models/movement_claim.dart';
import 'models/payment_card.dart';
import 'models/shared/activation_failed_exception.dart';
import 'models/shared/auth_exception.dart';
import 'models/shared/claim_already_filed_exception.dart';
import 'models/shared/insufficient_funds_exception.dart';
import 'models/shared/too_many_failed_attempts_exception.dart';
import 'models/shared/validation_exception.dart';
import 'models/spei_deposit.dart';
import 'models/spei_payment.dart';
import 'models/spei_payment_status.dart';
import '../features/auth/cardholder_auth_repository.dart';
import '../features/cards/card_repository.dart';
import '../features/spei/spei_repository.dart';
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
class HttpCardholderBackend implements CardholderAuthRepository, CardRepository, TransferRepository, SpeiRepository {
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
  Future<CardholderSession> activate({
    required String email,
    required String idDocumentNumber,
    required String password,
  }) async {
    try {
      final json = await client.post('/v1/cardholder-activation', {
        'email': email,
        'idDocumentNumber': idDocumentNumber,
        'password': password,
      }) as Map<String, dynamic>;
      client.accessToken = json['accessToken'] as String;
      return CardholderSession(
        cardholderId: json['cardholderId'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
      );
    } on KbmBackendException catch (e) {
      if (e.statusCode == 401) throw const ActivationFailedException();
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
    // Una tarjeta `cancelled` (reemplazada por vencimiento/robo/extravío,
    // ver docs/adr/0020-cuenta-individual-tarjetahabiente.md) sigue
    // devolviéndose en este listado (nunca se borra, es historial), pero
    // ya no es una tarjeta con la que este Tarjetahabiente pueda hacer
    // nada — la propia app ni siquiera tiene ese estado en su enum
    // (ver core/models/card_status.dart). La Cuenta Individual detrás
    // sigue viva con su tarjeta de reemplazo, que sí aparece aparte.
    final cardsToShow = cardsJson.cast<Map<String, dynamic>>().where((m) => m['status'] != 'cancelled');
    final cards = await Future.wait(cardsToShow.map((cardMap) async {
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

  LedgerMovement _movementFromJson(Map<String, dynamic> map) => LedgerMovement(
        id: map['id'] as String,
        type: (map['type'] as String) == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
        amount: (map['amount'] as num).toDouble(),
        balanceAfter: (map['balanceAfter'] as num).toDouble(),
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  @override
  Future<List<LedgerMovement>> listMovements(String cardId) async {
    final json = await client.get('/v1/cards/$cardId/ledger') as Map<String, dynamic>;
    final movements =
        (json['entries'] as List<dynamic>).map((e) => _movementFromJson(e as Map<String, dynamic>)).toList();
    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return movements;
  }

  ClaimStatus _claimStatusFromJson(String value) {
    switch (value) {
      case 'open':
        return ClaimStatus.open;
      case 'in_review':
        return ClaimStatus.inReview;
      case 'resolved_favor':
        return ClaimStatus.resolvedFavor;
      case 'rejected':
        return ClaimStatus.rejected;
      default:
        return ClaimStatus.open;
    }
  }

  MovementClaim _claimFromJson(Map<String, dynamic> json) => MovementClaim(
        id: json['id'] as String,
        ledgerEntryId: json['ledgerEntryId'] as String,
        reason: json['reason'] as String,
        status: _claimStatusFromJson(json['status'] as String),
        resolutionNotes: json['resolutionNotes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
      );

  @override
  Future<MovementClaim?> getClaim(String ledgerEntryId) async {
    try {
      final json = await client.get('/v1/ledger-entries/$ledgerEntryId/claim') as Map<String, dynamic>;
      return _claimFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<MovementClaim> fileClaim(String ledgerEntryId, String reason) async {
    try {
      final json = await client.post('/v1/ledger-entries/$ledgerEntryId/claim', {'reason': reason}) as Map<String, dynamic>;
      return _claimFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 409) throw const ClaimAlreadyFiledException();
      rethrow;
    }
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

  @override
  Future<String?> getClabe(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/clabe') as Map<String, dynamic>;
    return json['clabe'] as String?;
  }

  @override
  Future<String> ensureClabe(String cardholderId) async {
    final json = await client.post('/v1/cardholders/$cardholderId/clabe') as Map<String, dynamic>;
    return json['clabe'] as String;
  }

  @override
  Future<AccountLedger> getAccountLedger(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/account/ledger') as Map<String, dynamic>;
    final movements =
        (json['entries'] as List<dynamic>).map((e) => _movementFromJson(e as Map<String, dynamic>)).toList();
    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return AccountLedger(
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
      movements: movements,
    );
  }

  @override
  Future<List<SpeiDeposit>> listDeposits(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/spei-deposits') as List<dynamic>;
    final deposits = json.map((e) {
      final map = e as Map<String, dynamic>;
      return SpeiDeposit(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        providerReference: map['providerReference'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
    deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deposits;
  }

  Beneficiary _beneficiaryFromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as String,
        alias: json['alias'] as String,
        clabe: json['clabe'] as String,
        bankName: json['bankName'] as String,
        coolingUntil: DateTime.parse(json['coolingUntil'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  Future<List<Beneficiary>> listBeneficiaries(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/beneficiaries') as List<dynamic>;
    return json.map((e) => _beneficiaryFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Beneficiary> registerBeneficiary({
    required String cardholderId,
    required String alias,
    required String clabe,
  }) async {
    try {
      final json = await client.post('/v1/cardholders/$cardholderId/beneficiaries', {
        'alias': alias,
        'clabe': clabe,
      }) as Map<String, dynamic>;
      return _beneficiaryFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 429) throw const TooManyFailedAttemptsException();
      if (e.statusCode == 400) throw const ValidationException();
      rethrow;
    }
  }

  SpeiPaymentStatus _speiStatusFromJson(String value) {
    switch (value) {
      case 'pending_approval':
        return SpeiPaymentStatus.pendingApproval;
      case 'executed':
        return SpeiPaymentStatus.executed;
      case 'rejected':
        return SpeiPaymentStatus.rejected;
      case 'failed':
        return SpeiPaymentStatus.failed;
      default:
        return SpeiPaymentStatus.pendingApproval;
    }
  }

  SpeiPayment _speiPaymentFromJson(Map<String, dynamic> json) => SpeiPayment(
        id: json['id'] as String,
        beneficiaryId: json['beneficiaryId'] as String,
        beneficiaryAlias: json['beneficiaryAlias'] as String? ?? '',
        beneficiaryClabe: json['beneficiaryClabe'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        status: _speiStatusFromJson(json['status'] as String),
        resolutionNotes: json['resolutionNotes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  Future<List<SpeiPayment>> listPayments(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/spei-payments') as List<dynamic>;
    final payments = json.map((e) => _speiPaymentFromJson(e as Map<String, dynamic>)).toList();
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  @override
  Future<SpeiPayment> createPayment({
    required String cardholderId,
    required String beneficiaryId,
    required double amount,
  }) async {
    try {
      final json = await client.post('/v1/cardholders/$cardholderId/spei-payments', {
        'beneficiaryId': beneficiaryId,
        'amount': amount,
      }) as Map<String, dynamic>;
      return _speiPaymentFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 400) throw const ValidationException();
      rethrow;
    }
  }
}
