package card

import "time"

// Status mirrors admin/lib/core/models/card_status.dart, minus
// "cancelled" (feature futura, este backend no la necesita todavía). See
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
//
// StatusFrozen es el autocongelamiento del propio Tarjetahabiente — ver
// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs. bloquear
// una tarjeta". Distinto de StatusBlocked (solo staff): un bloqueo de
// staff siempre pesa más y el Tarjetahabiente nunca puede revertirlo,
// pero él (o el staff) sí puede revertir su propio congelamiento.
type Status string

const (
	StatusUnassigned Status = "unassigned"
	StatusActive     Status = "active"
	StatusBlocked    Status = "blocked"
	StatusFrozen     Status = "frozen"
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
