/// Lanzada al superar el límite de intentos fallidos resolviendo el
/// destino de una transferencia C2C — mitigación de enumeración, ver
/// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Seguridad"
/// y docs/security/threat-model.md punto 12. El límite es por sesión: se
/// reinicia en el siguiente login, nunca dentro de la misma sesión.
class TooManyFailedAttemptsException implements Exception {
  final String message;
  const TooManyFailedAttemptsException([
    this.message =
        'Demasiados intentos fallidos. Vuelve a iniciar sesión para intentar una transferencia de nuevo.',
  ]);

  @override
  String toString() => message;
}
