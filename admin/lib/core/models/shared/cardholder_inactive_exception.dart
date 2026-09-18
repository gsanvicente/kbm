/// Lanzada por cualquier acción que intente asignar una tarjeta nueva a,
/// editar, o desbloquear una tarjeta de un Tarjetahabiente inactivo —
/// Capa 2 de enforcement, ver
/// docs/business/desactivacion-de-tarjetahabientes.md. Nunca depende de
/// que la UI ya haya ocultado el control correspondiente.
class CardholderInactiveException implements Exception {
  final String message;
  const CardholderInactiveException([this.message = 'Este tarjetahabiente está inactivo y no puede operar.']);

  @override
  String toString() => message;
}
