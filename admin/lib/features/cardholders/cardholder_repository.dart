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

  Future<Cardholder?> getById(String cardholderId);

  /// Da de alta un nuevo Tarjetahabiente — ver
  /// docs/feature/alta-y-gestion-de-tarjetahabientes/README.md.
  /// [draft.id] se ignora, el repositorio asigna uno nuevo.
  /// [draft.clientId] queda fijo, resuelto por el contexto desde el que
  /// se crea (la pestaña de Tarjetahabientes de un Cliente específico).
  Future<Cardholder> create(Cardholder draft);

  /// Actualiza el expediente de un Tarjetahabiente ya existente.
  /// `cardholder.clientId` e `isActive` se ignoran (mover de Cliente sigue
  /// fuera de alcance; usar [setActive] para el estado). Lanza
  /// [CardholderInactiveException] si el Tarjetahabiente está inactivo —
  /// a diferencia de Cliente, aquí **no** se permite editar mientras está
  /// inactivo, ver docs/business/desactivacion-de-tarjetahabientes.md.
  Future<Cardholder> update(Cardholder cardholder);

  Future<Cardholder> setActive(String cardholderId, bool isActive);

  /// true solo si el Tarjetahabiente existe y está activo — Capa 2 de
  /// enforcement (ver docs/business/desactivacion-de-tarjetahabientes.md).
  /// Sin cadena de ancestros (a diferencia de
  /// `ClientRepository.isOperable`) — un Tarjetahabiente no tiene
  /// descendientes.
  Future<bool> isOperable(String cardholderId);
}
