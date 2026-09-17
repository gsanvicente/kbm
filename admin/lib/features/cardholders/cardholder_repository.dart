import '../../core/models/cardholder.dart';

abstract class CardholderRepository {
  /// Tarjetahabientes de un único Cliente. No hierarchy resolution here —
  /// the caller already establishes access to clientId via
  /// ClientRepository.listAccessibleClients.
  Future<List<Cardholder>> listByClient(String clientId);

  /// Tarjetahabientes de cualquiera de [clientIds] — usado por el listado
  /// global (docs/feature/listado-global-tarjetahabientes/), donde el
  /// llamador ya resolvió qué Clientes son accesibles.
  Future<List<Cardholder>> listByClients(List<String> clientIds);

  Future<Cardholder> update(Cardholder cardholder);

  Future<Cardholder> setActive(String cardholderId, bool isActive);
}
