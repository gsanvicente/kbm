import 'acta_constitutiva.dart';
import 'apoderado_legal.dart';
import 'beneficiario_controlador.dart';

/// [razonSocial] en adelante son el expediente KYB (persona moral) — ver
/// docs/business/kyb-cliente.md. Opcionales a nivel de tipo (igual que
/// Cardholder.curp/rfc) para no romper Clientes sembrados sin expediente
/// completo; el formulario de alta exige los campos de negocio
/// requeridos antes de permitir crear uno nuevo — ver
/// docs/feature/alta-y-gestion-de-clientes/README.md.
class Client {
  final String id;
  final String name;
  final String? parentClientId;

  /// Ver docs/business/desactivacion-de-clientes.md — desactivar se
  /// propaga en cascada a todos los descendientes, y bloquea cualquier
  /// acción operativa dentro de ese alcance (ver `ClientRepository.isOperable`).
  final bool isActive;

  final String? razonSocial;
  final String? nombreComercial;
  final String? rfc;
  final DateTime? fechaConstitucion;
  final String? objetoSocial;
  final ActaConstitutiva? actaConstitutiva;

  // Domicilio fiscal — mismo shape plano que Cardholder.
  final String? addressStreet;
  final String? addressNeighborhood;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;
  final String addressCountry;

  /// Cada Cliente tiene exactamente un apoderado con `esPrincipal: true`
  /// una vez dado de alta con su expediente completo — ver
  /// [apoderadoPrincipal].
  final List<ApoderadoLegal> apoderados;

  /// Cada Cliente tiene exactamente un beneficiario con
  /// `esMayoritario: true` una vez dado de alta — ver
  /// [beneficiarioMayoritario].
  final List<BeneficiarioControlador> beneficiariosControladores;

  const Client({
    required this.id,
    required this.name,
    this.parentClientId,
    this.isActive = true,
    this.razonSocial,
    this.nombreComercial,
    this.rfc,
    this.fechaConstitucion,
    this.objetoSocial,
    this.actaConstitutiva,
    this.addressStreet,
    this.addressNeighborhood,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
    this.addressCountry = 'México',
    this.apoderados = const [],
    this.beneficiariosControladores = const [],
  });

  ApoderadoLegal? get apoderadoPrincipal {
    for (final apoderado in apoderados) {
      if (apoderado.esPrincipal) return apoderado;
    }
    return null;
  }

  BeneficiarioControlador? get beneficiarioMayoritario {
    for (final beneficiario in beneficiariosControladores) {
      if (beneficiario.esMayoritario) return beneficiario;
    }
    return null;
  }

  Client copyWith({
    String? name,
    bool? isActive,
    String? razonSocial,
    String? nombreComercial,
    String? rfc,
    DateTime? fechaConstitucion,
    String? objetoSocial,
    ActaConstitutiva? actaConstitutiva,
    String? addressStreet,
    String? addressNeighborhood,
    String? addressCity,
    String? addressState,
    String? addressPostalCode,
    String? addressCountry,
    List<ApoderadoLegal>? apoderados,
    List<BeneficiarioControlador>? beneficiariosControladores,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      parentClientId: parentClientId,
      isActive: isActive ?? this.isActive,
      razonSocial: razonSocial ?? this.razonSocial,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      rfc: rfc ?? this.rfc,
      fechaConstitucion: fechaConstitucion ?? this.fechaConstitucion,
      objetoSocial: objetoSocial ?? this.objetoSocial,
      actaConstitutiva: actaConstitutiva ?? this.actaConstitutiva,
      addressStreet: addressStreet ?? this.addressStreet,
      addressNeighborhood: addressNeighborhood ?? this.addressNeighborhood,
      addressCity: addressCity ?? this.addressCity,
      addressState: addressState ?? this.addressState,
      addressPostalCode: addressPostalCode ?? this.addressPostalCode,
      addressCountry: addressCountry ?? this.addressCountry,
      apoderados: apoderados ?? this.apoderados,
      beneficiariosControladores: beneficiariosControladores ?? this.beneficiariosControladores,
    );
  }
}
