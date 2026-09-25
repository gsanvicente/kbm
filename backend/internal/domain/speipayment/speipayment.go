// Package speipayment holds los pagos SPEI salientes (a un
// beneficiary.Beneficiary) y los depósitos SPEI entrantes de una Cuenta
// Individual — ver docs/adr/0021-conector-spei.md. Tabla propia, no
// reutiliza balance_operations (mismo criterio que "Compra" en
// docs/adr/0011): quien origina es el propio Tarjetahabiente, no el
// staff sobre una tarjeta.
package speipayment

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/approval"
)

// Payment.Status reutiliza approval.OperationStatus — mismo enum
// Postgres (operation_status) que balance_operations, ver la migración.
//
// BeneficiaryAlias/BeneficiaryCLABE/RequestedByFullName son campos de
// join, poblados solo por los queries de listado (mismo criterio que
// approval.Operation.RequestedByEmail: un dato desnormalizado para
// mostrar, no una relación de dominio) — vacíos en el resultado de crear
// o de aprobar/rechazar un pago.
type Payment struct {
	ID                      string
	ClientID                string
	AccountID               string
	BeneficiaryID           string
	Amount                  float64
	Status                  approval.OperationStatus
	RequestedByCardholderID string
	ResolvedByEmail         *string
	ResolutionNotes         *string
	ProviderReference       *string
	CreatedAt               time.Time
	UpdatedAt               time.Time

	BeneficiaryAlias    string
	BeneficiaryCLABE    string
	RequestedByFullName string
}

// Deposit — un depósito SPEI entrante ya conciliado automáticamente
// (ADR-0021, punto 8) — a diferencia de un Payment, nunca pasa por
// pending_approval: para cuando esta fila existe, el ledger ya fue
// acreditado. CardholderFullName es un campo de join (mismo criterio que
// Payment.BeneficiaryAlias) — solo poblado por el reporte cross-cliente
// de staff (ADR-0022), vacío en el resultado del webhook o del listado
// self-only del propio Tarjetahabiente.
type Deposit struct {
	ID                 string
	ClientID           string
	AccountID          string
	Amount             float64
	ProviderReference  string
	CreatedAt          time.Time
	CardholderFullName string
}
