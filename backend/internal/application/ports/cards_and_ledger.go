package ports

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/ledger"
)

// CardRepository — ver
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md. A
// propósito no valida el estado de un Tarjetahabiente (activo/inactivo) —
// esa verificación sigue siendo responsabilidad del llamador (admin/'s
// propio repositorio de Tarjetahabientes, que nunca migra aquí); ver la
// ADR, "Alternativas consideradas".
type CardRepository interface {
	ListByCardholder(ctx context.Context, cardholderID string) ([]card.Card, error)
	ListByClient(ctx context.Context, clientID string) ([]card.Card, error)
	GetByID(ctx context.Context, id string) (card.Card, error)

	// Assign lanza shared.ErrCardNotAvailable o shared.ErrCardLimitExceeded.
	Assign(ctx context.Context, cardID, cardholderID string) (card.Card, error)

	// SetBlocked con blocked=true siempre usa BlockedReasonManual — el
	// motivo automático (BlockedReasonCardholderInactive) solo lo aplica
	// FreezeAllForCardholder.
	SetBlocked(ctx context.Context, cardID string, blocked bool) (card.Card, error)

	// SetFrozen es el autocongelamiento del propio Tarjetahabiente — ver
	// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
	// bloquear una tarjeta". A diferencia de SetBlocked, nunca puede
	// tocar ni revertir un bloqueo de staff: lanza shared.ErrNotFound si
	// [cardID] no le pertenece a [cardholderID], y
	// shared.ErrInvalidState si la tarjeta no está en el estado correcto
	// para la transición pedida (congelar exige "active", descongelar
	// exige "frozen" — nunca "blocked" en ningún sentido).
	SetFrozen(ctx context.Context, cardID, cardholderID string, frozen bool) (card.Card, error)

	// FreezeAllForCardholder bloquea toda tarjeta de [cardholderID] que no
	// estuviera ya bloqueada — ver
	// docs/business/desactivacion-de-tarjetahabientes.md. Una tarjeta ya
	// bloqueada (por el motivo que sea) no se toca.
	FreezeAllForCardholder(ctx context.Context, cardholderID string) error

	// MaxActiveCardsPerCardholder — el límite configurado en
	// client_settings para clientID, o nil si no hay override (ver
	// docs/business/tarjetas-y-asignacion.md; el llamador decide el
	// default cuando es nil, ver defaultMaxActiveCardsPerCardholder).
	MaxActiveCardsPerCardholder(ctx context.Context, clientID string) (*int, error)

	// SetMaxActiveCardsPerCardholder — max=nil borra el override (vuelve
	// a usar el default de la aplicación). Ver
	// docs/feature/configuracion-de-cliente/README.md.
	SetMaxActiveCardsPerCardholder(ctx context.Context, clientID string, max *int) (*int, error)
}

// LedgerRepository — el subconjunto de
// admin/lib/features/ledger/ledger_repository.dart que sí migra a este
// backend (ver la ADR); reclamos y todo lo demás siguen 100% en Dart.
type LedgerRepository interface {
	GetByCard(ctx context.Context, cardID string) (ledger.Account, []ledger.Entry, error)

	// PostEntry lanza shared.ErrInsufficientFunds para un débito que
	// dejaría el saldo negativo — ningún ledger se modifica en ese caso.
	PostEntry(ctx context.Context, cardID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error)

	// GetClaim devuelve nil sin error si [ledgerEntryID] no tiene reclamo
	// — relación 1:1, ver docs/business/reclamos-de-movimientos.md.
	GetClaim(ctx context.Context, ledgerEntryID string) (*ledger.MovementClaim, error)

	// GetClaimsByLedgerEntries — forma en lote de GetClaim, para
	// pantallas que necesitan el reclamo (si existe) de muchos
	// movimientos a la vez (p.ej. el Panel directivo) sin una llamada
	// por movimiento. Solo devuelve los que sí tienen reclamo — el
	// llamador ya sabe distinguir "sin reclamo" de "no pedido".
	GetClaimsByLedgerEntries(ctx context.Context, ledgerEntryIDs []string) ([]ledger.MovementClaim, error)

	// FileClaim lanza shared.ErrInvalidState si [ledgerEntryID] ya tiene
	// un reclamo.
	FileClaim(ctx context.Context, ledgerEntryID, reason, requestedByEmail string) (ledger.MovementClaim, error)

	// FileClaimAsCardholder — mismo contrato que FileClaim, pero
	// presentado por el propio Tarjetahabiente sobre su propio
	// movimiento (ver docs/business/reclamos-de-movimientos.md). El
	// llamador ya debe haber verificado la pertenencia vía
	// GetEntryCardholderID.
	FileClaimAsCardholder(ctx context.Context, ledgerEntryID, reason, cardholderID string) (ledger.MovementClaim, error)

	// GetEntryCardholderID — a qué Tarjetahabiente pertenece la tarjeta
	// detrás de [ledgerEntryID] (nil si no está asignada) — usado por el
	// handler para el chequeo de pertenencia de getClaim/fileClaim,
	// mismo patrón que ya usa getLedger.
	GetEntryCardholderID(ctx context.Context, ledgerEntryID string) (*string, error)

	// ResolveClaim — inFavor elige resolved_favor vs rejected. Nunca
	// toca el Entry subyacente.
	ResolveClaim(ctx context.Context, claimID string, inFavor bool, resolutionNotes, resolvedByEmail string) (ledger.MovementClaim, error)
}

// CardholderAuthRepository respalda el login y la activación de cuenta
// del portal de autoservicio — ver
// docs/business/desactivacion-de-tarjetahabientes.md, "Enforcement",
// Capa 1.
type CardholderAuthRepository interface {
	// Login lanza shared.ErrInvalidCredentials tanto para credenciales
	// incorrectas como para un Tarjetahabiente inactivo — mismo mensaje
	// genérico, nunca se distingue el motivo.
	Login(ctx context.Context, email, password string) (cardholder.Cardholder, error)

	// Activate — primera creación de credenciales de un Tarjetahabiente,
	// ver docs/adr/0019-cardholder-self-activation.md. Lanza
	// shared.ErrActivationFailed (mensaje genérico) tanto si el email no
	// existe, como si el documento no coincide, como si la cuenta ya fue
	// activada, como si el Tarjetahabiente está inactivo, como si ya
	// agotó sus 5 intentos — nunca se distingue cuál.
	Activate(ctx context.Context, email, idDocumentNumber, password string) (cardholder.Cardholder, error)
}

// ResolvedTransferDestination es lo mínimo que la confirmación de una
// transferencia C2C necesita mostrar — ver
// docs/feature/transferencia-c2c-tarjetahabiente/README.md.
type ResolvedTransferDestination struct {
	Card           card.Card
	CardholderName string
}

// TransferService resuelve y ejecuta transferencias C2C — ver
// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md y
// docs/security/threat-model.md puntos 11 y 12.
type TransferService interface {
	// ResolveDestination devuelve (nil, nil) — nunca un error — cuando no
	// hay ninguna coincidencia válida: formato inválido, fuera del
	// Cliente origen, o es la propia tarjeta del Tarjetahabiente. Nunca
	// se distingue el motivo (ver "Seguridad" en el README de la
	// feature). Lanza shared.ErrTooManyFailedAttempts al superar el
	// límite de intentos fallidos de la sesión de [cardholderID].
	ResolveDestination(ctx context.Context, cardholderID, originCardID, pan string) (*ResolvedTransferDestination, error)

	// Execute lanza shared.ErrInsufficientFunds sin tocar ningún ledger.
	Execute(ctx context.Context, originCardID, destinationCardID string, amount float64) error
}
