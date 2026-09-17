/// The current balance of a card's ledger account — always derived from
/// the most recent ledger_entry.balance_after in the real backend (see
/// docs/business/saldo-y-ledger.md), never set directly. Read-only in
/// this iteration: no operation here mutates it yet.
class LedgerAccount {
  final String id;
  final String cardId;
  final String currency;
  final double balance;

  const LedgerAccount({
    required this.id,
    required this.cardId,
    required this.currency,
    required this.balance,
  });
}
