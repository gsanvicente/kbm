import '../../core/http/kbm_backend_client.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import 'auth_repository.dart';

/// Implementación real de `AuthRepository` (login administrativo) contra
/// el backend compartido — ver
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
/// Reemplaza a `FakeAuthRepository`.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required this.client});

  final KbmBackendClient client;

  @override
  Future<Session> login({required String email, required String password}) async {
    try {
      final json = await client.post('/v1/staff-sessions', {
        'email': email,
        'password': password,
      }) as Map<String, dynamic>;
      return Session(
        userId: json['userId'] as String,
        email: json['email'] as String,
        role: _roleFromJson(json['role'] as String),
        clientId: json['clientId'] as String?,
      );
    } on KbmBackendException catch (e) {
      // El backend ya usa el mismo mensaje genérico
      // ("Email o contraseña incorrectos.") — ver
      // docs/feature/login-administrativo/README.md.
      throw AuthException(e.message);
    }
  }

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
}
