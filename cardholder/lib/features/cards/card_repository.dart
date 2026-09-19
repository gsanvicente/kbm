import '../../core/models/ledger_movement.dart';
import '../../core/models/payment_card.dart';

abstract class CardRepository {
  /// Las tarjetas del propio Tarjetahabiente autenticado — nunca de nadie
  /// más. Un Tarjetahabiente puede tener más de una, ver
  /// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
  Future<List<PaymentCard>> listMine(String cardholderId);

  /// Movimientos de una tarjeta propia, más reciente primero. Sin filtro
  /// de fechas ni resumen de periodo todavía — esa parte de "Estado de
  /// cuenta" sigue pendiente, ver
  /// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
  Future<List<LedgerMovement>> listMovements(String cardId);

  /// Autocongelamiento ("Bloqueo temporal") — ver
  /// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
  /// bloquear una tarjeta". [freeze] true exige que la tarjeta esté
  /// activa; false exige que ya esté congelada. Nunca puede tocar un
  /// bloqueo hecho por el staff (`CardStatus.blocked`) — lanza si se
  /// intenta. [cardholderId] verifica que [cardId] sea realmente suya.
  /// Devuelve la tarjeta ya actualizada.
  Future<PaymentCard> setFrozen(String cardholderId, String cardId, bool freeze);
}
