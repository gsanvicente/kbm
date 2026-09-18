/// Datos del instrumento notarial que constituye legalmente a un Cliente
/// — ver docs/business/kyb-cliente.md. Solo datos estructurados en esta
/// iteración, sin carga del PDF real.
class ActaConstitutiva {
  final String numeroEscritura;
  final String notario;
  final String plaza;
  final DateTime fecha;
  final String folioRPC;

  const ActaConstitutiva({
    required this.numeroEscritura,
    required this.notario,
    required this.plaza,
    required this.fecha,
    required this.folioRPC,
  });
}
