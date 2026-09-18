/// Tipo de poder notarial otorgado a un Apoderado Legal de un Cliente —
/// ver docs/business/kyb-cliente.md.
enum TipoPoder {
  actosDeAdministracion,
  pleitosYCobranzas,
  actosDeDominio,
  especial;

  String get label {
    switch (this) {
      case TipoPoder.actosDeAdministracion:
        return 'Poder general para actos de administración';
      case TipoPoder.pleitosYCobranzas:
        return 'Poder general para pleitos y cobranzas';
      case TipoPoder.actosDeDominio:
        return 'Poder general para actos de dominio';
      case TipoPoder.especial:
        return 'Poder especial';
    }
  }

  /// Solo "especial" requiere describir libremente las facultades
  /// otorgadas — los poderes generales ya tienen alcance conocido por su
  /// propio nombre.
  bool get requiereDescripcion => this == TipoPoder.especial;
}
