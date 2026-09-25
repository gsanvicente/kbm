import 'concentrator_entry.dart';

/// El "Estado de cuenta para directivos" — ver
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 5.
/// entries ya incluye los créditos de depósitos de Colectora conciliados
/// (`ReconcileDeposit` los inserta como ConcentratorEntry) — nunca se
/// combina por separado con CollectorDeposit, contaría el mismo
/// movimiento dos veces.
class TreasuryStatement {
  final double concentratorBalance;
  final String currency;
  final List<ConcentratorEntry> entries;

  const TreasuryStatement({
    required this.concentratorBalance,
    required this.currency,
    required this.entries,
  });
}
