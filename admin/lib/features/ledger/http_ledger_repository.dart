import '../../core/http/kbm_backend_client.dart';
import '../../core/models/claim_status.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import 'ledger_repository.dart';

/// Implementación real de `LedgerRepository` contra el backend compartido
/// para saldo/movimientos — ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
/// Reclamos (`MovementClaim`) se quedan 100% en memoria local de Dart, tal
/// como esa ADR decidió: no forman parte del alcance de datos
/// compartidos, y esta clase mezcla ambas fuentes sin que su interfaz
/// pública lo note — mismo criterio que `FakeCardholderBackend` del lado
/// de `cardholder/`.
///
/// `ledgerAccountId` es, en este esquema, literalmente el `cardId` — el
/// backend en memoria no tiene un concepto de cuenta separado del de
/// tarjeta (1:1, ver internal/domain/ledger/ledger.go). Esta clase es la
/// única que necesita saberlo; el resto de `admin/` sigue tratando
/// `LedgerAccount.id` como un identificador opaco.
class HttpLedgerRepository implements LedgerRepository {
  HttpLedgerRepository({
    required this.client,
    required this.cardRepository,
    required this.clientRepository,
  });

  final KbmBackendClient client;

  /// Para resolver, en `fileClaim`/`resolveClaim`, a qué Cliente
  /// pertenece la tarjeta de un movimiento.
  final CardRepository cardRepository;

  /// Para verificar que ese Cliente pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  final ClientRepository clientRepository;

  final List<MovementClaim> _claims = [
    // Mismo dato de demo que ya traía FakeLedgerRepository — Juan Perez
    // disputa su "Compra en restaurante", dejado en revisión.
    MovementClaim(
      id: '70000000-0000-0000-0000-000000000001',
      ledgerEntryId: '60000000-0000-0000-0000-000000000002',
      reason: 'No reconozco este cargo.',
      status: ClaimStatus.inReview,
      requestedByEmail: 'operador.subA@koons.test',
      createdAt: DateTime(2026, 1, 16, 8, 0),
    ),
  ];

  LedgerEntry _entryFromJson(String ledgerAccountId, Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      ledgerAccountId: ledgerAccountId,
      type: (json['type'] as String) == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balanceAfter'] as num).toDouble(),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Future<LedgerAccount?> getByCard(String cardId) async {
    try {
      final json = await client.get('/v1/cards/$cardId/ledger') as Map<String, dynamic>;
      return LedgerAccount(id: cardId, cardId: cardId, currency: json['currency'] as String, balance: (json['balance'] as num).toDouble());
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, LedgerAccount>> getByCards(List<String> cardIds) async {
    final results = await Future.wait(cardIds.map((id) async => MapEntry(id, await getByCard(id))));
    return {
      for (final entry in results)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  @override
  Future<List<LedgerEntry>> listEntries(String ledgerAccountId) async {
    // ledgerAccountId es el cardId — ver el doc de la clase.
    try {
      final json = await client.get('/v1/cards/$ledgerAccountId/ledger') as Map<String, dynamic>;
      final entries = (json['entries'] as List<dynamic>)
          .map((e) => _entryFromJson(ledgerAccountId, e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  @override
  Future<Map<String, MovementClaim>> getClaims(List<String> ledgerEntryIds) async {
    return {
      for (final claim in _claims)
        if (ledgerEntryIds.contains(claim.ledgerEntryId)) claim.ledgerEntryId: claim,
    };
  }

  @override
  Future<MovementClaim?> getClaim(String ledgerEntryId) async {
    for (final claim in _claims) {
      if (claim.ledgerEntryId == ledgerEntryId) return claim;
    }
    return null;
  }

  /// Verifica que el Cliente dueño de [cardId] pueda operar — igual que
  /// la versión fake, solo que ahora `cardRepository.getById` viaja por
  /// HTTP. `cardId` llega explícito desde el llamador (ver
  /// [LedgerRepository.fileClaim]) porque este backend no ofrece "dame la
  /// tarjeta dueña de este movimiento".
  Future<bool> _isOperableForCard(String cardId) async {
    final card = await cardRepository.getById(cardId);
    if (card == null) return true; // no debería pasar, pero no bloquear por un dato inconsistente
    return clientRepository.isOperable(card.clientId);
  }

  @override
  Future<MovementClaim> fileClaim({
    required String ledgerEntryId,
    required String cardId,
    required String reason,
    required String requestedByEmail,
  }) async {
    if (!await _isOperableForCard(cardId)) {
      throw const ClientInactiveException();
    }
    if (_claims.any((c) => c.ledgerEntryId == ledgerEntryId)) {
      throw StateError('Este movimiento ya tiene un reclamo.');
    }
    final claim = MovementClaim(
      id: 'claim-${DateTime.now().microsecondsSinceEpoch}',
      ledgerEntryId: ledgerEntryId,
      reason: reason,
      status: ClaimStatus.open,
      requestedByEmail: requestedByEmail,
      createdAt: DateTime.now(),
    );
    _claims.add(claim);
    return claim;
  }

  @override
  Future<MovementClaim> resolveClaim({
    required String claimId,
    required String cardId,
    required bool inFavor,
    required String resolutionNotes,
    required String resolvedByEmail,
  }) async {
    final index = _claims.indexWhere((c) => c.id == claimId);
    if (index == -1) throw NotFoundException('Reclamo $claimId no encontrado');
    if (!await _isOperableForCard(cardId)) {
      throw const ClientInactiveException();
    }
    final updated = _claims[index].copyWith(
      status: inFavor ? ClaimStatus.resolvedFavor : ClaimStatus.rejected,
      resolvedByEmail: resolvedByEmail,
      resolutionNotes: resolutionNotes,
      resolvedAt: DateTime.now(),
    );
    _claims[index] = updated;
    return updated;
  }

  @override
  Future<LedgerEntry> postEntry({
    required String ledgerAccountId,
    required LedgerEntryType type,
    required double amount,
    String? description,
  }) async {
    try {
      final json = await client.post('/v1/cards/$ledgerAccountId/ledger/entries', {
        'type': type == LedgerEntryType.credit ? 'credit' : 'debit',
        'amount': amount,
        'description': description ?? '',
      }) as Map<String, dynamic>;
      return _entryFromJson(ledgerAccountId, json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 402) {
        final account = await getByCard(ledgerAccountId);
        throw InsufficientFundsException(currentBalance: account?.balance ?? 0, requestedAmount: amount);
      }
      rethrow;
    }
  }
}
