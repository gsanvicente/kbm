import '../../core/models/client.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import 'client_repository.dart';

/// In-memory stand-in for `GET /clients` — same clients/hierarchy as
/// backend/scripts/init-db/001_seed.sql. See
/// docs/feature/panel-principal-admin/README.md for the scope note.
class FakeClientRepository implements ClientRepository {
  static const _clients = [
    Client(id: '00000000-0000-0000-0000-000000000001', name: 'Grupo Koons Holding'),
    Client(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Koons Subsidiaria A',
      parentClientId: '00000000-0000-0000-0000-000000000001',
    ),
    Client(
      id: '00000000-0000-0000-0000-000000000003',
      name: 'Koons Subsidiaria B',
      parentClientId: '00000000-0000-0000-0000-000000000001',
    ),
  ];

  @override
  Future<List<Client>> listAccessibleClients(Session session) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (session.role == Role.superAdmin) {
      return _clients;
    }

    final rootId = session.clientId;
    return _clients.where((c) => c.id == rootId || _isDescendantOf(c, rootId)).toList();
  }

  bool _isDescendantOf(Client client, String? ancestorId) {
    var current = client;
    while (current.parentClientId != null) {
      if (current.parentClientId == ancestorId) return true;
      current = _clients.firstWhere((c) => c.id == current.parentClientId);
    }
    return false;
  }
}
