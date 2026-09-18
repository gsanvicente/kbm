import '../../core/models/cardholder.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/shared/cardholder_inactive_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import 'cardholder_repository.dart';

/// In-memory stand-in for the cardholder endpoints — same seed data as
/// backend/scripts/init-db/001_seed.sql (CURP/RFC values are fabricated,
/// structurally plausible test data only). Mutable (unlike the other fake
/// repositories) since docs/feature/alta-y-gestion-de-tarjetahabientes/
/// introduces real create/edit/deactivate actions. Changes live only for
/// the current app session — expected fake-repository behavior, not a bug.
class FakeCardholderRepository implements CardholderRepository {
  FakeCardholderRepository({this.onDeactivated});

  /// Hook invocado justo después de que `setActive(id, false)` aplica el
  /// cambio — usado por `app.dart` para disparar el congelamiento de
  /// tarjetas (`CardRepository.freezeAllForCardholder`) sin que este
  /// repositorio dependa de `CardRepository` (evita una dependencia
  /// circular, ver docs/business/desactivacion-de-tarjetahabientes.md).
  final Future<void> Function(String cardholderId)? onDeactivated;

  final List<Cardholder> _cardholders = [
    Cardholder(
      id: '20000000-0000-0000-0000-000000000001',
      clientId: '00000000-0000-0000-0000-000000000002',
      fullName: 'Juan Perez',
      idDocumentType: IdDocumentType.ine,
      idDocumentNumber: 'INE1234567890123',
      curp: 'PERJ850312HDFRRN05',
      rfc: 'PERJ850312AB1',
      dateOfBirth: DateTime(1985, 3, 12),
      addressStreet: 'Av. Reforma 123',
      addressNeighborhood: 'Juárez',
      addressCity: 'Ciudad de México',
      addressState: 'CDMX',
      addressPostalCode: '06600',
      email: 'juan.perez@cardholder.test',
      phone: '+52 55 1234 5601',
    ),
    Cardholder(
      id: '20000000-0000-0000-0000-000000000003',
      clientId: '00000000-0000-0000-0000-000000000002',
      fullName: 'Ana Torres',
      idDocumentType: IdDocumentType.ine,
      idDocumentNumber: 'INE2345678901234',
      curp: 'TORA900825MDFRRN08',
      rfc: 'TORA900825CD2',
      dateOfBirth: DateTime(1990, 8, 25),
      addressStreet: 'Calle Insurgentes Sur 456',
      addressNeighborhood: 'Roma Norte',
      addressCity: 'Ciudad de México',
      addressState: 'CDMX',
      addressPostalCode: '06700',
      email: 'ana.torres@cardholder.test',
      phone: '+52 55 1234 5603',
    ),
    Cardholder(
      id: '20000000-0000-0000-0000-000000000002',
      clientId: '00000000-0000-0000-0000-000000000003',
      fullName: 'Maria Gomez',
      idDocumentType: IdDocumentType.ine,
      idDocumentNumber: 'INE3456789012345',
      curp: 'GOMM880615MJCRZR03',
      rfc: 'GOMM880615EF3',
      dateOfBirth: DateTime(1988, 6, 15),
      addressStreet: 'Av. Vallarta 789',
      addressNeighborhood: 'Americana',
      addressCity: 'Guadalajara',
      addressState: 'Jalisco',
      addressPostalCode: '44160',
      email: 'maria.gomez@cardholder.test',
      phone: '+52 33 1234 5602',
    ),
    // Marked as PEP on purpose, to exercise that flag in the UI.
    Cardholder(
      id: '20000000-0000-0000-0000-000000000004',
      clientId: '00000000-0000-0000-0000-000000000003',
      fullName: 'Carlos Ruiz',
      idDocumentType: IdDocumentType.pasaporte,
      idDocumentNumber: 'G12345678',
      curp: 'RUIC750130HJCZRR07',
      rfc: 'RUIC750130GH4',
      dateOfBirth: DateTime(1975, 1, 30),
      addressStreet: 'Av. Chapultepec 321',
      addressNeighborhood: 'Americana',
      addressCity: 'Guadalajara',
      addressState: 'Jalisco',
      addressPostalCode: '44100',
      isPoliticallyExposed: true,
      email: 'carlos.ruiz@cardholder.test',
      phone: '+52 33 1234 5604',
    ),
    // Grupo Koons Holding (00...001) intentionally has none — see the
    // tarjetahabientes-por-cliente feature doc.
  ];

  @override
  Future<List<Cardholder>> listByClient(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _cardholders.where((c) => c.clientId == clientId).toList();
  }

  @override
  Future<List<Cardholder>> listByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _cardholders.where((c) => clientIds.contains(c.clientId)).toList();
  }

  @override
  Future<Cardholder?> getById(String cardholderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (final c in _cardholders) {
      if (c.id == cardholderId) return c;
    }
    return null;
  }

  @override
  Future<Cardholder> create(Cardholder draft) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final created = Cardholder(
      id: 'cardholder-${DateTime.now().microsecondsSinceEpoch}',
      clientId: draft.clientId,
      fullName: draft.fullName,
      idDocumentType: draft.idDocumentType,
      idDocumentNumber: draft.idDocumentNumber,
      curp: draft.curp,
      rfc: draft.rfc,
      dateOfBirth: draft.dateOfBirth,
      nationality: draft.nationality,
      addressStreet: draft.addressStreet,
      addressNeighborhood: draft.addressNeighborhood,
      addressCity: draft.addressCity,
      addressState: draft.addressState,
      addressPostalCode: draft.addressPostalCode,
      addressCountry: draft.addressCountry,
      isPoliticallyExposed: draft.isPoliticallyExposed,
      email: draft.email,
      phone: draft.phone,
    );
    _cardholders.add(created);
    return created;
  }

  @override
  Future<Cardholder> update(Cardholder cardholder) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _cardholders.indexWhere((c) => c.id == cardholder.id);
    if (index == -1) throw NotFoundException('Tarjetahabiente ${cardholder.id} no encontrado');
    final current = _cardholders[index];
    if (!current.isActive) throw const CardholderInactiveException();
    // clientId e isActive nunca vienen de `cardholder` — mover de Cliente
    // sigue fuera de alcance, y activar/desactivar es una acción propia
    // (ver setActive), no un efecto secundario de editar el expediente.
    final merged = Cardholder(
      id: current.id,
      clientId: current.clientId,
      isActive: current.isActive,
      fullName: cardholder.fullName,
      idDocumentType: cardholder.idDocumentType,
      idDocumentNumber: cardholder.idDocumentNumber,
      curp: cardholder.curp,
      rfc: cardholder.rfc,
      dateOfBirth: cardholder.dateOfBirth,
      nationality: cardholder.nationality,
      addressStreet: cardholder.addressStreet,
      addressNeighborhood: cardholder.addressNeighborhood,
      addressCity: cardholder.addressCity,
      addressState: cardholder.addressState,
      addressPostalCode: cardholder.addressPostalCode,
      addressCountry: cardholder.addressCountry,
      isPoliticallyExposed: cardholder.isPoliticallyExposed,
      email: cardholder.email,
      phone: cardholder.phone,
    );
    _cardholders[index] = merged;
    return merged;
  }

  @override
  Future<Cardholder> setActive(String cardholderId, bool isActive) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _cardholders.indexWhere((c) => c.id == cardholderId);
    if (index == -1) throw NotFoundException('Tarjetahabiente $cardholderId no encontrado');
    final updated = _cardholders[index].copyWith(isActive: isActive);
    _cardholders[index] = updated;
    if (!isActive) await onDeactivated?.call(cardholderId);
    return updated;
  }

  @override
  Future<bool> isOperable(String cardholderId) async {
    final cardholder = await getById(cardholderId);
    return cardholder?.isActive ?? false;
  }
}
