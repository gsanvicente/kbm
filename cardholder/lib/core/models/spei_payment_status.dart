/// Espejo del subconjunto de `operation_status` (Postgres) que un pago
/// SPEI puede tomar — ver docs/adr/0021-conector-spei.md. `approved`
/// nunca llega hasta acá: aprobar ejecuta en el mismo paso (ver
/// backend/internal/adapters/postgres/repository/spei.go, ApprovePayment).
enum SpeiPaymentStatus {
  pendingApproval,
  executed,
  rejected,
  failed;

  String get label {
    switch (this) {
      case SpeiPaymentStatus.pendingApproval:
        return 'Pendiente de aprobación';
      case SpeiPaymentStatus.executed:
        return 'Enviado';
      case SpeiPaymentStatus.rejected:
        return 'Rechazado';
      case SpeiPaymentStatus.failed:
        return 'Falló';
    }
  }
}
