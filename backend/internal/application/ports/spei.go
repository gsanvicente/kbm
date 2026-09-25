package ports

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/beneficiary"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/speipayment"
)

// SPEIGateway — el "conector abierto" para un proveedor SPEI todavía sin
// elegir, mismo molde que CardProcessorGateway
// (docs/adr/0011-processor-integration-architecture-and-postgres-default.md).
// Nunca un SDK de un proveedor específico embebido en SPEIRepository —
// internal/adapters/spei/ tiene el único adaptador que lo implementa hoy,
// un simulador. Ver docs/adr/0021-conector-spei.md.
type SPEIGateway interface {
	// ProvisionCLABE asigna una CLABE nueva a la Cuenta [accountID], que
	// todavía no tiene una — el simulador genera una sintética; un
	// proveedor real la pediría a su API. Nunca se llama sobre una Cuenta
	// que ya tiene CLABE (SPEIRepository.EnsureCLABE ya lo revisa antes).
	ProvisionCLABE(ctx context.Context, accountID string) (clabeNumber string, err error)

	// DispatchPayment envía un pago SPEI ya aprobado internamente
	// (interno, no del proveedor) al proveedor — devuelve su referencia
	// si lo aceptó. El molde real es asíncrono (outbox/queue/worker, ver
	// el ADR "Consecuencias"); hasta que haya un proveedor de verdad, el
	// simulador corre síncrono y siempre confirma de inmediato.
	DispatchPayment(ctx context.Context, payment speipayment.Payment, to beneficiary.Beneficiary) (providerReference string, err error)
}

// SPEIRepository — la capa de negocio sobre SPEIGateway: candados de
// seguridad, Cuenta Individual, approval_rules. Ver
// docs/adr/0021-conector-spei.md. Nil en modo memoria — igual que
// Treasury/BalanceOps/Cardholders (ver Handler), esta parte del dominio
// nunca formó parte del alcance del adaptador en memoria.
type SPEIRepository interface {
	// GetCLABE — la CLABE de la Cuenta Individual de [cardholderID], o
	// nil si la Cuenta todavía no tiene una asignada.
	GetCLABE(ctx context.Context, cardholderID string) (*string, error)

	// GetAccountLedger — saldo y movimientos de la Cuenta Individual de
	// [cardholderID], sin depender de que tenga ninguna tarjeta asignada.
	// Ver docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3.
	GetAccountLedger(ctx context.Context, cardholderID string) (ledger.Account, []ledger.Entry, error)

	// EnsureCLABE devuelve la CLABE existente, o la provisiona (vía
	// SPEIGateway) si la Cuenta todavía no tenía una.
	EnsureCLABE(ctx context.Context, cardholderID string) (string, error)

	// ListBeneficiaries — los Beneficiarios de Pago de [cardholderID],
	// nunca los de otro Tarjetahabiente.
	ListBeneficiaries(ctx context.Context, cardholderID string) ([]beneficiary.Beneficiary, error)

	// RegisterBeneficiary valida el CLABE (dígito verificador + catálogo
	// de bancos, ver internal/domain/clabe) y que no sea la propia CLABE
	// de [cardholderID] antes de crear el Beneficiario. Lanza
	// shared.ErrValidation para una CLABE mal formada, un código de banco
	// desconocido, o la propia CLABE como beneficiario; lanza
	// shared.ErrTooManyFailedAttempts tras varios intentos fallidos
	// seguidos en la misma sesión — mismo mecanismo que
	// TransferService.ResolveDestination.
	RegisterBeneficiary(ctx context.Context, cardholderID, alias, clabeNumber string) (beneficiary.Beneficiary, error)

	// CreatePayment valida que [beneficiaryID] le pertenezca a
	// [cardholderID] (shared.ErrNotFound si no), aplica el periodo de
	// enfriamiento (shared.ErrValidation si lo excede) y evalúa
	// approval_rules para operation_type='spei_payment': por debajo del
	// umbral se despacha de inmediato (vía SPEIGateway); por encima queda
	// pending_approval. Nunca toca el ledger si el pago queda pendiente.
	CreatePayment(ctx context.Context, cardholderID, beneficiaryID string, amount float64) (speipayment.Payment, error)

	// ListPayments — el historial de pagos SPEI salientes de la Cuenta
	// Individual de [cardholderID], más reciente primero.
	ListPayments(ctx context.Context, cardholderID string) ([]speipayment.Payment, error)

	// ListDeposits — mis depósitos SPEI entrantes, más reciente primero.
	// Necesario para el comprobante propio de un depósito (ADR-0021,
	// punto 9).
	ListDeposits(ctx context.Context, cardholderID string) ([]speipayment.Deposit, error)

	// ListPendingPayments — cola de aprobación para staff, mismo criterio
	// que BalanceOperationRepository.ListPending. clientIDs vacío o nil
	// nunca devuelve "todos los Clientes": el llamador (handler) siempre
	// lo resuelve primero a partir del alcance real del staff.
	ListPendingPayments(ctx context.Context, clientIDs []string) ([]speipayment.Payment, error)

	// ListPaymentsByClients — historial completo (cualquier estatus) para
	// el reporte de staff. Ver
	// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md.
	ListPaymentsByClients(ctx context.Context, clientIDs []string) ([]speipayment.Payment, error)

	// ListDepositsByClients — reporte de depósitos SPEI cross-cliente
	// para staff, distinto de ListDeposits (self-only).
	ListDepositsByClients(ctx context.Context, clientIDs []string) ([]speipayment.Deposit, error)

	// ListBeneficiaryDirectory — el directorio agregado de Beneficiarios
	// de Pago para staff (datos + actividad + señal de CLABE
	// compartida). Ver ADR-0022, puntos 2 y 3.
	ListBeneficiaryDirectory(ctx context.Context, clientIDs []string) ([]beneficiary.DirectoryEntry, error)

	// RevealBeneficiaryCLABE devuelve la CLABE completa de un
	// Beneficiario del directorio agregado (que la muestra enmascarada
	// por default) — queda auditada. shared.ErrNotFound si
	// [beneficiaryID] no existe o está fuera del alcance de quien la
	// pide.
	RevealBeneficiaryCLABE(ctx context.Context, beneficiaryID string) (string, error)

	// ApprovePayment despacha el pago (vía SPEIGateway) y lo deja
	// executed o failed. Lanza shared.ErrInvalidState si no estaba
	// pending_approval. Ver approval.go's Approve para el mismo criterio
	// de "nunca a medias" con fondos insuficientes.
	ApprovePayment(ctx context.Context, paymentID, approvedByEmail string) (speipayment.Payment, error)

	// RejectPayment nunca toca el ledger. Lanza shared.ErrInvalidState si
	// no estaba pending_approval.
	RejectPayment(ctx context.Context, paymentID, rejectedByEmail, reason string) (speipayment.Payment, error)

	// HandleDeposit — el webhook entrante de un proveedor SPEI simulado o
	// real, idempotente por providerReference (ver
	// docs/adr/0021-conector-spei.md, punto 8): una referencia repetida
	// devuelve el depósito ya existente sin acreditar el ledger dos
	// veces. Resuelve la Cuenta destino por su CLABE — shared.ErrNotFound
	// si ninguna Cuenta la tiene asignada.
	HandleDeposit(ctx context.Context, clabeNumber string, amount float64, providerReference string) (speipayment.Deposit, error)
}
