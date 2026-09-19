enum CardStatus {
  unassigned,
  active,
  blocked,
  frozen,
  cancelled;

  String get label {
    switch (this) {
      case CardStatus.unassigned:
        return 'Disponible';
      case CardStatus.active:
        return 'Activa';
      case CardStatus.blocked:
        return 'Bloqueada';
      // "Bloqueo temporal", no "Congelada" — a propósito distinto del
      // texto de `blocked` ("Bloqueada"), para que se note a simple
      // vista que este lo hizo el propio Tarjetahabiente y no el staff.
      // Ver docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
      // bloquear una tarjeta". Misma etiqueta en
      // cardholder/lib/core/models/card_status.dart.
      case CardStatus.frozen:
        return 'Bloqueo temporal';
      case CardStatus.cancelled:
        return 'Cancelada';
    }
  }
}
