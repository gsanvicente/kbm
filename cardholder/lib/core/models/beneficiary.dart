/// Beneficiario de Pago — a quién le puedo enviar un pago SPEI. Ver
/// docs/adr/0021-conector-spei.md. Nada que ver con el `cardholderName`
/// que resuelve una transferencia C2C (transfer_repository.dart): ese es
/// otro Tarjetahabiente del mismo Cliente; esto es una CLABE externa.
class Beneficiary {
  final String id;
  final String alias;
  final String clabe;
  final String bankName;
  final DateTime coolingUntil;
  final DateTime createdAt;

  const Beneficiary({
    required this.id,
    required this.alias,
    required this.clabe,
    required this.bankName,
    required this.coolingUntil,
    required this.createdAt,
  });

  /// Mientras es true, este Beneficiario solo puede recibir montos
  /// pequeños (el backend decide el tope exacto) — ver "Periodo de
  /// enfriamiento" en docs/adr/0021-conector-spei.md, "Seguridad".
  bool get isCooling => DateTime.now().isBefore(coolingUntil);

  /// CLABE enmascarada para mostrar en listas/confirmaciones — nunca los
  /// 18 dígitos completos fuera de la pantalla de alta. Mismo criterio
  /// que `maskedPan` en `PaymentCard`.
  String get maskedClabe => '•••• ${clabe.substring(clabe.length - 4)}';
}
