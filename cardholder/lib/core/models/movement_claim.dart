import 'claim_status.dart';

/// Un reclamo sobre un movimiento propio — ver
/// docs/business/reclamos-de-movimientos.md. Solo lo que el propio
/// Tarjetahabiente necesita ver (nunca resuelve nada desde aquí, eso es
/// exclusivo de `admin/`).
class MovementClaim {
  final String id;
  final String ledgerEntryId;
  final String reason;
  final ClaimStatus status;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const MovementClaim({
    required this.id,
    required this.ledgerEntryId,
    required this.reason,
    required this.status,
    this.resolutionNotes,
    required this.createdAt,
    this.resolvedAt,
  });
}
