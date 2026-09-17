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
      case CardStatus.frozen:
        return 'Congelada';
      case CardStatus.cancelled:
        return 'Cancelada';
    }
  }
}
