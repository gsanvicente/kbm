import '../../core/models/client.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import '../../core/models/shared/not_found_exception.dart';
import 'client_repository.dart';

/// In-memory stand-in for `GET /clients` — same clients/hierarchy as
/// backend/scripts/init-db/001_seed.sql. See
/// docs/feature/panel-principal-admin/README.md for the scope note.
class FakeClientRepository implements ClientRepository {
  final List<Client> _clients = [
    const Client(id: '00000000-0000-0000-0000-000000000001', name: 'Grupo Koons Holding'),
    const Client(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Koons Subsidiaria A',
      parentClientId: '00000000-0000-0000-0000-000000000001',
    ),
    const Client(
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

  Client? _findById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Set<String> _descendantIdsOf(String ancestorId) {
    return {
      for (final client in _clients)
        if (_isDescendantOf(client, ancestorId)) client.id,
    };
  }

  @override
  Future<Client> create(Client draft) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final created = Client(
      id: 'client-${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
      parentClientId: draft.parentClientId,
      razonSocial: draft.razonSocial,
      nombreComercial: draft.nombreComercial,
      rfc: draft.rfc,
      fechaConstitucion: draft.fechaConstitucion,
      objetoSocial: draft.objetoSocial,
      actaConstitutiva: draft.actaConstitutiva,
      addressStreet: draft.addressStreet,
      addressNeighborhood: draft.addressNeighborhood,
      addressCity: draft.addressCity,
      addressState: draft.addressState,
      addressPostalCode: draft.addressPostalCode,
      addressCountry: draft.addressCountry,
      apoderados: draft.apoderados,
      beneficiariosControladores: draft.beneficiariosControladores,
    );
    _clients.add(created);
    return created;
  }

  @override
  Future<Client> update(Client updated) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _clients.indexWhere((c) => c.id == updated.id);
    if (index == -1) throw NotFoundException('Cliente ${updated.id} no encontrado');
    final current = _clients[index];
    // parentClientId e isActive nunca vienen de `updated` — re-parentar
    // sigue fuera de alcance, y activar/desactivar es una acción propia
    // (ver setActive), no un efecto secundario de editar el expediente.
    final merged = Client(
      id: current.id,
      name: updated.name,
      parentClientId: current.parentClientId,
      isActive: current.isActive,
      razonSocial: updated.razonSocial,
      nombreComercial: updated.nombreComercial,
      rfc: updated.rfc,
      fechaConstitucion: updated.fechaConstitucion,
      objetoSocial: updated.objetoSocial,
      actaConstitutiva: updated.actaConstitutiva,
      addressStreet: updated.addressStreet,
      addressNeighborhood: updated.addressNeighborhood,
      addressCity: updated.addressCity,
      addressState: updated.addressState,
      addressPostalCode: updated.addressPostalCode,
      addressCountry: updated.addressCountry,
      apoderados: updated.apoderados,
      beneficiariosControladores: updated.beneficiariosControladores,
    );
    _clients[index] = merged;
    return merged;
  }

  @override
  Future<Client> setActive(String clientId, bool active) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_findById(clientId) == null) throw NotFoundException('Cliente $clientId no encontrado');
    final targets = {clientId, ..._descendantIdsOf(clientId)};
    for (var i = 0; i < _clients.length; i++) {
      if (targets.contains(_clients[i].id)) {
        _clients[i] = _clients[i].copyWith(isActive: active);
      }
    }
    return _findById(clientId)!;
  }

  @override
  Future<bool> isOperable(String clientId) async {
    var current = _findById(clientId);
    while (current != null) {
      if (!current.isActive) return false;
      final parentId = current.parentClientId;
      if (parentId == null) return true;
      current = _findById(parentId);
    }
    return true;
  }
}
