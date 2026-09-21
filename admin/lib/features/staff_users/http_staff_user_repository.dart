import '../../core/http/kbm_backend_client.dart';
import '../../core/models/role.dart';
import '../../core/models/staff_user.dart';
import 'staff_user_repository.dart';

/// Implementación real de `StaffUserRepository` contra el backend
/// compartido — ver docs/adr/0017-staff-user-management-and-rls-on-users.md.
class HttpStaffUserRepository implements StaffUserRepository {
  HttpStaffUserRepository({required this.client});

  final KbmBackendClient client;

  Role _roleFromJson(String value) {
    switch (value) {
      case 'super_admin':
        return Role.superAdmin;
      case 'client_admin':
        return Role.clientAdmin;
      case 'operator':
        return Role.operator;
      case 'auditor':
        return Role.auditor;
      default:
        throw StateError('Rol desconocido: $value');
    }
  }

  String _roleToJson(Role role) {
    switch (role) {
      case Role.superAdmin:
        return 'super_admin';
      case Role.clientAdmin:
        return 'client_admin';
      case Role.operator:
        return 'operator';
      case Role.auditor:
        return 'auditor';
    }
  }

  StaffUser _fromJson(Map<String, dynamic> json) => StaffUser(
        id: json['id'] as String,
        clientId: json['clientId'] as String?,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: _roleFromJson(json['role'] as String),
        isActive: json['isActive'] as bool,
      );

  @override
  Future<List<StaffUser>> listByClient(String clientId) async {
    final json = await client.get('/v1/clients/$clientId/staff-users') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<StaffUser> create({
    required String clientId,
    required String email,
    required String fullName,
    required Role role,
    required String password,
  }) async {
    try {
      final json = await client.post('/v1/clients/$clientId/staff-users', {
        'email': email,
        'fullName': fullName,
        'role': _roleToJson(role),
        'password': password,
        'confirmPassword': password,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 409) throw const EmailAlreadyExistsException();
      rethrow;
    }
  }

  @override
  Future<StaffUser> update(StaffUser updated) async {
    final json = await client.put('/v1/staff-users/${updated.id}', {
      'fullName': updated.fullName,
      'role': _roleToJson(updated.role),
    }) as Map<String, dynamic>;
    return _fromJson(json);
  }

  @override
  Future<StaffUser> setActive(String userId, bool isActive) async {
    final json = await client.post('/v1/staff-users/$userId/active-status', {'active': isActive}) as Map<String, dynamic>;
    return _fromJson(json);
  }

  @override
  Future<void> resetPassword(String userId, String password) async {
    await client.post('/v1/staff-users/$userId/reset-password', {
      'password': password,
      'confirmPassword': password,
    });
  }
}
