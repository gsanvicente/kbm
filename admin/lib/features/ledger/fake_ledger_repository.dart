import '../../core/models/claim_status.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import 'ledger_repository.dart';

/// In-memory stand-in for the ledger endpoints — same seed data as
/// backend/scripts/init-db/001_seed.sql. Read-only for accounts/entries
/// (this iteration doesn't implement fondeo/débito/transferencia — see
/// docs/business/saldo-y-ledger.md); claims are mutable, same rationale
/// as FakeCardRepository.
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository({required this.cardRepository, required this.clientRepository});

  /// Para resolver, en `fileClaim`/`resolveClaim`, a qué Cliente
  /// pertenece la tarjeta de un movimiento — `LedgerAccount` solo conoce
  /// el `cardId`, no el `clientId` directamente.
  final CardRepository cardRepository;

  /// Para verificar que ese Cliente pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  final ClientRepository clientRepository;
  // Mutable (not static const) — postEntry() rewrites an account's
  // cached balance in place as new entries are posted.
  final _accountsByCard = {
    '40000000-0000-0000-0000-000000000001': const LedgerAccount(
      id: '50000000-0000-0000-0000-000000000001',
      cardId: '40000000-0000-0000-0000-000000000001',
      currency: 'MXN',
      balance: 1250.00,
    ),
    '40000000-0000-0000-0000-000000000002': const LedgerAccount(
      id: '50000000-0000-0000-0000-000000000002',
      cardId: '40000000-0000-0000-0000-000000000002',
      currency: 'MXN',
      balance: 340.50,
    ),
    '40000000-0000-0000-0000-000000000004': const LedgerAccount(
      id: '50000000-0000-0000-0000-000000000004',
      cardId: '40000000-0000-0000-0000-000000000004',
      currency: 'MXN',
      balance: 75.00,
    ),
    // Unassigned cards (2001, 2002, 3001, 3002) intentionally absent —
    // no ledger_account exists until a card is assigned.
  };

  final List<LedgerEntry> _entries = [
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000001',
      ledgerAccountId: '50000000-0000-0000-0000-000000000001',
      type: LedgerEntryType.credit,
      amount: 1000.00,
      balanceAfter: 1000.00,
      description: 'Carga inicial',
      createdAt: DateTime(2026, 1, 10, 9, 0),
    ),
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000002',
      ledgerAccountId: '50000000-0000-0000-0000-000000000001',
      type: LedgerEntryType.debit,
      amount: 150.00,
      balanceAfter: 850.00,
      description: 'Compra en restaurante',
      createdAt: DateTime(2026, 1, 15, 14, 30),
    ),
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000003',
      ledgerAccountId: '50000000-0000-0000-0000-000000000001',
      type: LedgerEntryType.credit,
      amount: 400.00,
      balanceAfter: 1250.00,
      description: 'Carga de fondos',
      createdAt: DateTime(2026, 1, 20, 10, 0),
    ),
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000004',
      ledgerAccountId: '50000000-0000-0000-0000-000000000002',
      type: LedgerEntryType.credit,
      amount: 500.00,
      balanceAfter: 500.00,
      description: 'Carga inicial',
      createdAt: DateTime(2026, 1, 12, 9, 0),
    ),
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000005',
      ledgerAccountId: '50000000-0000-0000-0000-000000000002',
      type: LedgerEntryType.debit,
      amount: 159.50,
      balanceAfter: 340.50,
      description: 'Compra en línea',
      createdAt: DateTime(2026, 1, 18, 16, 45),
    ),
    LedgerEntry(
      id: '60000000-0000-0000-0000-000000000006',
      ledgerAccountId: '50000000-0000-0000-0000-000000000004',
      type: LedgerEntryType.credit,
      amount: 75.00,
      balanceAfter: 75.00,
      description: 'Carga inicial',
      createdAt: DateTime(2026, 1, 15, 9, 0),
    ),
  ];

  // Demo: Juan Perez disputes his "Compra en restaurante" debit, filed by
  // the Operador, left "in_review" — see
  // docs/business/reclamos-de-movimientos.md for why nothing in this
  // iteration transitions a claim into in_review manually.
  final List<MovementClaim> _claims = [
    MovementClaim(
      id: '70000000-0000-0000-0000-000000000001',
      ledgerEntryId: '60000000-0000-0000-0000-000000000002',
      reason: 'No reconozco este cargo.',
      status: ClaimStatus.inReview,
      requestedByEmail: 'operador.subA@koons.test',
      createdAt: DateTime(2026, 1, 16, 8, 0),
    ),
  ];

  @override
  Future<LedgerAccount?> getByCard(String cardId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _accountsByCard[cardId];
  }

  @override
  Future<Map<String, LedgerAccount>> getByCards(List<String> cardIds) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      for (final id in cardIds)
        if (_accountsByCard.containsKey(id)) id: _accountsByCard[id]!,
    };
  }

  @override
  Future<List<LedgerEntry>> listEntries(String ledgerAccountId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final entries = _entries.where((e) => e.ledgerAccountId == ledgerAccountId).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<Map<String, MovementClaim>> getClaims(List<String> ledgerEntryIds) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      for (final claim in _claims)
        if (ledgerEntryIds.contains(claim.ledgerEntryId)) claim.ledgerEntryId: claim,
    };
  }

  @override
  Future<MovementClaim?> getClaim(String ledgerEntryId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (final claim in _claims) {
      if (claim.ledgerEntryId == ledgerEntryId) return claim;
    }
    return null;
  }

  /// Verifica que el Cliente dueño de [cardId] pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  Future<bool> _isOperableForCard(String cardId) async {
    final card = await cardRepository.getById(cardId);
    if (card == null) return true; // no debería pasar, pero no bloquear por un dato inconsistente
    return clientRepository.isOperable(card.clientId);
  }

  @override
  Future<MovementClaim> fileClaim({
    required String ledgerEntryId,
    required String cardId,
    required String reason,
    required String requestedByEmail,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!await _isOperableForCard(cardId)) {
      throw const ClientInactiveException();
    }
    if (_claims.any((c) => c.ledgerEntryId == ledgerEntryId)) {
      throw StateError('Este movimiento ya tiene un reclamo.');
    }
    final claim = MovementClaim(
      id: 'claim-${DateTime.now().microsecondsSinceEpoch}',
      ledgerEntryId: ledgerEntryId,
      reason: reason,
      status: ClaimStatus.open,
      requestedByEmail: requestedByEmail,
      createdAt: DateTime.now(),
    );
    _claims.add(claim);
    return claim;
  }

  @override
  Future<MovementClaim> resolveClaim({
    required String claimId,
    required String cardId,
    required bool inFavor,
    required String resolutionNotes,
    required String resolvedByEmail,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _claims.indexWhere((c) => c.id == claimId);
    if (index == -1) throw NotFoundException('Reclamo $claimId no encontrado');
    if (!await _isOperableForCard(cardId)) {
      throw const ClientInactiveException();
    }
    final updated = _claims[index].copyWith(
      status: inFavor ? ClaimStatus.resolvedFavor : ClaimStatus.rejected,
      resolvedByEmail: resolvedByEmail,
      resolutionNotes: resolutionNotes,
      resolvedAt: DateTime.now(),
    );
    _claims[index] = updated;
    return updated;
  }

  @override
  Future<LedgerEntry> postEntry({
    required String ledgerAccountId,
    required LedgerEntryType type,
    required double amount,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final cardId = _accountsByCard.entries
        .firstWhere((e) => e.value.id == ledgerAccountId,
            orElse: () => throw NotFoundException('Cuenta de saldo $ledgerAccountId no encontrada'))
        .key;
    final account = _accountsByCard[cardId]!;

    final newBalance = type == LedgerEntryType.credit ? account.balance + amount : account.balance - amount;
    if (newBalance < 0) {
      throw InsufficientFundsException(currentBalance: account.balance, requestedAmount: amount);
    }

    final entry = LedgerEntry(
      id: 'entry-${DateTime.now().microsecondsSinceEpoch}',
      ledgerAccountId: ledgerAccountId,
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      description: description,
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    _accountsByCard[cardId] = account.copyWith(balance: newBalance);
    return entry;
  }
}
