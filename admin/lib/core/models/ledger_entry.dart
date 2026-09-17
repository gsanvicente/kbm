import 'ledger_entry_type.dart';

/// A single movement — append-only in the real backend
/// (docs/business/saldo-y-ledger.md). Never mutated once created; a
/// dispute about one is a separate MovementClaim, not a change here.
class LedgerEntry {
  final String id;
  final String ledgerAccountId;
  final LedgerEntryType type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.ledgerAccountId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });
}
