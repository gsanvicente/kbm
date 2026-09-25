import 'spei_payment_status.dart';

/// Un pago SPEI saliente a un [Beneficiary] — ver
/// docs/adr/0021-conector-spei.md. beneficiaryAlias/beneficiaryClabe son
/// datos de join para mostrar en la lista, no una relación de dominio —
/// mismo criterio que el lado Go (speipayment.Payment).
class SpeiPayment {
  final String id;
  final String beneficiaryId;
  final String beneficiaryAlias;
  final String beneficiaryClabe;
  final double amount;
  final SpeiPaymentStatus status;
  final String? resolutionNotes;
  final DateTime createdAt;

  const SpeiPayment({
    required this.id,
    required this.beneficiaryId,
    required this.beneficiaryAlias,
    required this.beneficiaryClabe,
    required this.amount,
    required this.status,
    this.resolutionNotes,
    required this.createdAt,
  });
}
