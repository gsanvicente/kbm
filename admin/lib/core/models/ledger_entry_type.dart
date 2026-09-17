enum LedgerEntryType {
  debit,
  credit;

  String get label {
    switch (this) {
      case LedgerEntryType.debit:
        return 'Débito';
      case LedgerEntryType.credit:
        return 'Crédito';
    }
  }
}
