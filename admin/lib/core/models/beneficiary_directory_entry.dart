/// Una fila del directorio agregado de Beneficiarios de Pago para staff
/// — ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md,
/// puntos 2 y 3. La CLABE viene enmascarada por default
/// (`maskedClabe`); la completa solo se obtiene con
/// `SpeiRepository.revealClabe`, una acción aparte y auditada.
class BeneficiaryDirectoryEntry {
  final String id;
  final String alias;
  final String maskedClabe;
  final String bankName;
  final DateTime coolingUntil;
  final bool isCooling;
  final DateTime createdAt;
  final String clientId;
  final String cardholderId;
  final String cardholderFullName;

  /// Solo pagos `executed` — dinero que de verdad salió, nunca intentos
  /// pending/rejected/failed.
  final int paymentCount;
  final double totalAmountPaid;

  /// true si esta misma CLABE está registrada por más de un
  /// Tarjetahabiente — calculado globalmente por el backend, sin
  /// respetar el alcance normal de quien consulta (ver
  /// docs/security/threat-model.md punto 18). Nunca dice quién más la
  /// registró.
  final bool sharedByMultipleCardholders;

  const BeneficiaryDirectoryEntry({
    required this.id,
    required this.alias,
    required this.maskedClabe,
    required this.bankName,
    required this.coolingUntil,
    required this.isCooling,
    required this.createdAt,
    required this.clientId,
    required this.cardholderId,
    required this.cardholderFullName,
    required this.paymentCount,
    required this.totalAmountPaid,
    required this.sharedByMultipleCardholders,
  });
}
