import '../../core/models/payment_card.dart';

abstract class CardRepository {
  /// Tarjetas de un único Tarjetahabiente.
  Future<List<PaymentCard>> listByCardholder(String cardholderId);

  /// Todas las tarjetas (disponibles + asignadas) de cualquiera de
  /// [clientIds] — usado por el listado global de
  /// docs/feature/pool-y-asignacion-de-tarjetas/.
  Future<List<PaymentCard>> listByClients(List<String> clientIds);

  /// El límite configurado de tarjetas activas por tarjetahabiente para
  /// [clientId], o null si no hay límite. Ver
  /// docs/business/tarjetas-y-asignacion.md.
  Future<int?> maxActiveCardsPerCardholder(String clientId);

  /// Asigna una tarjeta disponible ([cardId]) a [cardholderId]. Lanza
  /// [CardLimitExceededException] (ver core/models/shared) si el
  /// tarjetahabiente ya alcanzó el límite de tarjetas activas de su
  /// Cliente. El llamador es responsable de que [cardholderId] pertenezca
  /// al mismo Cliente que la tarjeta — ver
  /// docs/feature/pool-y-asignacion-de-tarjetas/README.md.
  Future<PaymentCard> assign({required String cardId, required String cardholderId});

  /// Bloquea ([blocked] = true) o desbloquea ([blocked] = false) una
  /// tarjeta ya asignada. Acción directa en esta iteración — no pasa por
  /// `approval_rules` todavía, ver
  /// docs/feature/bloqueo-de-tarjeta/README.md.
  Future<PaymentCard> setBlocked(String cardId, bool blocked);
}
