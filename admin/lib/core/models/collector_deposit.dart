import 'collector_deposit_status.dart';

/// A deposit registered in a Cliente's Cuenta Colectora. Registering one
/// never moves the Concentradora's balance by itself — only reconciling
/// does. See docs/business/tesoreria-cliente.md, "El flujo de fondeo:
/// dos pasos, no uno".
class CollectorDeposit {
  final String id;
  final String clientId;
  final double amount;
  final String reference;
  final CollectorDepositStatus status;
  final String registeredByEmail;
  final String? reconciledByEmail;
  final DateTime createdAt;
  final DateTime? reconciledAt;

  const CollectorDeposit({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.reference,
    required this.status,
    required this.registeredByEmail,
    this.reconciledByEmail,
    required this.createdAt,
    this.reconciledAt,
  });

  CollectorDeposit copyWith({
    CollectorDepositStatus? status,
    String? reconciledByEmail,
    DateTime? reconciledAt,
  }) {
    return CollectorDeposit(
      id: id,
      clientId: clientId,
      amount: amount,
      reference: reference,
      status: status ?? this.status,
      registeredByEmail: registeredByEmail,
      reconciledByEmail: reconciledByEmail ?? this.reconciledByEmail,
      createdAt: createdAt,
      reconciledAt: reconciledAt ?? this.reconciledAt,
    );
  }
}
