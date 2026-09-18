import 'ledger_entry_type.dart';

/// Append-only, same pattern as LedgerEntry but one level up (Cliente
/// instead of Tarjeta). A Dispersión debits, a Deducción credits, a
/// reconciled CollectorDeposit also credits. See
/// docs/business/tesoreria-cliente.md.
class ConcentratorEntry {
  final String id;
  final String concentratorAccountId;
  final LedgerEntryType type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;

  const ConcentratorEntry({
    required this.id,
    required this.concentratorAccountId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });
}
