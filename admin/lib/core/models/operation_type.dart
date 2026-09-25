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
  transfer,
  // Pago SPEI a un Beneficiario externo — ver
  // docs/adr/0021-conector-spei.md, punto 7. Solo aparece en el contexto
  // de las Reglas de aprobación (ClientDetailView): a diferencia de los
  // otros tres, nunca se "solicita" desde OperationsTab/BalanceOperationDialog
  // — un pago SPEI lo origina el propio Tarjetahabiente
  // (features/spei/spei_repository.dart), nunca el staff sobre una
  // tarjeta.
  speiPayment;

  String get label {
    switch (this) {
      case OperationType.load:
        return 'Dispersión';
      case OperationType.debit:
        return 'Deducción';
      case OperationType.transfer:
        return 'Transferencia';
      case OperationType.speiPayment:
        return 'Pago SPEI';
    }
  }

  /// Nombre tal como lo espera/devuelve el backend (`operation_type` en
  /// Postgres) — separado de `.name` porque Dart no permite un
  /// identificador de enum en snake_case idiomático (`speiPayment` vs
  /// `spei_payment`). load/debit/transfer coinciden con `.name` por ser
  /// una sola palabra; para serializar/deserializar cualquier
  /// OperationType, wireValue es la fuente de verdad, nunca `.name`.
  String get wireValue {
    switch (this) {
      case OperationType.load:
        return 'load';
      case OperationType.debit:
        return 'debit';
      case OperationType.transfer:
        return 'transfer';
      case OperationType.speiPayment:
        return 'spei_payment';
    }
  }

  static OperationType fromWireValue(String value) {
    return OperationType.values.firstWhere((t) => t.wireValue == value, orElse: () => OperationType.load);
  }
}
