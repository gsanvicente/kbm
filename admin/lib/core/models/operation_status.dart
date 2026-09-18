/// Mirrors the DB `operation_status` enum exactly, including `approved`
/// — which this iteration never actually produces (approving executes
/// in the same step) but is kept for schema fidelity and a future async
/// approve-then-execute flow. See docs/business/approval-policy.md.
enum OperationStatus {
  pendingApproval,
  approved,
  executed,
  rejected,
  failed;

  String get label {
    switch (this) {
      case OperationStatus.pendingApproval:
        return 'Pendiente de aprobación';
      case OperationStatus.approved:
        return 'Aprobada';
      case OperationStatus.executed:
        return 'Ejecutada';
      case OperationStatus.rejected:
        return 'Rechazada';
      case OperationStatus.failed:
        return 'Fallida';
    }
  }

  bool get isResolved => this != OperationStatus.pendingApproval;
}
