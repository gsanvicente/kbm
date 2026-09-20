import '../../core/http/kbm_backend_client.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/shared/cardholder_inactive_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import 'cardholder_repository.dart';

/// Implementación real de `CardholderRepository` (expediente KYC que
/// admin/ gestiona — distinto del login del portal de autoservicio, que
/// ya migró antes) contra el backend compartido — ver
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
/// Reemplaza a `FakeCardholderRepository`.
class HttpCardholderRepository implements CardholderRepository {
  HttpCardholderRepository({required this.client});

  final KbmBackendClient client;

  // id_document_type viaja en mayúsculas/snake_case desde Postgres — ver
  // la misma nota en HttpClientRepository.
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

  Map<String, dynamic> _toJson(Cardholder c) => {
        'clientId': c.clientId,
        'fullName': c.fullName,
        'idDocumentType': _idDocTypeToJson(c.idDocumentType),
        'idDocumentNumber': c.idDocumentNumber,
        'curp': c.curp,
        'rfc': c.rfc,
        'dateOfBirth': c.dateOfBirth?.toIso8601String(),
        'nationality': c.nationality,
        'addressStreet': c.addressStreet,
        'addressNeighborhood': c.addressNeighborhood,
        'addressCity': c.addressCity,
        'addressState': c.addressState,
        'addressPostalCode': c.addressPostalCode,
        'addressCountry': c.addressCountry,
        'isPoliticallyExposed': c.isPoliticallyExposed,
        'email': c.email,
        'phone': c.phone,
        'isActive': c.isActive,
      };

  Cardholder _fromJson(Map<String, dynamic> json) => Cardholder(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        fullName: json['fullName'] as String,
        idDocumentType: _idDocTypeFromJson(json['idDocumentType'] as String),
        idDocumentNumber: json['idDocumentNumber'] as String,
        curp: json['curp'] as String?,
        rfc: json['rfc'] as String?,
        dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth'] as String) : null,
        nationality: json['nationality'] as String,
        addressStreet: json['addressStreet'] as String?,
        addressNeighborhood: json['addressNeighborhood'] as String?,
        addressCity: json['addressCity'] as String?,
        addressState: json['addressState'] as String?,
        addressPostalCode: json['addressPostalCode'] as String?,
        addressCountry: json['addressCountry'] as String,
        isPoliticallyExposed: json['isPoliticallyExposed'] as bool,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        isActive: json['isActive'] as bool,
      );

  @override
  Future<List<Cardholder>> listByClient(String clientId) async {
    final json = await client.get('/v1/cardholders?client_id=$clientId') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Cardholder>> listByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/cardholders?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Cardholder?> getById(String cardholderId) async {
    try {
      final json = await client.get('/v1/cardholders/$cardholderId') as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Cardholder> create(Cardholder draft) async {
    final json = await client.post('/v1/cardholders', _toJson(draft)) as Map<String, dynamic>;
    return _fromJson(json);
  }

  @override
  Future<Cardholder> update(Cardholder cardholder) async {
    try {
      final json = await client.put('/v1/cardholders/${cardholder.id}', _toJson(cardholder)) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 403) throw const CardholderInactiveException();
      if (e.statusCode == 404) throw NotFoundException('Tarjetahabiente ${cardholder.id} no encontrado');
      rethrow;
    }
  }

  @override
  Future<Cardholder> setActive(String cardholderId, bool isActive) async {
    final json = await client.post('/v1/cardholders/$cardholderId/active-status', {'active': isActive}) as Map<String, dynamic>;
    return _fromJson(json);
  }

  @override
  Future<bool> isOperable(String cardholderId) async {
    final c = await getById(cardholderId);
    return c != null && c.isActive;
  }
}
