import 'balance_operation.dart';
import 'client_dashboard_row.dart';
import 'collector_deposit.dart';
import 'movement_trend_point.dart';

/// Resultado agregado del Panel directivo (pantalla "Inicio") para un
/// conjunto de Clientes ya resuelto por `ClientRepository.listAccessibleClients`
/// — ver docs/feature/panel-directivo/README.md. Asume una sola moneda
/// (MXN) entre los Clientes agregados, igual que el resto de la
/// plataforma en esta iteración.
class DashboardSummary {
  final String currency;

  final double concentratorBalanceTotal;
  final double cardBalanceTotal;

  final int pendingDepositsCount;
  final double pendingDepositsAmount;

  final int pendingOperationsCount;
  final double pendingOperationsAmount;

  final int openClaimsCount;

  final int activeCardsCount;
  final int availableCardsCount;
  final int blockedOrFrozenCardsCount;

  /// Históricos, todo el tiempo (operaciones `executed`) — no confundir
  /// con [pendingOperationsAmount], que es solo lo pendiente.
  final double executedDispersionTotal;
  final double executedDeduccionTotal;
  final double executedTransferenciaTotal;

  /// Solo tiene más de un elemento cuando el usuario ve más de un
  /// Cliente (Super Admin, o Admin Cliente con filiales) — ver "Desglose
  /// por empresa" en el feature doc.
  final List<ClientDashboardRow> clientBreakdown;

  /// Las más recientes primero, tope 5 — ver "Requiere tu atención".
  final List<BalanceOperation> attentionPendingOperations;
  final List<CollectorDeposit> attentionPendingDeposits;

  /// Últimas 12 semanas.
  final List<MovementTrendPoint> weeklyTrend;

  /// true solo en modo demo (`FakeBalanceOperationRepository`, sin
  /// backend real) — ahí [weeklyTrend] sigue siendo un dato sintético
  /// determinista, ver esa clase. Contra el backend Postgres
  /// (`HttpBalanceOperationRepository`) es un agregado real de
  /// `balance_operations` ejecutadas — ver
  /// docs/feature/panel-directivo/README.md, "Volumen de movimientos".
  /// La UI usa esto para mostrar (o no) el aviso de "dato ilustrativo".
  final bool isWeeklyTrendSynthetic;

  const DashboardSummary({
    required this.currency,
    required this.concentratorBalanceTotal,
    required this.cardBalanceTotal,
    required this.pendingDepositsCount,
    required this.pendingDepositsAmount,
    required this.pendingOperationsCount,
    required this.pendingOperationsAmount,
    required this.openClaimsCount,
    required this.activeCardsCount,
    required this.availableCardsCount,
    required this.blockedOrFrozenCardsCount,
    required this.executedDispersionTotal,
    required this.executedDeduccionTotal,
    required this.executedTransferenciaTotal,
    required this.clientBreakdown,
    required this.attentionPendingOperations,
    required this.attentionPendingDeposits,
    required this.weeklyTrend,
    required this.isWeeklyTrendSynthetic,
  });
}
