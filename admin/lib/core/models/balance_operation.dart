import 'operation_status.dart';
import 'operation_type.dart';

/// A requested carga/débito/transferencia over a card, gated by
/// approval_rules. Never mutates the ledger directly — only a successful
/// execution (immediate, or on approval) does, via LedgerRepository. See
/// docs/feature/operacion-saldo-con-aprobacion/README.md.
class BalanceOperation {
  final String id;
  final String clientId;
  final String cardId;
  final OperationType type;
  final double amount;

  /// Only set for [OperationType.transfer] — see "Destino de una
  /// transferencia" in the feature doc.
  final String? destinationCardId;

  final OperationStatus status;
  final String requestedByEmail;
  final String? resolvedByEmail;

  /// Rejection reason, or the failure reason (e.g. insufficient funds) —
  /// same dual-purpose field as MovementClaim.resolutionNotes.
  final String? resolutionNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BalanceOperation({
    required this.id,
    required this.clientId,
    required this.cardId,
    required this.type,
    required this.amount,
    this.destinationCardId,
    required this.status,
    required this.requestedByEmail,
    this.resolvedByEmail,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  BalanceOperation copyWith({
    OperationStatus? status,
    String? resolvedByEmail,
    String? resolutionNotes,
    DateTime? updatedAt,
  }) {
    return BalanceOperation(
      id: id,
      clientId: clientId,
      cardId: cardId,
      type: type,
      amount: amount,
      destinationCardId: destinationCardId,
      status: status ?? this.status,
      requestedByEmail: requestedByEmail,
      resolvedByEmail: resolvedByEmail ?? this.resolvedByEmail,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
