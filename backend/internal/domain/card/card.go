package card

import "time"

// Status mirrors admin/lib/core/models/card_status.dart, minus the states
// this in-memory backend doesn't need to reason about yet (frozen —
// self-service autocongelamiento, cancelled — feature futura). See
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
type Status string

const (
	StatusUnassigned Status = "unassigned"
	StatusActive     Status = "active"
	StatusBlocked    Status = "blocked"
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
	ID            string
	ClientID      string
	CardholderID  *string
	MaskedPAN     string
	Network       Network
	ExpiryMonth   int
	ExpiryYear    int
	Status        Status
	BlockedReason *BlockedReason
	AssignedAt    *time.Time
}

func (c Card) IsAvailable() bool {
	return c.Status == StatusUnassigned
}
