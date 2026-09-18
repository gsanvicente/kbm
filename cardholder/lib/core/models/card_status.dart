/// Solo los estados que un Tarjetahabiente necesita distinguir sobre su
/// propia tarjeta en esta iteración — `frozen` (autocongelamiento) y
/// `cancelled` llegan cuando se construya esa feature, ver
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
enum CardStatus {
  active,
  blocked;

  String get label {
    switch (this) {
      case CardStatus.active:
        return 'Activa';
      case CardStatus.blocked:
        return 'Bloqueada';
    }
  }
}
