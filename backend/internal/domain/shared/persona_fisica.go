package shared

// IDDocumentType — compartido entre el KYC de un Cardholder
// (internal/domain/cardholder) y el KYB de un Cliente
// (internal/domain/client, PersonaFisica de un Apoderado/Beneficiario) —
// mismo shape a propósito, ver
// admin/lib/core/models/persona_fisica.dart, "Diseño: reutilizar un
// shape común de persona física".
type IDDocumentType string

const (
	IDDocumentTypeINE               IDDocumentType = "INE"
	IDDocumentTypePasaporte         IDDocumentType = "pasaporte"
	IDDocumentTypeCedulaProfesional IDDocumentType = "cedula_profesional"
)

// PersonaFisica — datos de identificación de un Apoderado Legal o
// Beneficiario Controlador de un Cliente. No confundir con Cardholder
// (una persona física que usa una Tarjeta) — ver
// admin/lib/core/models/persona_fisica.dart.
type PersonaFisica struct {
	FullName         string
	IDDocumentType   IDDocumentType
	IDDocumentNumber string
	CURP             *string
	RFC              *string
}
