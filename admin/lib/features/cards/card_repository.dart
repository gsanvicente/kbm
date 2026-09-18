import '../../core/models/payment_card.dart';

abstract class CardRepository {
  /// Una tarjeta por id, o null si no existe — usado por
  /// `LedgerRepository` para resolver el Cliente dueño de un movimiento
  /// al verificar si puede operar (ver
  /// docs/business/desactivacion-de-clientes.md).
  Future<PaymentCard?> getById(String cardId);

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
  /// Cliente, o [CardholderInactiveException] si [cardholderId] está
  /// inactivo (ver docs/business/desactivacion-de-tarjetahabientes.md). El
  /// llamador es responsable de que [cardholderId] pertenezca al mismo
  /// Cliente que la tarjeta — ver
  /// docs/feature/pool-y-asignacion-de-tarjetas/README.md.
  Future<PaymentCard> assign({required String cardId, required String cardholderId});

  /// Bloquea ([blocked] = true, motivo `manual`) o desbloquea ([blocked] =
  /// false) una tarjeta ya asignada. Acción directa en esta iteración —
  /// no pasa por `approval_rules` todavía, ver
  /// docs/feature/bloqueo-de-tarjeta/README.md. Desbloquear lanza
  /// [CardholderInactiveException] si el Tarjetahabiente dueño de la
  /// tarjeta está inactivo, sin importar el motivo de bloqueo actual —
  /// ver docs/business/tarjetas-y-asignacion.md, "Motivo de bloqueo".
  Future<PaymentCard> setBlocked(String cardId, bool blocked);

  /// Bloquea, con motivo `cardholderInactive`, todas las tarjetas de
  /// [cardholderId] que no estuvieran ya bloqueadas — llamado solo al
  /// desactivar un Tarjetahabiente (ver
  /// docs/business/desactivacion-de-tarjetahabientes.md). Una tarjeta que
  /// ya estaba bloqueada (por el motivo que sea) no se toca.
  Future<void> freezeAllForCardholder(String cardholderId);
}
