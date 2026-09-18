import 'operation_type.dart';

/// A Cliente's configured approval requirement for one operation type.
/// See docs/business/approval-policy.md for how [requiresApproval] and
/// [minAmount] combine, and the fail-safe default when no rule exists
/// for a given Cliente + [operationType].
class ApprovalRule {
  final String clientId;
  final OperationType operationType;
  final bool requiresApproval;

  /// Approval only applies to amounts strictly greater than this — null
  /// means "any amount" when [requiresApproval] is true.
  final double? minAmount;

  const ApprovalRule({
    required this.clientId,
    required this.operationType,
    required this.requiresApproval,
    this.minAmount,
  });
}
