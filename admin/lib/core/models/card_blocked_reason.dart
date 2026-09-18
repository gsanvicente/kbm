/// Por qué una tarjeta está en estado `blocked` — ver
/// docs/business/tarjetas-y-asignacion.md, "Motivo de bloqueo". Solo
/// [cardholderInactive] impide desbloquear mientras su Tarjetahabiente
/// siga inactivo (ver docs/business/desactivacion-de-tarjetahabientes.md).
enum CardBlockedReason {
  manual,
  cardholderInactive;

  String get label {
    switch (this) {
      case CardBlockedReason.manual:
        return 'Bloqueo manual';
      case CardBlockedReason.cardholderInactive:
        return 'Tarjetahabiente inactivo';
    }
  }
}
