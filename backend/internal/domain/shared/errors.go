package shared

import "errors"

// Sentinel errors shared across domain packages so adapters (HTTP, etc.)
// can map them to the right status/response without importing domain internals.
var (
	ErrNotFound     = errors.New("resource not found")
	ErrForbidden    = errors.New("operation not permitted")
	ErrInvalidState = errors.New("invalid state transition")
	ErrValidation   = errors.New("validation failed")

	// ErrInsufficientFunds — ver docs/business/saldo-y-ledger.md, "nunca a
	// medias": ningún ledger se modifica cuando se devuelve este error.
	ErrInsufficientFunds = errors.New("insufficient funds")
	// ErrCardLimitExceeded — límite de tarjetas activas por
	// Tarjetahabiente, ver docs/business/tarjetas-y-asignacion.md.
	ErrCardLimitExceeded = errors.New("active card limit exceeded")
	// ErrCardNotAvailable — se intentó asignar una tarjeta que ya no está
	// en estado unassigned.
	ErrCardNotAvailable = errors.New("card not available")
	// ErrInvalidCredentials — mensaje genérico de login, ver
	// docs/feature/login-administrativo/README.md.
	ErrInvalidCredentials = errors.New("invalid credentials")
	// ErrTooManyFailedAttempts — límite de intentos fallidos resolviendo
	// el destino de una transferencia C2C, ver
	// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Seguridad".
	ErrTooManyFailedAttempts = errors.New("too many failed attempts")
	// ErrEmailAlreadyExists — alta de un usuario de staff con un email ya
	// registrado (users.email es citext UNIQUE), ver
	// docs/adr/0017-staff-user-management-and-rls-on-users.md.
	ErrEmailAlreadyExists = errors.New("email already exists")
)

// CardLimitExceededError lleva el límite configurado además de
// clasificar como ErrCardLimitExceeded (vía Is) — el mensaje que ve el
// usuario final (admin/lib/core/models/shared/card_limit_exceeded_exception.dart)
// necesita el número exacto, no solo saber que se excedió.
type CardLimitExceededError struct {
	Limit int
}

func (e *CardLimitExceededError) Error() string {
	return ErrCardLimitExceeded.Error()
}

func (e *CardLimitExceededError) Is(target error) bool {
	return target == ErrCardLimitExceeded
}
