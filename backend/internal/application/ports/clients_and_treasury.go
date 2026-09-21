package ports

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/approval"
	kbmclient "github.com/koons/kbm/backend/internal/domain/client"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/staff"
	"github.com/koons/kbm/backend/internal/domain/treasury"
)

// ClientRepository — sin filtrado por rol/sesión (ver ListAll): este
// backend no tiene todavía un AuthorizationPort real, admin/ sigue
// resolviendo qué Clientes son accesibles del lado del cliente, igual
// que ya hacía contra sus propios fakes de Dart. Ver
// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
type ClientRepository interface {
	ListAll(ctx context.Context) ([]kbmclient.Client, error)

	// Create ignora draft.ID (se asigna uno nuevo) y mantiene
	// client_hierarchy (cierre transitivo) en la misma transacción.
	Create(ctx context.Context, draft kbmclient.Client) (kbmclient.Client, error)

	// Update ignora updated.ParentClientID (re-parentar sigue fuera de
	// alcance) e updated.IsActive (usar SetActive). Reemplaza
	// Apoderados/BeneficiariosControladores completos — el llamador
	// manda la lista final, no un delta.
	Update(ctx context.Context, updated kbmclient.Client) (kbmclient.Client, error)

	// SetActive cambia is_active en cascada para clientID y TODOS sus
	// descendientes — ver docs/business/desactivacion-de-clientes.md.
	SetActive(ctx context.Context, clientID string, active bool) (kbmclient.Client, error)

	// IsOperable — true solo si clientID y toda su cadena de ancestros
	// están activos.
	IsOperable(ctx context.Context, clientID string) (bool, error)
}

// TreasuryRepository — ver docs/business/tesoreria-cliente.md.
type TreasuryRepository interface {
	// GetConcentratorAccount devuelve nil sin error si el Cliente
	// todavía no tiene una — no debería pasar para un Cliente creado vía
	// Create (que ya la crea), pero un Cliente sembrado directamente en
	// SQL podría carecer de ella.
	GetConcentratorAccount(ctx context.Context, clientID string) (*treasury.ConcentratorAccount, error)

	// CreateConcentratorAccount es get-or-create — llamarla para un
	// Cliente que ya tiene una simplemente devuelve la existente, nunca
	// falla ni duplica.
	CreateConcentratorAccount(ctx context.Context, clientID string) (treasury.ConcentratorAccount, error)

	ListConcentratorEntries(ctx context.Context, concentratorAccountID string) ([]treasury.ConcentratorEntry, error)

	// PostConcentratorEntry lanza shared.ErrInsufficientFunds para un
	// débito que dejaría el saldo negativo.
	PostConcentratorEntry(ctx context.Context, concentratorAccountID string, entryType ledger.EntryType, amount float64, description string) (treasury.ConcentratorEntry, error)

	ListCollectorDeposits(ctx context.Context, clientID string) ([]treasury.CollectorDeposit, error)

	// RegisterDeposit deja el depósito en pending — nunca mueve el saldo
	// de la Concentradora por sí solo.
	RegisterDeposit(ctx context.Context, clientID string, amount float64, reference, registeredByEmail string) (treasury.CollectorDeposit, error)

	// ReconcileDeposit mueve pending -> reconciled y acredita la
	// Concentradora del mismo Cliente. Lanza shared.ErrInvalidState si el
	// depósito ya fue conciliado.
	ReconcileDeposit(ctx context.Context, depositID, reconciledByEmail string) (treasury.CollectorDeposit, error)
}

// StaffAuthRepository respalda el login administrativo (admin/) — mismo
// criterio de mensaje genérico que CardholderAuthRepository.
type StaffAuthRepository interface {
	// Login lanza shared.ErrInvalidCredentials para credenciales
	// incorrectas, usuario inactivo, o el Cliente del usuario (o alguno
	// de sus ancestros) inactivo — Capa 1, ver
	// docs/business/desactivacion-de-clientes.md.
	Login(ctx context.Context, email, password string) (staff.User, error)
}

// BalanceOperationRepository — ver
// docs/feature/operacion-saldo-con-aprobacion/README.md.
type BalanceOperationRepository interface {
	ListByClients(ctx context.Context, clientIDs []string) ([]approval.Operation, error)
	ListPendingByClients(ctx context.Context, clientIDs []string) ([]approval.Operation, error)

	// GetWeeklyTrend — volumen real ejecutado por semana, últimas 12
	// semanas, para el Panel directivo.
	GetWeeklyTrend(ctx context.Context, clientIDs []string) ([]approval.WeekVolume, error)

	// Request evalúa approval_rules y ejecuta de inmediato o deja
	// pending_approval. destinationCardID requerido solo para
	// OperationTypeTransfer. Un resultado `failed` significa que corrió
	// pero chocó con fondos insuficientes — el registro se crea de
	// cualquier forma.
	Request(ctx context.Context, clientID, cardID string, opType approval.OperationType, amount float64, destinationCardID *string, requestedByEmail string) (approval.Operation, error)

	// Approve intenta ejecutar ahora — termina en executed o failed,
	// nunca la deja pendiente. Lanza shared.ErrInvalidState si no estaba
	// pending_approval.
	Approve(ctx context.Context, operationID, approvedByEmail string) (approval.Operation, error)

	// Reject nunca toca el ledger. Lanza shared.ErrInvalidState si no
	// estaba pending_approval.
	Reject(ctx context.Context, operationID, rejectedByEmail, reason string) (approval.Operation, error)

	// ListApprovalRules — las reglas configuradas para clientID, una por
	// OperationType como máximo (ver approval_rules_client_operation_unique
	// en migrations/0004_approval_rules_unique_constraint.sql). Un
	// OperationType ausente de la lista usa el default fail-safe
	// (requiere aprobación) — ver docs/business/approval-policy.md.
	ListApprovalRules(ctx context.Context, clientID string) ([]approval.Rule, error)

	// SetApprovalRule — crea o actualiza la regla de clientID+opType
	// (upsert). minAmount=nil significa "cualquier monto" cuando
	// requiresApproval es true. Ver
	// docs/feature/configuracion-de-cliente/README.md.
	SetApprovalRule(ctx context.Context, clientID string, opType approval.OperationType, requiresApproval bool, minAmount *float64) (approval.Rule, error)

	// DeleteApprovalRule quita el override — el Cliente vuelve al
	// default fail-safe (requiere aprobación) para ese OperationType.
	DeleteApprovalRule(ctx context.Context, clientID string, opType approval.OperationType) error
}
