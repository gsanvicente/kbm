import 'id_document_type.dart';

/// Datos de identificación de una persona física relacionada con un
/// Cliente (Apoderado Legal o Beneficiario Controlador) — no confundir
/// con [Cardholder], que es una persona física que usa una Tarjeta.
/// Comparten el mismo shape a propósito para no duplicar la definición
/// de campos tres veces — ver docs/business/kyb-cliente.md, "Diseño:
/// reutilizar un shape común de persona física".
class PersonaFisica {
  final String fullName;
  final IdDocumentType idDocumentType;
  final String idDocumentNumber;
  final String? curp;
  final String? rfc;

  const PersonaFisica({
    required this.fullName,
    this.idDocumentType = IdDocumentType.ine,
    required this.idDocumentNumber,
    this.curp,
    this.rfc,
  });

  PersonaFisica copyWith({
    String? fullName,
    IdDocumentType? idDocumentType,
    String? idDocumentNumber,
    String? curp,
    String? rfc,
  }) {
    return PersonaFisica(
      fullName: fullName ?? this.fullName,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentNumber: idDocumentNumber ?? this.idDocumentNumber,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
    );
  }
}
