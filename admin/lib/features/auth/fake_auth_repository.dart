import '../../core/models/role.dart';
import '../../core/models/session.dart';
import '../clients/client_repository.dart';
import 'auth_repository.dart';

class _FakeUser {
  final String id;
  final String email;
  final String password;
  final Role role;
  final String? clientId;
  final bool isActive;

  const _FakeUser({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    this.clientId,
    this.isActive = true,
  });
}

/// In-memory stand-in for the real `POST /auth/login` backend call — same
/// users/passwords as backend/scripts/init-db/001_seed.sql, so swapping in
/// the real HTTP-backed AuthRepository later requires no UI changes.
/// See docs/feature/login-administrativo/README.md for the scope note.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.clientRepository});

  /// Para verificar, además del propio usuario, que su Cliente (y toda
  /// su cadena de ancestros) esté activo — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 1 — bloqueo de
  /// login".
  final ClientRepository clientRepository;

  static const _password = 'LocalDevOnly123!';

  static const _users = [
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000001',
      email: 'super.admin@koons.test',
      password: _password,
      role: Role.superAdmin,
    ),
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000002',
      email: 'admin.holding@koons.test',
      password: _password,
      role: Role.clientAdmin,
      clientId: '00000000-0000-0000-0000-000000000001',
    ),
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000003',
      email: 'admin.subA@koons.test',
      password: _password,
      role: Role.clientAdmin,
      clientId: '00000000-0000-0000-0000-000000000002',
    ),
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000004',
      email: 'operador.subA@koons.test',
      password: _password,
      role: Role.operator,
      clientId: '00000000-0000-0000-0000-000000000002',
    ),
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000005',
      email: 'auditor.subA@koons.test',
      password: _password,
      role: Role.auditor,
      clientId: '00000000-0000-0000-0000-000000000002',
    ),
    // Fake-only, not in the real seed: exists to exercise the "usuario
    // inactivo" scenario in acceptance.feature without a real backend.
    _FakeUser(
      id: '10000000-0000-0000-0000-000000000099',
      email: 'usuario.inactivo@koons.test',
      password: _password,
      role: Role.operator,
      clientId: '00000000-0000-0000-0000-000000000002',
      isActive: false,
    ),
  ];

  static const _genericError = AuthException('Email o contraseña incorrectos.');

  @override
  Future<Session> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _FakeUser? user;
    for (final candidate in _users) {
      if (candidate.email == email) {
        user = candidate;
        break;
      }
    }
    if (user == null || user.password != password || !user.isActive) {
      throw _genericError;
    }
    // Super Admin no tiene clientId (alcance global) — nunca se ve
    // afectado por el estado de ningún Cliente en particular.
    if (user.clientId != null && !await clientRepository.isOperable(user.clientId!)) {
      throw _genericError;
    }

    return Session(
      userId: user.id,
      email: user.email,
      role: user.role,
      clientId: user.clientId,
    );
  }
}
