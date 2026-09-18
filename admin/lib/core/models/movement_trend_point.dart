/// Un punto semanal de volumen de movimientos ejecutados (Dispersión,
/// Deducción, Transferencia), usado por el Panel directivo — ver
/// docs/feature/panel-directivo/README.md. Es un dato de flujo (cuánto se
/// movió esa semana), no de saldo: no se espera que sume al saldo actual
/// de ninguna cuenta.
class MovementTrendPoint {
  final DateTime weekStart;
  final double dispersion;
  final double deduccion;
  final double transferencia;

  const MovementTrendPoint({
    required this.weekStart,
    required this.dispersion,
    required this.deduccion,
    required this.transferencia,
  });

  double get total => dispersion + deduccion + transferencia;
}
