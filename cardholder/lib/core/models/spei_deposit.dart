/// Un depósito SPEI entrante ya conciliado automáticamente — ver
/// docs/adr/0021-conector-spei.md, punto 8. Base del comprobante propio
/// de un depósito (mismo ADR, punto 9): a diferencia de un movimiento
/// genérico del estado de cuenta, esto trae su propia referencia del
/// proveedor.
class SpeiDeposit {
  final String id;
  final double amount;
  final String providerReference;
  final DateTime createdAt;

  const SpeiDeposit({
    required this.id,
    required this.amount,
    required this.providerReference,
    required this.createdAt,
  });
}
