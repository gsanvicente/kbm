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
}
