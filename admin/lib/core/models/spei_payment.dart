import 'operation_status.dart';

/// Un pago SPEI saliente de la Cuenta Individual de un Tarjetahabiente a
/// un Beneficiario de Pago externo — ver
/// docs/adr/0021-conector-spei.md. Vista de solo lectura para staff: el
/// alta la origina el propio Tarjetahabiente desde `cardholder/`, staff
/// solo aprueba/rechaza. beneficiaryAlias/beneficiaryClabe/
/// requestedByFullName son campos de join (solo poblados en el listado
/// de pendientes), no una relación de dominio — mismo criterio que el
/// lado Go (speipayment.Payment).
class SpeiPayment {
  final String id;
  final String clientId;
  final String accountId;
  final String beneficiaryId;
  final String beneficiaryAlias;
  final String beneficiaryClabe;
  final String requestedByFullName;
  final double amount;
  final OperationStatus status;
  final String? resolvedByEmail;
  final String? resolutionNotes;
  final DateTime createdAt;

  const SpeiPayment({
    required this.id,
    required this.clientId,
    required this.accountId,
    required this.beneficiaryId,
    required this.beneficiaryAlias,
    required this.beneficiaryClabe,
    required this.requestedByFullName,
    required this.amount,
    required this.status,
    this.resolvedByEmail,
    this.resolutionNotes,
    required this.createdAt,
  });

  SpeiPayment copyWith({
    OperationStatus? status,
    String? resolvedByEmail,
    String? resolutionNotes,
  }) {
    return SpeiPayment(
      id: id,
      clientId: clientId,
      accountId: accountId,
      beneficiaryId: beneficiaryId,
      beneficiaryAlias: beneficiaryAlias,
      beneficiaryClabe: beneficiaryClabe,
      requestedByFullName: requestedByFullName,
      amount: amount,
      status: status ?? this.status,
      resolvedByEmail: resolvedByEmail ?? this.resolvedByEmail,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
    );
  }
}
