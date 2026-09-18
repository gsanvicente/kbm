import 'persona_fisica.dart';

/// Persona física que en última instancia posee o controla un Cliente —
/// dato de cumplimiento PLD/LFPIORPI. Cada Cliente tiene exactamente un
/// beneficiario mayoritario (requerido, con su % de participación) y
/// cero o más minoritarios (opcionales) — ver
/// docs/business/kyb-cliente.md.
class BeneficiarioControlador {
  final PersonaFisica persona;
  final double porcentajeParticipacion;
  final bool isPoliticallyExposed;
  final bool esMayoritario;

  const BeneficiarioControlador({
    required this.persona,
    required this.porcentajeParticipacion,
    this.isPoliticallyExposed = false,
    required this.esMayoritario,
  });
}
