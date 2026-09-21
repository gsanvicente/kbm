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
/// para saldo/movimientos y reclamos — ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md y
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md
/// (reclamos migraron a Postgres en ese segundo incremento; hasta
/// entonces vivían 100% en memoria local de esta clase).
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

  MovementClaim _claimFromJson(Map<String, dynamic> json) {
    return MovementClaim(
      id: json['id'] as String,
      ledgerEntryId: json['ledgerEntryId'] as String,
      reason: json['reason'] as String,
      status: _claimStatusFromJson(json['status'] as String),
      requestedByEmail: json['requestedByEmail'] as String,
      resolvedByEmail: json['resolvedByEmail'] as String?,
      resolutionNotes: json['resolutionNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
    );
  }

  // El wire trae snake_case (in_review/resolved_favor) — no coincide con
  // los identificadores Dart (camelCase), se mapea a mano.
  ClaimStatus _claimStatusFromJson(String v) {
    switch (v) {
      case 'open':
        return ClaimStatus.open;
      case 'in_review':
        return ClaimStatus.inReview;
      case 'resolved_favor':
        return ClaimStatus.resolvedFavor;
      case 'rejected':
        return ClaimStatus.rejected;
      default:
        return ClaimStatus.open;
    }
  }

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
    if (ledgerEntryIds.isEmpty) return {};
    final json = await client.get('/v1/claims?ledger_entry_ids=${ledgerEntryIds.join(',')}') as List<dynamic>;
    final claims = json.map((e) => _claimFromJson(e as Map<String, dynamic>));
    return {for (final claim in claims) claim.ledgerEntryId: claim};
  }

  @override
  Future<MovementClaim?> getClaim(String ledgerEntryId) async {
    try {
      final json = await client.get('/v1/ledger-entries/$ledgerEntryId/claim') as Map<String, dynamic>;
      return _claimFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
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
    try {
      final json = await client.post('/v1/ledger-entries/$ledgerEntryId/claim', {
        'reason': reason,
        'requestedByEmail': requestedByEmail,
      }) as Map<String, dynamic>;
      return _claimFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 409) throw StateError('Este movimiento ya tiene un reclamo.');
      rethrow;
    }
  }

  @override
  Future<MovementClaim> resolveClaim({
    required String claimId,
    required String cardId,
    required bool inFavor,
    required String resolutionNotes,
    required String resolvedByEmail,
  }) async {
    if (!await _isOperableForCard(cardId)) {
      throw const ClientInactiveException();
    }
    try {
      final json = await client.post('/v1/claims/$claimId/resolve', {
        'inFavor': inFavor,
        'resolutionNotes': resolutionNotes,
        'resolvedByEmail': resolvedByEmail,
      }) as Map<String, dynamic>;
      return _claimFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) throw NotFoundException('Reclamo $claimId no encontrado');
      rethrow;
    }
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
