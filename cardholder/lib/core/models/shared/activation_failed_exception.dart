/// Mensaje genérico a propósito — nunca distingue "el email no existe" de
/// "el documento no coincide" de "la cuenta ya fue activada" de "el
/// Tarjetahabiente está inactivo" de "se agotaron los intentos" — ver
/// docs/adr/0019-cardholder-self-activation.md y
/// docs/security/threat-model.md punto 16.
class ActivationFailedException implements Exception {
  final String message;
  const ActivationFailedException([this.message = 'No pudimos verificar tus datos. Contacta a tu administrador.']);

  @override
  String toString() => message;
}
