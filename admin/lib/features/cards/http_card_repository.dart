import '../../core/http/kbm_backend_client.dart';
import '../../core/models/card_blocked_reason.dart';
import '../../core/models/card_network.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/shared/card_limit_exceeded_exception.dart';
import '../../core/models/shared/cardholder_inactive_exception.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../cardholders/cardholder_repository.dart';
import '../clients/client_repository.dart';
import 'card_repository.dart';

/// Implementación real de `CardRepository` contra el backend compartido —
/// ver docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
/// Reemplaza a `FakeCardRepository`, pero conserva exactamente las mismas
/// verificaciones de Cliente/Tarjetahabiente inactivo *antes* de llamar
/// al backend: ese backend en memoria no conoce la jerarquía de Clientes
/// ni el expediente KYC del Tarjetahabiente (ninguno de los dos migra
/// ahí, ver la ADR) — quien sí los conoce sigue siendo `admin/`.
class HttpCardRepository implements CardRepository {
  HttpCardRepository({
    required this.client,
    required this.clientRepository,
    required this.cardholderRepository,
  });

  final KbmBackendClient client;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;

  /// Duplicado del `seedCardLimits()` de
  /// backend/internal/adapters/memory/repository/seed.go — el backend es
  /// quien de verdad hace cumplir el límite (ver `assign`); esto solo
  /// respalda `maxActiveCardsPerCardholder`, que hoy ningún widget llama
  /// todavía. Default de 1 para cualquier Cliente no listado — ver
  /// docs/business/tarjetas-y-asignacion.md.
  static const _defaultMaxActiveCardsPerCardholder = 1;
  static const _maxActiveCardsByClient = {
    '00000000-0000-0000-0000-000000000003': 2,
  };

  PaymentCard _fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      cardholderId: json['cardholderId'] as String?,
      maskedPan: json['maskedPan'] as String,
      network: CardNetwork.values.byName(json['network'] as String),
      expiryMonth: json['expiryMonth'] as int,
      expiryYear: json['expiryYear'] as int,
      status: CardStatus.values.byName(json['status'] as String),
      blockedReason: _blockedReasonFromJson(json['blockedReason'] as String?),
      assignedAt: json['assignedAt'] != null ? DateTime.parse(json['assignedAt'] as String) : null,
    );
  }

  CardBlockedReason? _blockedReasonFromJson(String? value) {
    switch (value) {
      case 'manual':
        return CardBlockedReason.manual;
      case 'cardholder_inactive':
        return CardBlockedReason.cardholderInactive;
      default:
        return null;
    }
  }

  @override
  Future<PaymentCard?> getById(String cardId) async {
    try {
      final json = await client.get('/v1/cards/$cardId');
      return _fromJson(json as Map<String, dynamic>);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<PaymentCard>> listByCardholder(String cardholderId) async {
    final json = await client.get('/v1/cards?cardholder_id=$cardholderId');
    return (json as List<dynamic>).map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentCard>> listByClients(List<String> clientIds) async {
    // El backend solo filtra por un client_id a la vez — se combinan
    // varias llamadas en vez de agregar un parámetro nuevo al contrato
    // para esta iteración interina, ver
    // docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
    final results = await Future.wait(clientIds.map((id) => client.get('/v1/cards?client_id=$id')));
    return [
      for (final json in results) ...(json as List<dynamic>).map((e) => _fromJson(e as Map<String, dynamic>)),
    ];
  }

  @override
  Future<int?> maxActiveCardsPerCardholder(String clientId) async {
    return _maxActiveCardsByClient[clientId] ?? _defaultMaxActiveCardsPerCardholder;
  }

  @override
  Future<PaymentCard> assign({required String cardId, required String cardholderId}) async {
    final card = await getById(cardId);
    if (card == null) throw NotFoundException('Tarjeta $cardId no encontrada');
    if (!await clientRepository.isOperable(card.clientId)) {
      throw const ClientInactiveException();
    }
    if (!await cardholderRepository.isOperable(cardholderId)) {
      throw const CardholderInactiveException();
    }

    try {
      final json = await client.post('/v1/cards/$cardId/assign', {'cardholderId': cardholderId});
      return _fromJson(json as Map<String, dynamic>);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 409 && e.body?['limit'] != null) {
        throw CardLimitExceededException(e.body!['limit'] as int);
      }
      if (e.statusCode == 409) {
        throw StateError('La tarjeta ${card.maskedPan} ya no está disponible.');
      }
      rethrow;
    }
  }

  @override
  Future<PaymentCard> setBlocked(String cardId, bool blocked) async {
    final card = await getById(cardId);
    if (card == null) throw NotFoundException('Tarjeta $cardId no encontrada');
    if (!await clientRepository.isOperable(card.clientId)) {
      throw const ClientInactiveException();
    }
    if (card.cardholderId == null) {
      throw StateError('No se puede bloquear una tarjeta que no está asignada.');
    }
    // Solo al desbloquear: bloquear más una tarjeta de alguien inactivo
    // nunca es un problema, ver docs/business/tarjetas-y-asignacion.md.
    if (!blocked && !await cardholderRepository.isOperable(card.cardholderId!)) {
      throw const CardholderInactiveException();
    }

    final json = await client.post('/v1/cards/$cardId/block-status', {'blocked': blocked});
    return _fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> freezeAllForCardholder(String cardholderId) async {
    await client.post('/v1/cardholders/$cardholderId/freeze-cards');
  }
}
