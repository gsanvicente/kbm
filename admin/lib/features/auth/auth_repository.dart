import '../../core/models/session.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

abstract class AuthRepository {
  /// Throws [AuthException] with a generic message on invalid credentials
  /// or an inactive user — never reveals which of the two it was (avoids
  /// user enumeration, see docs/feature/login-administrativo/README.md).
  Future<Session> login({required String email, required String password});

  /// Limpia cualquier credencial de sesión guardada localmente (el JWT en
  /// `HttpAuthRepository`; no-op en `FakeAuthRepository`) — ver
  /// docs/adr/0013-jwt-session-authentication.md.
  void logout();
}
