/// Lanzada al presentar un reclamo sobre un movimiento que ya tiene uno
/// — relación 1:1, ver docs/business/reclamos-de-movimientos.md.
class ClaimAlreadyFiledException implements Exception {
  final String message;
  const ClaimAlreadyFiledException([this.message = 'Ya existe un reclamo sobre este movimiento.']);

  @override
  String toString() => message;
}
