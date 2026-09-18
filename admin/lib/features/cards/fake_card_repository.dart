import '../../core/models/card_network.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/shared/card_limit_exceeded_exception.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../clients/client_repository.dart';
import 'card_repository.dart';

/// In-memory stand-in for the card endpoints — same seed data as
/// backend/scripts/init-db/001_seed.sql. Mutable, same rationale as
/// FakeCardholderRepository (see its doc comment).
class FakeCardRepository implements CardRepository {
  FakeCardRepository({required this.clientRepository});

  /// Para verificar, en `assign`/`setBlocked`, que el Cliente dueño de la
  /// tarjeta pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  final ClientRepository clientRepository;

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

  // Subsidiaria A is at capacity per-cardholder (1) on purpose, to
  // demonstrate the rejection path; Subsidiaria B has room (2).
  static const _maxActiveCardsByClient = {
    '00000000-0000-0000-0000-000000000002': 1,
    '00000000-0000-0000-0000-000000000003': 2,
  };

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
    return _maxActiveCardsByClient[clientId];
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
    if (!card.isAvailable) {
      throw StateError('La tarjeta ${card.maskedPan} ya no está disponible.');
    }

    final max = _maxActiveCardsByClient[card.clientId];
    if (max != null) {
      final activeCount =
          _cards.where((c) => c.cardholderId == cardholderId && c.status == CardStatus.active).length;
      if (activeCount >= max) throw CardLimitExceededException(max);
    }

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

    final updated = card.copyWith(status: blocked ? CardStatus.blocked : CardStatus.active);
    _cards[index] = updated;
    return updated;
  }
}
