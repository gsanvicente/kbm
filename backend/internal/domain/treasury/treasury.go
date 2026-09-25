// Package treasury holds a Cliente's Cuenta Concentradora and Cuenta
// Colectora — see docs/business/tesoreria-cliente.md.
package treasury

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/ledger"
)

// ConcentratorAccount — el pool de dinero real de un Cliente, 1:1 con él,
// nunca con una Tarjeta.
type ConcentratorAccount struct {
	ID       string
	ClientID string
	Currency string
	Balance  float64
}

// ConcentratorEntry — append-only, mismo patrón que ledger.Entry pero un
// nivel arriba (Cliente en vez de Tarjeta).
type ConcentratorEntry struct {
	ID                    string
	ConcentratorAccountID string
	Type                  ledger.EntryType
	Amount                float64
	BalanceAfter          float64
	Description           string
	CreatedAt             time.Time
}

type CollectorDepositStatus string

const (
	CollectorDepositStatusPending    CollectorDepositStatus = "pending"
	CollectorDepositStatusReconciled CollectorDepositStatus = "reconciled"
)

// CollectorDeposit — el punto de entrada cuando el Cliente deposita
// dinero externo. Registrarlo nunca mueve el saldo de la Concentradora
// por sí solo — solo conciliar lo hace.
type CollectorDeposit struct {
	ID                string
	ClientID          string
	Amount            float64
	Reference         string
	Status            CollectorDepositStatus
	RegisteredByEmail string
	ReconciledByEmail *string
	CreatedAt         time.Time
	ReconciledAt      *time.Time
}

// Statement — saldo actual + movimientos de la Concentradora de un
// Cliente, para el "Estado de cuenta" de directivos — ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 5.
// Entries ya incluye los créditos de depósitos de Colectora conciliados
// (ReconcileDeposit los inserta como ConcentratorEntry, descripción
// "Conciliación de depósito ...") — nunca se mezclan por separado con
// CollectorDeposit, contarían el mismo movimiento dos veces.
type Statement struct {
	ConcentratorBalance float64
	Currency            string
	Entries             []ConcentratorEntry
}
