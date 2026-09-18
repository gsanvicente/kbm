import '../../core/models/dashboard_summary.dart';
import '../../core/models/session.dart';

/// Fuente de datos del Panel directivo ("Inicio") — ver
/// docs/feature/panel-directivo/README.md. A diferencia del resto de los
/// repositorios de esta app, no es un puerto 1:1 hacia un recurso propio:
/// compone ClientRepository/CardRepository/LedgerRepository/
/// TreasuryRepository/BalanceOperationRepository, igual que un backend
/// real probablemente serviría este panel desde un endpoint agregado
/// dedicado en vez de recomponerlo en el cliente.
abstract class DashboardRepository {
  /// Alcance resuelto internamente a partir de [session] (el mismo Cliente
  /// propio + descendientes que ya usa `ClientRepository.listAccessibleClients`).
  Future<DashboardSummary> getSummary(Session session);
}
