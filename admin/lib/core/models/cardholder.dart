import 'id_document_type.dart';

/// KYC/PLD fields (curp, rfc, address, isPoliticallyExposed) hold
/// sensitive personal data regulated under Mexico's LFPDPPP — see
/// docs/business/kyc-tarjetahabiente.md before adding new consumers of
/// this model (exports, logs, new screens).
class Cardholder {
  final String id;
  final String clientId;
  final String fullName;
  final IdDocumentType idDocumentType;
  final String idDocumentNumber;
  final String? curp;
  final String? rfc;
  final DateTime? dateOfBirth;
  final String nationality;
  final String? addressStreet;
  final String? addressNeighborhood;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;
  final String addressCountry;
  final bool isPoliticallyExposed;
  final String? email;
  final String? phone;
  final bool isActive;

  const Cardholder({
    required this.id,
    required this.clientId,
    required this.fullName,
    this.idDocumentType = IdDocumentType.ine,
    required this.idDocumentNumber,
    this.curp,
    this.rfc,
    this.dateOfBirth,
    this.nationality = 'Mexicana',
    this.addressStreet,
    this.addressNeighborhood,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
    this.addressCountry = 'México',
    this.isPoliticallyExposed = false,
    this.email,
    this.phone,
    this.isActive = true,
  });

  Cardholder copyWith({
    String? fullName,
    IdDocumentType? idDocumentType,
    String? idDocumentNumber,
    String? curp,
    String? rfc,
    DateTime? dateOfBirth,
    String? nationality,
    String? addressStreet,
    String? addressNeighborhood,
    String? addressCity,
    String? addressState,
    String? addressPostalCode,
    String? addressCountry,
    bool? isPoliticallyExposed,
    String? email,
    String? phone,
    bool? isActive,
  }) {
    return Cardholder(
      id: id,
      clientId: clientId,
      fullName: fullName ?? this.fullName,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentNumber: idDocumentNumber ?? this.idDocumentNumber,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      nationality: nationality ?? this.nationality,
      addressStreet: addressStreet ?? this.addressStreet,
      addressNeighborhood: addressNeighborhood ?? this.addressNeighborhood,
      addressCity: addressCity ?? this.addressCity,
      addressState: addressState ?? this.addressState,
      addressPostalCode: addressPostalCode ?? this.addressPostalCode,
      addressCountry: addressCountry ?? this.addressCountry,
      isPoliticallyExposed: isPoliticallyExposed ?? this.isPoliticallyExposed,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }
}
