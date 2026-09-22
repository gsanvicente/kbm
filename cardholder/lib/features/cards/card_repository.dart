import '../../core/models/ledger_movement.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/payment_card.dart';

abstract class CardRepository {
  /// Las tarjetas del propio Tarjetahabiente autenticado — nunca de nadie
  /// más. Un Tarjetahabiente puede tener más de una, ver
  /// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
  Future<List<PaymentCard>> listMine(String cardholderId);

  /// Movimientos de una tarjeta propia, más reciente primero. Filtro de
  /// fechas/resumen de periodo: ver `MovementsTab`, es puramente
  /// client-side sobre esta misma lista.
  Future<List<LedgerMovement>> listMovements(String cardId);

  /// El reclamo sobre [ledgerEntryId], si existe — null si nunca se
  /// presentó uno. Ver docs/business/reclamos-de-movimientos.md.
  Future<MovementClaim?> getClaim(String ledgerEntryId);

  /// Presenta un reclamo sobre un movimiento propio. Lanza
  /// [ClaimAlreadyFiledException] si [ledgerEntryId] ya tiene uno
  /// (relación 1:1).
  Future<MovementClaim> fileClaim(String ledgerEntryId, String reason);

  /// Autocongelamiento ("Bloqueo temporal") — ver
  /// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
  /// bloquear una tarjeta". [freeze] true exige que la tarjeta esté
  /// activa; false exige que ya esté congelada. Nunca puede tocar un
  /// bloqueo hecho por el staff (`CardStatus.blocked`) — lanza si se
  /// intenta. [cardholderId] verifica que [cardId] sea realmente suya.
  /// Devuelve la tarjeta ya actualizada.
  Future<PaymentCard> setFrozen(String cardholderId, String cardId, bool freeze);
}
