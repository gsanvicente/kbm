// Package approval holds the balance-operation state machine and
// approval-rule evaluation — see docs/business/approval-policy.md and
// docs/feature/operacion-saldo-con-aprobacion/README.md.
package approval

import "time"

// OperationType mirrors admin/lib/core/models/operation_type.dart —
// 'block'/'unblock' excluded on purpose, those stay the direct action
// from docs/feature/bloqueo-de-tarjeta/.
type OperationType string

const (
	OperationTypeLoad     OperationType = "load"
	OperationTypeDebit    OperationType = "debit"
	OperationTypeTransfer OperationType = "transfer"
)

// OperationStatus mirrors admin/lib/core/models/operation_status.dart.
// "approved" is kept for schema fidelity even though this iteration
// never actually produces it — approving executes in the same step.
type OperationStatus string

const (
	OperationStatusPendingApproval OperationStatus = "pending_approval"
	OperationStatusApproved        OperationStatus = "approved"
	OperationStatusExecuted        OperationStatus = "executed"
	OperationStatusRejected        OperationStatus = "rejected"
	OperationStatusFailed          OperationStatus = "failed"
)

// Rule — la configuración de aprobación de un Cliente para un
// OperationType. La ausencia de una Rule para un Cliente+OperationType es
// significativa (fail-safe: requiere aprobación por default), no se
// modela como un valor cero de este struct.
type Rule struct {
	ClientID         string
	OperationType    OperationType
	RequiresApproval bool
	// nil significa "cualquier monto" cuando RequiresApproval es true.
	MinAmount *float64
}

// Operation — una carga/débito/transferencia solicitada sobre una
// tarjeta, condicionada por Rule. Nunca muta el ledger directamente —
// solo una ejecución exitosa lo hace.
type Operation struct {
	ID       string
	ClientID string
	CardID   string
	Type     OperationType
	Amount   float64
	// Solo para OperationTypeTransfer.
	DestinationCardID *string
	Status            OperationStatus
	RequestedByEmail  string
	ResolvedByEmail   *string
	// Motivo de rechazo, o de falla (p.ej. fondos insuficientes) — mismo
	// campo de doble propósito que ledger.MovementClaim.ResolutionNotes.
	ResolutionNotes *string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// WeekVolume — un punto semanal de volumen ejecutado, para el Panel
// directivo. Dato de flujo (cuánto se movió esa semana), no de saldo.
type WeekVolume struct {
	WeekStart     time.Time
	Dispersion    float64
	Deduccion     float64
	Transferencia float64
}
