enum IdDocumentType {
  ine,
  pasaporte,
  cedulaProfesional;

  String get label {
    switch (this) {
      case IdDocumentType.ine:
        return 'INE';
      case IdDocumentType.pasaporte:
        return 'Pasaporte';
      case IdDocumentType.cedulaProfesional:
        return 'Cédula profesional';
    }
  }
}
