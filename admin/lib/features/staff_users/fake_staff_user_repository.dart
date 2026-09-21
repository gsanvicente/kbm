import '../../core/models/role.dart';
import '../../core/models/staff_user.dart';
import 'staff_user_repository.dart';

/// In-memory stand-in — mismos usuarios que
/// backend/scripts/init-db/001_seed.sql (menos Super Admin, que nunca se
/// lista "dentro" de ningún Cliente). Mutable, como el resto de los
/// repositorios fake que ya introdujeron alta/edición/desactivación real
/// (ver FakeCardholderRepository).
class FakeStaffUserRepository implements StaffUserRepository {
  final List<StaffUser> _users = [
    const StaffUser(
      id: '10000000-0000-0000-0000-000000000002',
      clientId: '00000000-0000-0000-0000-000000000001',
      email: 'admin.holding@koons.test',
      fullName: 'Admin Holding',
      role: Role.clientAdmin,
    ),
    const StaffUser(
      id: '10000000-0000-0000-0000-000000000003',
      clientId: '00000000-0000-0000-0000-000000000002',
      email: 'admin.subA@koons.test',
      fullName: 'Admin Subsidiaria A',
      role: Role.clientAdmin,
    ),
    const StaffUser(
      id: '10000000-0000-0000-0000-000000000004',
      clientId: '00000000-0000-0000-0000-000000000002',
      email: 'operador.subA@koons.test',
      fullName: 'Operador Subsidiaria A',
      role: Role.operator,
    ),
    const StaffUser(
      id: '10000000-0000-0000-0000-000000000005',
      clientId: '00000000-0000-0000-0000-000000000002',
      email: 'auditor.subA@koons.test',
      fullName: 'Auditor Subsidiaria A',
      role: Role.auditor,
    ),
  ];

  @override
  Future<List<StaffUser>> listByClient(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _users.where((u) => u.clientId == clientId).toList();
  }

  @override
  Future<StaffUser> create({
    required String clientId,
    required String email,
    required String fullName,
    required Role role,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw const EmailAlreadyExistsException();
    }
    final created = StaffUser(
      id: 'staff-user-${DateTime.now().microsecondsSinceEpoch}',
      clientId: clientId,
      email: email,
      fullName: fullName,
      role: role,
    );
    _users.add(created);
    return created;
  }

  @override
  Future<StaffUser> update(StaffUser updated) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _users.indexWhere((u) => u.id == updated.id);
    if (index == -1) throw StateError('Usuario ${updated.id} no encontrado');
    final merged = _users[index].copyWith(fullName: updated.fullName, role: updated.role);
    _users[index] = merged;
    return merged;
  }

  @override
  Future<StaffUser> setActive(String userId, bool isActive) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) throw StateError('Usuario $userId no encontrado');
    final updated = _users[index].copyWith(isActive: isActive);
    _users[index] = updated;
    return updated;
  }

  @override
  Future<void> resetPassword(String userId, String password) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // La fake no simula login de staff con contraseña real — no hay
    // nada que persistir aquí más allá de aceptar la operación.
  }
}
