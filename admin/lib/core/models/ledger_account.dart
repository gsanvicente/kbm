/// The current balance of a card's ledger account — always derived from
/// the most recent ledger_entry.balance_after in the real backend (see
/// docs/business/saldo-y-ledger.md). Never set directly by the UI; only
/// LedgerRepository.postEntry recomputes it, as the result of posting a
/// new append-only entry.
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

  LedgerAccount copyWith({double? balance}) {
    return LedgerAccount(
      id: id,
      cardId: cardId,
      currency: currency,
      balance: balance ?? this.balance,
    );
  }
}
