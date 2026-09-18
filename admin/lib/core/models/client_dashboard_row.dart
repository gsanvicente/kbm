/// Una fila del desglose por empresa del Panel directivo — solo se
/// muestra cuando el usuario tiene más de un Cliente en su alcance (ver
/// docs/feature/panel-directivo/README.md).
class ClientDashboardRow {
  final String clientId;
  final String clientName;
  final double concentratorBalance;
  final int activeCardsCount;
  final int pendingOperationsCount;
  final int pendingDepositsCount;

  const ClientDashboardRow({
    required this.clientId,
    required this.clientName,
    required this.concentratorBalance,
    required this.activeCardsCount,
    required this.pendingOperationsCount,
    required this.pendingDepositsCount,
  });
}
