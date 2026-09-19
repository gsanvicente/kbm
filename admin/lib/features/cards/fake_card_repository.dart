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

/// In-memory stand-in for the card endpoints — same seed data as
/// backend/scripts/init-db/001_seed.sql. Mutable, same rationale as
/// FakeCardholderRepository (see its doc comment).
class FakeCardRepository implements CardRepository {
  FakeCardRepository({required this.clientRepository, required this.cardholderRepository});

  /// Para verificar, en `assign`/`setBlocked`, que el Cliente dueño de la
  /// tarjeta pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  final ClientRepository clientRepository;

  /// Para verificar que el Tarjetahabiente pueda operar — ver
  /// docs/business/desactivacion-de-tarjetahabientes.md, "Capa 2". Una
  /// sola dirección de dependencia (Card → Cardholder); el efecto
  /// contrario (desactivar un Tarjetahabiente congela sus tarjetas) se
  /// resuelve con un callback en `FakeCardholderRepository`, no aquí, para
  /// no crear una dependencia circular entre ambos repositorios.
  final CardholderRepository cardholderRepository;

  final List<PaymentCard> _cards = [
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000001',
      clientId: '00000000-0000-0000-0000-000000000002',
      cardholderId: '20000000-0000-0000-0000-000000000001', // Juan Perez
      maskedPan: '**** **** **** 1234',
      network: CardNetwork.visa,
      expiryMonth: 8,
      expiryYear: 2027,
      status: CardStatus.active,
      assignedAt: DateTime(2026, 1, 10),
    ),
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000002',
      clientId: '00000000-0000-0000-0000-000000000003',
      cardholderId: '20000000-0000-0000-0000-000000000002', // Maria Gomez
      maskedPan: '**** **** **** 5678',
      network: CardNetwork.mastercard,
      expiryMonth: 3,
      expiryYear: 2026,
      status: CardStatus.active,
      assignedAt: DateTime(2026, 1, 12),
    ),
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000004',
      clientId: '00000000-0000-0000-0000-000000000003',
      cardholderId: '20000000-0000-0000-0000-000000000004', // Carlos Ruiz
      maskedPan: '**** **** **** 7890',
      network: CardNetwork.visa,
      expiryMonth: 11,
      expiryYear: 2026,
      status: CardStatus.blocked,
      assignedAt: DateTime(2026, 1, 15),
      blockedReason: CardBlockedReason.manual,
    ),
    // Available pool — Ana Torres (Subsidiaria A) intentionally has no
    // card yet, see docs/feature/tarjetas-de-tarjetahabiente/.
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000005',
      clientId: '00000000-0000-0000-0000-000000000002',
      maskedPan: '**** **** **** 2001',
      network: CardNetwork.visa,
      expiryMonth: 5,
      expiryYear: 2028,
      status: CardStatus.unassigned,
    ),
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000006',
      clientId: '00000000-0000-0000-0000-000000000002',
      maskedPan: '**** **** **** 2002',
      network: CardNetwork.mastercard,
      expiryMonth: 9,
      expiryYear: 2028,
      status: CardStatus.unassigned,
    ),
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000007',
      clientId: '00000000-0000-0000-0000-000000000003',
      maskedPan: '**** **** **** 3001',
      network: CardNetwork.visa,
      expiryMonth: 1,
      expiryYear: 2029,
      status: CardStatus.unassigned,
    ),
    PaymentCard(
      id: '40000000-0000-0000-0000-000000000008',
      clientId: '00000000-0000-0000-0000-000000000003',
      maskedPan: '**** **** **** 3002',
      network: CardNetwork.mastercard,
      expiryMonth: 7,
      expiryYear: 2027,
      status: CardStatus.unassigned,
    ),
  ];

  // Default de 1 tarjeta activa por tarjetahabiente para cualquier
  // Cliente no listado aquí — ver docs/business/tarjetas-y-asignacion.md,
  // "Límite de tarjetas activas por Tarjetahabiente". Solo overrides
  // explícitos van en este mapa; Subsidiaria B tiene uno (2), para
  // demostrar que sí varía por Cliente y no queda solo en el default.
  static const _defaultMaxActiveCardsPerCardholder = 1;
  static const _maxActiveCardsByClient = {
    '00000000-0000-0000-0000-000000000003': 2,
  };

  int _maxActiveCardsFor(String clientId) =>
      _maxActiveCardsByClient[clientId] ?? _defaultMaxActiveCardsPerCardholder;

  @override
  Future<PaymentCard?> getById(String cardId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (final card in _cards) {
      if (card.id == cardId) return card;
    }
    return null;
  }

  @override
  Future<List<PaymentCard>> listByCardholder(String cardholderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _cards.where((c) => c.cardholderId == cardholderId).toList();
  }

  @override
  Future<List<PaymentCard>> listByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _cards.where((c) => clientIds.contains(c.clientId)).toList();
  }

  @override
  Future<int?> maxActiveCardsPerCardholder(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _maxActiveCardsFor(clientId);
  }

  @override
  Future<PaymentCard> assign({required String cardId, required String cardholderId}) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final index = _cards.indexWhere((c) => c.id == cardId);
    if (index == -1) throw NotFoundException('Tarjeta $cardId no encontrada');
    final card = _cards[index];
    if (!await clientRepository.isOperable(card.clientId)) {
      throw const ClientInactiveException();
    }
    if (!await cardholderRepository.isOperable(cardholderId)) {
      throw const CardholderInactiveException();
    }
    if (!card.isAvailable) {
      throw StateError('La tarjeta ${card.maskedPan} ya no está disponible.');
    }

    final max = _maxActiveCardsFor(card.clientId);
    final activeCount = _cards.where((c) => c.cardholderId == cardholderId && c.status == CardStatus.active).length;
    if (activeCount >= max) throw CardLimitExceededException(max);

    final updated = card.copyWith(
      cardholderId: cardholderId,
      status: CardStatus.active,
      assignedAt: DateTime.now(),
    );
    _cards[index] = updated;
    return updated;
  }

  @override
  Future<PaymentCard> setBlocked(String cardId, bool blocked) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _cards.indexWhere((c) => c.id == cardId);
    if (index == -1) throw NotFoundException('Tarjeta $cardId no encontrada');
    final card = _cards[index];
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

    // Construcción directa, no `copyWith` — necesitamos poder limpiar
    // `blockedReason` a `null` explícitamente al desbloquear, cosa que el
    // patrón `??` de copyWith no permite (ver el doc del campo en
    // payment_card.dart).
    final updated = PaymentCard(
      id: card.id,
      clientId: card.clientId,
      cardholderId: card.cardholderId,
      maskedPan: card.maskedPan,
      network: card.network,
      expiryMonth: card.expiryMonth,
      expiryYear: card.expiryYear,
      status: blocked ? CardStatus.blocked : CardStatus.active,
      assignedAt: card.assignedAt,
      blockedReason: blocked ? CardBlockedReason.manual : null,
    );
    _cards[index] = updated;
    return updated;
  }

  @override
  Future<void> freezeAllForCardholder(String cardholderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (var i = 0; i < _cards.length; i++) {
      final card = _cards[i];
      if (card.cardholderId != cardholderId || card.status == CardStatus.blocked) continue;
      _cards[i] = PaymentCard(
        id: card.id,
        clientId: card.clientId,
        cardholderId: card.cardholderId,
        maskedPan: card.maskedPan,
        network: card.network,
        expiryMonth: card.expiryMonth,
        expiryYear: card.expiryYear,
        status: CardStatus.blocked,
        assignedAt: card.assignedAt,
        blockedReason: CardBlockedReason.cardholderInactive,
      );
    }
  }
}
