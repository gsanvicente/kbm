import 'persona_fisica.dart';
import 'tipo_poder.dart';

/// Persona física con poder notarial para actuar en nombre de un Cliente
/// frente a KBM. Cada Cliente tiene exactamente un apoderado principal
/// (requerido) y cero o más adicionales (opcionales) — ver
/// docs/business/kyb-cliente.md.
class ApoderadoLegal {
  final PersonaFisica persona;
  final TipoPoder tipoPoder;

  /// Solo aplica (y es requerido) cuando [tipoPoder] es
  /// [TipoPoder.especial] — ver [TipoPoder.requiereDescripcion].
  final String? descripcionPoderEspecial;

  final String numeroEscritura;
  final String notario;
  final DateTime fechaInstrumento;

  /// Opcional — no todo poder notarial tiene fecha de expiración.
  final DateTime? vigencia;

  final bool esPrincipal;

  ApoderadoLegal({
    required this.persona,
    required this.tipoPoder,
    this.descripcionPoderEspecial,
    required this.numeroEscritura,
    required this.notario,
    required this.fechaInstrumento,
    this.vigencia,
    required this.esPrincipal,
  }) : assert(
          !tipoPoder.requiereDescripcion || descripcionPoderEspecial != null,
          'Un poder especial requiere describir sus facultades — ver docs/business/kyb-cliente.md',
        );
}
