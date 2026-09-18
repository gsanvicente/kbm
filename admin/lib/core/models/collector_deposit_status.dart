enum CollectorDepositStatus {
  pending,
  reconciled;

  String get label {
    switch (this) {
      case CollectorDepositStatus.pending:
        return 'Pendiente';
      case CollectorDepositStatus.reconciled:
        return 'Conciliado';
    }
  }
}
