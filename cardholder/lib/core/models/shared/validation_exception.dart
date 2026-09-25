/// Un 400 genérico del backend (shared.ErrValidation) — cubre CLABE mal
/// formada, código de banco desconocido, la propia CLABE como
/// beneficiario, o un monto que excede el tope del periodo de
/// enfriamiento. El backend nunca distingue cuál a propósito (mismo
/// criterio "nunca revela el motivo exacto" que el resto del proyecto en
/// validaciones de seguridad) — [message] es genérico, no el mensaje
/// literal del backend.
class ValidationException implements Exception {
  final String message;
  const ValidationException([
    this.message = 'Revisa los datos e intenta de nuevo.',
  ]);

  @override
  String toString() => message;
}
