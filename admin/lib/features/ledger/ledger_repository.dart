import '../../core/models/ledger_account.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/movement_claim.dart';

abstract class LedgerRepository {
  /// null if [cardId] has no ledger account yet — a Disponible (unassigned)
  /// card, per docs/business/tarjetas-y-asignacion.md. Never "$0.00" for
  /// that case; the caller must distinguish "no account" from "zero
  /// balance" — see docs/business/saldo-y-ledger.md.
  Future<LedgerAccount?> getByCard(String cardId);

  /// Batch form of [getByCard], for list views that show many cards at
  /// once without one sequential fetch per row.
  Future<Map<String, LedgerAccount>> getByCards(List<String> cardIds);

  /// Movements for one account, most recent first. See
  /// docs/feature/reclamos-de-movimientos/README.md.
  Future<List<LedgerEntry>> listEntries(String ledgerAccountId);

  /// Batch form for the movements list, avoiding one fetch per row.
  Future<Map<String, MovementClaim>> getClaims(List<String> ledgerEntryIds);

  Future<MovementClaim?> getClaim(String ledgerEntryId);

  /// Throws if [ledgerEntryId] already has a claim — 1:1 relationship,
  /// see docs/business/reclamos-de-movimientos.md.
  Future<MovementClaim> fileClaim({
    required String ledgerEntryId,
    required String reason,
    required String requestedByEmail,
  });

  /// [inFavor] picks resolved_favor vs rejected. Never touches the
  /// underlying LedgerEntry — resolving a claim is a record of the
  /// decision, not a financial operation.
  Future<MovementClaim> resolveClaim({
    required String claimId,
    required bool inFavor,
    required String resolutionNotes,
    required String resolvedByEmail,
  });
}
