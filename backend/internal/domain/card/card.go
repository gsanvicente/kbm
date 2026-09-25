package card

import "time"

// Status mirrors admin/lib/core/models/card_status.dart. See
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
//
// StatusFrozen es el autocongelamiento del propio Tarjetahabiente — ver
// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs. bloquear
// una tarjeta". Distinto de StatusBlocked (solo staff): un bloqueo de
// staff siempre pesa más y el Tarjetahabiente nunca puede revertirlo,
// pero él (o el staff) sí puede revertir su propio congelamiento.
//
// StatusCancelled, desde docs/adr/0020-cuenta-individual-tarjetahabiente.md:
// a diferencia de Blocked/Frozen, nunca es reversible — ver
// docs/business/tarjetas-y-asignacion.md, "Reemplazo de tarjeta".
type Status string

const (
	StatusUnassigned Status = "unassigned"
	StatusActive     Status = "active"
	StatusBlocked    Status = "blocked"
	StatusFrozen     Status = "frozen"
	StatusCancelled  Status = "cancelled"
)

// BlockedReason distingue un bloqueo manual del staff de un congelamiento
// automático por Tarjetahabiente inactivo — ver
// docs/business/tarjetas-y-asignacion.md, "Motivo de bloqueo". Solo tiene
// sentido cuando Status == StatusBlocked.
type BlockedReason string

const (
	BlockedReasonManual             BlockedReason = "manual"
	BlockedReasonCardholderInactive BlockedReason = "cardholder_inactive"
)

// CancelledReason — solo tiene sentido cuando Status == StatusCancelled,
// mismo espíritu que BlockedReason. Ver "Reemplazo de tarjeta" arriba.
type CancelledReason string

const (
	CancelledReasonExpired CancelledReason = "expirada"
	CancelledReasonStolen  CancelledReason = "robada"
	CancelledReasonLost    CancelledReason = "extraviada"
)

type Network string

const (
	NetworkVisa       Network = "visa"
	NetworkMastercard Network = "mastercard"
)

// Card es deliberadamente ajena al PAN completo — igual que
// admin/lib/core/models/payment_card.dart, nunca carga el PAN ni su hash;
// esos viven solo dentro del adaptador que resuelve transferencias C2C.
// Ver docs/adr/0009-pan-hash-transit-for-c2c-transfers.md.
type Card struct {
	ID           string
	ClientID     string
	CardholderID *string
	// AccountID — la Cuenta Individual dueña del saldo detrás de esta
	// tarjeta (nil solo si la tarjeta sigue `unassigned`). Ver
	// docs/adr/0020-cuenta-individual-tarjetahabiente.md.
	AccountID       *string
	MaskedPAN       string
	Network         Network
	ExpiryMonth     int
	ExpiryYear      int
	Status          Status
	BlockedReason   *BlockedReason
	CancelledReason *CancelledReason
	AssignedAt      *time.Time
}

func (c Card) IsAvailable() bool {
	return c.Status == StatusUnassigned
}
