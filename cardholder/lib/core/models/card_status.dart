/// Solo los estados que un Tarjetahabiente necesita distinguir sobre su
/// propia tarjeta en esta iteración — `cancelled` llega cuando se
/// construya esa feature, ver
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
///
/// `frozen` es el autocongelamiento del propio Tarjetahabiente
/// ("Bloqueo temporal") — distinto de `blocked` (solo lo hace el staff
/// desde `admin/`, nunca revertible por el Tarjetahabiente). Misma
/// etiqueta que `admin/lib/core/models/card_status.dart` usa para el
/// mismo valor, a propósito: debe verse igual en ambas apps. Ver
/// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs. bloquear
/// una tarjeta".
enum CardStatus {
  active,
  frozen,
  blocked;

  String get label {
    switch (this) {
      case CardStatus.active:
        return 'Activa';
      case CardStatus.frozen:
        return 'Bloqueo temporal';
      case CardStatus.blocked:
        return 'Bloqueada';
    }
  }
}
