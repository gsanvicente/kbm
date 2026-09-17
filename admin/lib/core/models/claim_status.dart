enum ClaimStatus {
  open,
  inReview,
  resolvedFavor,
  rejected;

  String get label {
    switch (this) {
      case ClaimStatus.open:
        return 'Abierto';
      case ClaimStatus.inReview:
        return 'En revisión';
      case ClaimStatus.resolvedFavor:
        return 'Resuelto a favor';
      case ClaimStatus.rejected:
        return 'Rechazado';
    }
  }

  bool get isResolved => this == ClaimStatus.resolvedFavor || this == ClaimStatus.rejected;
}
