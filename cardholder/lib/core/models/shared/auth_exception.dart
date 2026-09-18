/// Mismo criterio que `admin`'s login: un solo mensaje genérico, nunca
/// distingue "email no existe" de "contraseña incorrecta" ni "cuenta
/// inactiva" — ver docs/feature/login-administrativo/README.md.
class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Email o contraseña incorrectos.']);

  @override
  String toString() => message;
}
