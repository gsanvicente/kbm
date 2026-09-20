import '../../core/http/kbm_backend_client.dart';
import '../../core/models/acta_constitutiva.dart';
import '../../core/models/apoderado_legal.dart';
import '../../core/models/beneficiario_controlador.dart';
import '../../core/models/client.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/persona_fisica.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import '../../core/models/tipo_poder.dart';
import 'client_repository.dart';

/// Implementación real de `ClientRepository` contra el backend
/// compartido — ver
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
/// Reemplaza a `FakeClientRepository`. Sin filtrado por rol/sesión en el
/// backend (no hay AuthorizationPort todavía, ver
/// internal/application/ports/doc.go) — [listAccessibleClients] hace el
/// mismo filtrado client-side que ya hacía la versión fake.
class HttpClientRepository implements ClientRepository {
  HttpClientRepository({required this.client});

  final KbmBackendClient client;

  // id_document_type y tipo_poder viajan en snake_case/mayúsculas desde
  // Postgres (mismo shape que backend/migrations/0001_init.sql) — no
  // coinciden con los identificadores Dart (camelCase), así que se
  // mapean a mano en vez de `.byName()`.
  String _idDocTypeToJson(IdDocumentType t) {
    switch (t) {
      case IdDocumentType.ine:
        return 'INE';
      case IdDocumentType.pasaporte:
        return 'pasaporte';
      case IdDocumentType.cedulaProfesional:
        return 'cedula_profesional';
    }
  }

  IdDocumentType _idDocTypeFromJson(String v) {
    switch (v) {
      case 'INE':
        return IdDocumentType.ine;
      case 'pasaporte':
        return IdDocumentType.pasaporte;
      case 'cedula_profesional':
        return IdDocumentType.cedulaProfesional;
      default:
        return IdDocumentType.ine;
    }
  }

  String _tipoPoderToJson(TipoPoder t) {
    switch (t) {
      case TipoPoder.actosDeAdministracion:
        return 'actos_de_administracion';
      case TipoPoder.pleitosYCobranzas:
        return 'pleitos_y_cobranzas';
      case TipoPoder.actosDeDominio:
        return 'actos_de_dominio';
      case TipoPoder.especial:
        return 'especial';
    }
  }

  TipoPoder _tipoPoderFromJson(String v) {
    switch (v) {
      case 'actos_de_administracion':
        return TipoPoder.actosDeAdministracion;
      case 'pleitos_y_cobranzas':
        return TipoPoder.pleitosYCobranzas;
      case 'actos_de_dominio':
        return TipoPoder.actosDeDominio;
      case 'especial':
        return TipoPoder.especial;
      default:
        return TipoPoder.actosDeAdministracion;
    }
  }

  Map<String, dynamic> _personaToJson(PersonaFisica p) => {
        'fullName': p.fullName,
        'idDocumentType': _idDocTypeToJson(p.idDocumentType),
        'idDocumentNumber': p.idDocumentNumber,
        'curp': p.curp,
        'rfc': p.rfc,
      };

  PersonaFisica _personaFromJson(Map<String, dynamic> json) => PersonaFisica(
        fullName: json['fullName'] as String,
        idDocumentType: _idDocTypeFromJson(json['idDocumentType'] as String),
        idDocumentNumber: json['idDocumentNumber'] as String,
        curp: json['curp'] as String?,
        rfc: json['rfc'] as String?,
      );

  Map<String, dynamic> _apoderadoToJson(ApoderadoLegal a) => {
        'persona': _personaToJson(a.persona),
        'tipoPoder': _tipoPoderToJson(a.tipoPoder),
        'descripcionPoderEspecial': a.descripcionPoderEspecial,
        'numeroEscritura': a.numeroEscritura,
        'notario': a.notario,
        'fechaInstrumento': a.fechaInstrumento.toIso8601String(),
        'vigencia': a.vigencia?.toIso8601String(),
        'esPrincipal': a.esPrincipal,
      };

  ApoderadoLegal _apoderadoFromJson(Map<String, dynamic> json) => ApoderadoLegal(
        persona: _personaFromJson(json['persona'] as Map<String, dynamic>),
        tipoPoder: _tipoPoderFromJson(json['tipoPoder'] as String),
        descripcionPoderEspecial: json['descripcionPoderEspecial'] as String?,
        numeroEscritura: json['numeroEscritura'] as String,
        notario: json['notario'] as String,
        fechaInstrumento: DateTime.parse(json['fechaInstrumento'] as String),
        vigencia: json['vigencia'] != null ? DateTime.parse(json['vigencia'] as String) : null,
        esPrincipal: json['esPrincipal'] as bool,
      );

  Map<String, dynamic> _beneficiarioToJson(BeneficiarioControlador b) => {
        'persona': _personaToJson(b.persona),
        'porcentajeParticipacion': b.porcentajeParticipacion,
        'isPoliticallyExposed': b.isPoliticallyExposed,
        'esMayoritario': b.esMayoritario,
      };

  BeneficiarioControlador _beneficiarioFromJson(Map<String, dynamic> json) => BeneficiarioControlador(
        persona: _personaFromJson(json['persona'] as Map<String, dynamic>),
        porcentajeParticipacion: (json['porcentajeParticipacion'] as num).toDouble(),
        isPoliticallyExposed: json['isPoliticallyExposed'] as bool,
        esMayoritario: json['esMayoritario'] as bool,
      );

  Map<String, dynamic> _clientToJson(Client c) => {
        'name': c.name,
        'parentClientId': c.parentClientId,
        'razonSocial': c.razonSocial,
        'nombreComercial': c.nombreComercial,
        'rfc': c.rfc,
        'fechaConstitucion': c.fechaConstitucion?.toIso8601String(),
        'objetoSocial': c.objetoSocial,
        'actaConstitutiva': c.actaConstitutiva == null
            ? null
            : {
                'numeroEscritura': c.actaConstitutiva!.numeroEscritura,
                'notario': c.actaConstitutiva!.notario,
                'plaza': c.actaConstitutiva!.plaza,
                'fecha': c.actaConstitutiva!.fecha.toIso8601String(),
                'folioRPC': c.actaConstitutiva!.folioRPC,
              },
        'addressStreet': c.addressStreet,
        'addressNeighborhood': c.addressNeighborhood,
        'addressCity': c.addressCity,
        'addressState': c.addressState,
        'addressPostalCode': c.addressPostalCode,
        'addressCountry': c.addressCountry,
        'apoderados': c.apoderados.map(_apoderadoToJson).toList(),
        'beneficiariosControladores': c.beneficiariosControladores.map(_beneficiarioToJson).toList(),
      };

  Client _clientFromJson(Map<String, dynamic> json) {
    final actaJson = json['actaConstitutiva'] as Map<String, dynamic>?;
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      parentClientId: json['parentClientId'] as String?,
      isActive: json['isActive'] as bool,
      razonSocial: json['razonSocial'] as String?,
      nombreComercial: json['nombreComercial'] as String?,
      rfc: json['rfc'] as String?,
      fechaConstitucion: json['fechaConstitucion'] != null ? DateTime.parse(json['fechaConstitucion'] as String) : null,
      objetoSocial: json['objetoSocial'] as String?,
      actaConstitutiva: actaJson == null
          ? null
          : ActaConstitutiva(
              numeroEscritura: actaJson['numeroEscritura'] as String,
              notario: actaJson['notario'] as String,
              plaza: actaJson['plaza'] as String,
              fecha: DateTime.parse(actaJson['fecha'] as String),
              folioRPC: actaJson['folioRPC'] as String,
            ),
      addressStreet: json['addressStreet'] as String?,
      addressNeighborhood: json['addressNeighborhood'] as String?,
      addressCity: json['addressCity'] as String?,
      addressState: json['addressState'] as String?,
      addressPostalCode: json['addressPostalCode'] as String?,
      addressCountry: json['addressCountry'] as String,
      apoderados: (json['apoderados'] as List<dynamic>).map((e) => _apoderadoFromJson(e as Map<String, dynamic>)).toList(),
      beneficiariosControladores: (json['beneficiariosControladores'] as List<dynamic>)
          .map((e) => _beneficiarioFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Client>> _listAll() async {
    final json = await client.get('/v1/clients') as List<dynamic>;
    return json.map((e) => _clientFromJson(e as Map<String, dynamic>)).toList();
  }

  bool _isDescendantOf(Client c, List<Client> all, String? ancestorId) {
    var current = c;
    while (current.parentClientId != null) {
      if (current.parentClientId == ancestorId) return true;
      current = all.firstWhere((x) => x.id == current.parentClientId);
    }
    return false;
  }

  @override
  Future<List<Client>> listAccessibleClients(Session session) async {
    final all = await _listAll();
    if (session.role == Role.superAdmin) return all;
    final rootId = session.clientId;
    return all.where((c) => c.id == rootId || _isDescendantOf(c, all, rootId)).toList();
  }

  @override
  Future<Client> create(Client draft) async {
    final json = await client.post('/v1/clients', _clientToJson(draft)) as Map<String, dynamic>;
    return _clientFromJson(json);
  }

  @override
  Future<Client> update(Client updated) async {
    final json = await client.put('/v1/clients/${updated.id}', _clientToJson(updated)) as Map<String, dynamic>;
    return _clientFromJson(json);
  }

  @override
  Future<Client> setActive(String clientId, bool active) async {
    final json = await client.post('/v1/clients/$clientId/active-status', {'active': active}) as Map<String, dynamic>;
    return _clientFromJson(json);
  }

  @override
  Future<bool> isOperable(String clientId) async {
    final json = await client.get('/v1/clients/$clientId/operable') as Map<String, dynamic>;
    return json['operable'] as bool;
  }
}
