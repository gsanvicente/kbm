import '../../core/models/client.dart';
import '../../core/models/session.dart';

abstract class ClientRepository {
  /// Returns the Clientes visible to [session]: its own client plus every
  /// descendant in the hierarchy (see docs/business/roles-and-permissions.md)
  /// — or every client in the system for Role.superAdmin.
  Future<List<Client>> listAccessibleClients(Session session);
}
