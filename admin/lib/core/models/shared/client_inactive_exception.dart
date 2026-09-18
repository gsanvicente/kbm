/// Lanzada por cualquier acción que mueva dinero o cambie estado cuando
/// el Cliente involucrado (o alguno de sus ancestros) está inactivo —
/// Capa 2 de enforcement, ver docs/business/desactivacion-de-clientes.md.
/// Nunca depende de que la UI ya haya ocultado el botón correspondiente.
class ClientInactiveException implements Exception {
  final String message;
  const ClientInactiveException([this.message = 'Esta empresa está inactiva y no puede operar.']);

  @override
  String toString() => message;
}
