/// Mirrors the DB `operation_type` enum, minus 'block'/'unblock' — those
/// stay the direct action from docs/feature/bloqueo-de-tarjeta/, never
/// created through this feature. See
/// docs/feature/operacion-saldo-con-aprobacion/README.md.
///
/// The enum identifiers (load/debit/transfer) are the DB-facing names and
/// stay as-is for schema stability — [label] is the only user-visible
/// name, and it was deliberately renamed (2026-09-19, "Carga"/"Débito"
/// tested as confusing) to Dispersión/Deducción.
enum OperationType {
  load,
  debit,
  transfer;

  String get label {
    switch (this) {
      case OperationType.load:
        return 'Dispersión';
      case OperationType.debit:
        return 'Deducción';
      case OperationType.transfer:
        return 'Transferencia';
    }
  }
}
