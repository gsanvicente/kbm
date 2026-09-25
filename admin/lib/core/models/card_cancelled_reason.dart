/// Por qué una tarjeta está en estado `cancelled` — ver
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md, "Reemplazo de
/// tarjeta". A diferencia de `CardBlockedReason`, este estado nunca es
/// reversible: una tarjeta cancelada no vuelve a `active`, se reemplaza
/// por una nueva sobre la misma Cuenta Individual.
enum CardCancelledReason {
  expired,
  stolen,
  lost;

  String get label {
    switch (this) {
      case CardCancelledReason.expired:
        return 'Expirada';
      case CardCancelledReason.stolen:
        return 'Robada';
      case CardCancelledReason.lost:
        return 'Extraviada';
    }
  }

  /// Nombre tal como lo espera/devuelve el backend
  /// (card.CancelledReason en Go) — español, no un identificador Dart.
  String get wireValue {
    switch (this) {
      case CardCancelledReason.expired:
        return 'expirada';
      case CardCancelledReason.stolen:
        return 'robada';
      case CardCancelledReason.lost:
        return 'extraviada';
    }
  }
}
