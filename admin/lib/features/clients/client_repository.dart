import '../../core/models/client.dart';
import '../../core/models/session.dart';

abstract class ClientRepository {
  /// Returns the Clientes visible to [session]: its own client plus every
  /// descendant in the hierarchy (see docs/business/roles-and-permissions.md)
  /// — or every client in the system for Role.superAdmin.
  Future<List<Client>> listAccessibleClients(Session session);

  /// Crea un nuevo Cliente con su expediente KYB completo — ver
  /// docs/feature/alta-y-gestion-de-clientes/README.md. [draft.id] se
  /// ignora, el repositorio asigna uno nuevo. `draft.parentClientId` ya
  /// determina dónde queda en la jerarquía; validar que ese padre esté
  /// dentro del alcance de quien lo crea es responsabilidad de la UI
  /// (mismo criterio que el resto de la app — ver `AuthorizationPort` en
  /// el backend real para la capa que hará cumplir esto del lado
  /// servidor).
  Future<Client> create(Client draft);

  /// Actualiza el expediente KYB de un Cliente ya existente —
  /// `updated.parentClientId` se ignora (re-parentar sigue fuera de
  /// alcance, ver docs/feature/alta-y-gestion-de-clientes/README.md) y
  /// `updated.isActive` también (usar [setActive] para eso). Un Cliente
  /// inactivo puede seguir editándose.
  Future<Client> update(Client updated);

  /// Cambia `is_active` para [clientId] y, en cascada, para **todos**
  /// sus descendientes — ver
  /// docs/business/desactivacion-de-clientes.md. Simétrico: reactivar
  /// también cascada hacia los descendientes, sin excepción. Devuelve el
  /// Cliente [clientId] ya actualizado (no la lista completa de
  /// descendientes afectados — la UI que lo llama ya sabe cuál pidió).
  Future<Client> setActive(String clientId, bool active);

  /// true solo si [clientId] **y toda su cadena de ancestros** están
  /// activos — Capa 2 de enforcement (ver
  /// docs/business/desactivacion-de-clientes.md, "Enforcement: dos
  /// capas"). Toda acción que mueva dinero o cambie estado debe
  /// verificar esto antes de ejecutarse, sin importar quién la pida.
  Future<bool> isOperable(String clientId);
}
