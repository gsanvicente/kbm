import 'claim_status.dart';

/// A dispute over an already-executed LedgerEntry — never mutates the
/// movement itself. 1:1 with the entry it's about. See
/// docs/business/reclamos-de-movimientos.md.
class MovementClaim {
  final String id;
  final String ledgerEntryId;
  final String reason;
  final ClaimStatus status;
  final String requestedByEmail;
  final String? resolvedByEmail;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const MovementClaim({
    required this.id,
    required this.ledgerEntryId,
    required this.reason,
    required this.status,
    required this.requestedByEmail,
    this.resolvedByEmail,
    this.resolutionNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  MovementClaim copyWith({
    ClaimStatus? status,
    String? resolvedByEmail,
    String? resolutionNotes,
    DateTime? resolvedAt,
  }) {
    return MovementClaim(
      id: id,
      ledgerEntryId: ledgerEntryId,
      reason: reason,
      status: status ?? this.status,
      requestedByEmail: requestedByEmail,
      resolvedByEmail: resolvedByEmail ?? this.resolvedByEmail,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
