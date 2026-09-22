// Package cardholder holds the Tarjetahabiente entity and its invariants.
package cardholder

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/shared"
)

// Cardholder — el expediente KYC completo (admin/'s vista de gestión) más
// lo mínimo que el login del portal de autoservicio y la resolución de
// destino de una transferencia C2C necesitan. Antes vivía dividido entre
// este struct mínimo y admin/'s propio repositorio fake — ver
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md,
// "Alternativas consideradas" — ahora es un solo Cardholder real,
// igual que en admin/lib/core/models/cardholder.dart.
type Cardholder struct {
	ID       string
	ClientID string
	FullName string

	IDDocumentType   shared.IDDocumentType
	IDDocumentNumber string
	CURP             *string
	RFC              *string
	DateOfBirth      *time.Time
	Nationality      string

	AddressStreet       *string
	AddressNeighborhood *string
	AddressCity         *string
	AddressState        *string
	AddressPostalCode   *string
	AddressCountry      string

	IsPoliticallyExposed bool
	Email                *string
	Phone                *string
	IsActive             bool

	// Password — solo la usa el adaptador en memoria (modo demo), en
	// texto plano, nunca en un backend real. El adaptador Postgres
	// verifica contra cardholder_users.password_hash (bcrypt) y nunca
	// llena este campo — ver internal/adapters/postgres/repository/auth.go.
	// Vacío significa "todavía no activó su cuenta" (ver Activate).
	Password string

	// ActivationFailedAttempts — ver
	// docs/adr/0019-cardholder-self-activation.md, "Seguridad". El
	// adaptador Postgres lo persiste en
	// cardholders.activation_failed_attempts; el adaptador en memoria lo
	// guarda aquí directamente.
	ActivationFailedAttempts int
}
