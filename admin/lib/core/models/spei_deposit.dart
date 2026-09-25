/// Un depósito SPEI entrante ya conciliado automáticamente — ver
/// docs/adr/0021-conector-spei.md, punto 8. cardholderFullName es un
/// campo de join (solo poblado en el reporte cross-cliente de staff, ver
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md).
class SpeiDeposit {
  final String id;
  final String clientId;
  final String accountId;
  final double amount;
  final String providerReference;
  final DateTime createdAt;
  final String cardholderFullName;

  const SpeiDeposit({
    required this.id,
    required this.clientId,
    required this.accountId,
    required this.amount,
    required this.providerReference,
    required this.createdAt,
    required this.cardholderFullName,
  });
}
