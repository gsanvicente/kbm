package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/approval"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

func (s *Store) ListByClients(ctx context.Context, clientIDs []string) ([]approval.Operation, error) {
	rows, err := s.q.ListBalanceOperationsByClients(ctx, clientIDs)
	if err != nil {
		return nil, err
	}
	out := make([]approval.Operation, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToBalanceOperation(mapper.BalanceOperationRow(r)))
	}
	return out, nil
}

func (s *Store) ListPendingByClients(ctx context.Context, clientIDs []string) ([]approval.Operation, error) {
	rows, err := s.q.ListPendingBalanceOperationsByClients(ctx, clientIDs)
	if err != nil {
		return nil, err
	}
	out := make([]approval.Operation, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToBalanceOperation(mapper.BalanceOperationRow(r)))
	}
	return out, nil
}

// GetWeeklyTrend — volumen real ejecutado por semana/tipo, últimas 12
// semanas — ver docs/feature/panel-directivo/README.md, "Visión futura".
func (s *Store) GetWeeklyTrend(ctx context.Context, clientIDs []string) ([]approval.WeekVolume, error) {
	rows, err := s.q.GetWeeklyOperationVolume(ctx, clientIDs)
	if err != nil {
		return nil, err
	}
	byWeek := map[string]*approval.WeekVolume{}
	var order []string
	for _, r := range rows {
		key := r.WeekStart.Format("2006-01-02")
		wv, ok := byWeek[key]
		if !ok {
			wv = &approval.WeekVolume{WeekStart: r.WeekStart}
			byWeek[key] = wv
			order = append(order, key)
		}
		switch approval.OperationType(r.OperationType) {
		case approval.OperationTypeLoad:
			wv.Dispersion = r.Total
		case approval.OperationTypeDebit:
			wv.Deduccion = r.Total
		case approval.OperationTypeTransfer:
			wv.Transferencia = r.Total
		}
	}
	out := make([]approval.WeekVolume, 0, len(order))
	for _, key := range order {
		out = append(out, *byWeek[key])
	}
	return out, nil
}

func (s *Store) needsApproval(ctx context.Context, clientID string, opType approval.OperationType, amount float64) (bool, error) {
	row, err := s.q.GetApprovalRule(ctx, sqlcgen.GetApprovalRuleParams{
		ClientID:      clientID,
		OperationType: sqlcgen.OperationType(opType),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil // sin regla configurada => requiere aprobación (fail-safe)
	}
	if err != nil {
		return false, err
	}
	if !row.RequiresApproval {
		return false, nil
	}
	if row.MinAmount == nil {
		return true, nil
	}
	return amount > *row.MinAmount, nil
}

// tryExecute — mismo criterio "nunca a medias" que
// internal/adapters/memory/repository/transfer.go: el primer movimiento
// que fallaría por fondos insuficientes se revisa antes de tocar el
// segundo. Reutiliza los métodos de LedgerRepository/TreasuryRepository
// que este mismo Store ya implementa.
func (s *Store) tryExecute(ctx context.Context, op approval.Operation) (approval.Operation, error) {
	var execErr error
	switch op.Type {
	case approval.OperationTypeLoad:
		concentrator, err := s.GetConcentratorAccount(ctx, op.ClientID)
		if err != nil {
			return approval.Operation{}, err
		}
		if concentrator == nil {
			return approval.Operation{}, shared.ErrNotFound
		}
		if _, execErr = s.PostConcentratorEntry(ctx, concentrator.ID, ledger.EntryDebit, op.Amount, "Dispersión a tarjeta"); execErr == nil {
			_, execErr = s.PostEntry(ctx, op.CardID, ledger.EntryCredit, op.Amount, "Carga de fondos")
		}
	case approval.OperationTypeDebit:
		if _, execErr = s.PostEntry(ctx, op.CardID, ledger.EntryDebit, op.Amount, "Débito"); execErr == nil {
			concentrator, err := s.GetConcentratorAccount(ctx, op.ClientID)
			if err != nil {
				return approval.Operation{}, err
			}
			if concentrator == nil {
				return approval.Operation{}, shared.ErrNotFound
			}
			_, execErr = s.PostConcentratorEntry(ctx, concentrator.ID, ledger.EntryCredit, op.Amount, "Deducción devuelta a la Concentradora")
		}
	case approval.OperationTypeTransfer:
		if _, execErr = s.PostEntry(ctx, op.CardID, ledger.EntryDebit, op.Amount, "Transferencia enviada"); execErr == nil {
			_, execErr = s.PostEntry(ctx, *op.DestinationCardID, ledger.EntryCredit, op.Amount, "Transferencia recibida")
		}
	}

	if execErr != nil {
		if errors.Is(execErr, shared.ErrInsufficientFunds) {
			notes := "Fondos insuficientes."
			op.Status = approval.OperationStatusFailed
			op.ResolutionNotes = &notes
			return op, nil
		}
		return approval.Operation{}, execErr
	}
	op.Status = approval.OperationStatusExecuted
	return op, nil
}

func (s *Store) Request(ctx context.Context, clientID, cardID string, opType approval.OperationType, amount float64, destinationCardID *string, requestedByEmail string) (approval.Operation, error) {
	operable, err := s.IsOperable(ctx, clientID)
	if err != nil {
		return approval.Operation{}, err
	}
	if !operable {
		return approval.Operation{}, shared.ErrForbidden
	}

	requestedByID, err := s.q.GetStaffUserIDByEmail(ctx, requestedByEmail)
	if err != nil {
		return approval.Operation{}, err
	}

	needsApproval, err := s.needsApproval(ctx, clientID, opType, amount)
	if err != nil {
		return approval.Operation{}, err
	}

	status := sqlcgen.OperationStatusPendingApproval
	row, err := s.q.InsertBalanceOperation(ctx, sqlcgen.InsertBalanceOperationParams{
		ClientID:          clientID,
		CardID:            cardID,
		OperationType:     sqlcgen.OperationType(opType),
		Amount:            &amount,
		DestinationCardID: destinationCardID,
		Status:            status,
		RequestedBy:       requestedByID,
	})
	if err != nil {
		return approval.Operation{}, err
	}
	op := approval.Operation{
		ID:                row.ID,
		ClientID:          clientID,
		CardID:            cardID,
		Type:              opType,
		Amount:            amount,
		DestinationCardID: destinationCardID,
		Status:            approval.OperationStatusPendingApproval,
		RequestedByEmail:  requestedByEmail,
		CreatedAt:         row.CreatedAt,
		UpdatedAt:         row.UpdatedAt,
	}

	if !needsApproval {
		op, err = s.tryExecute(ctx, op)
		if err != nil {
			return approval.Operation{}, err
		}
		if err := s.q.UpdateBalanceOperationStatus(ctx, sqlcgen.UpdateBalanceOperationStatusParams{
			ID:              op.ID,
			Status:          sqlcgen.OperationStatus(op.Status),
			ResolutionNotes: op.ResolutionNotes,
		}); err != nil {
			return approval.Operation{}, err
		}
	}
	return op, nil
}

func (s *Store) getOperationForUpdate(ctx context.Context, tx pgx.Tx, operationID string) (approval.Operation, error) {
	qtx := s.q.WithTx(tx)
	row, err := qtx.GetBalanceOperationForUpdate(ctx, operationID)
	if errors.Is(err, pgx.ErrNoRows) {
		return approval.Operation{}, shared.ErrNotFound
	}
	if err != nil {
		return approval.Operation{}, err
	}
	return mapper.ToBalanceOperation(mapper.BalanceOperationRow(row)), nil
}

// Approve — intenta ejecutar ahora, termina en executed o failed. Lanza
// shared.ErrInvalidState si la operación no estaba pending_approval.
func (s *Store) Approve(ctx context.Context, operationID, approvedByEmail string) (approval.Operation, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return approval.Operation{}, err
	}
	defer tx.Rollback(ctx)

	op, err := s.getOperationForUpdate(ctx, tx, operationID)
	if err != nil {
		return approval.Operation{}, err
	}
	if op.Status != approval.OperationStatusPendingApproval {
		return approval.Operation{}, shared.ErrInvalidState
	}
	operable, err := s.IsOperable(ctx, op.ClientID)
	if err != nil {
		return approval.Operation{}, err
	}
	if !operable {
		return approval.Operation{}, shared.ErrForbidden
	}
	if err := tx.Commit(ctx); err != nil {
		return approval.Operation{}, err
	}

	executed, err := s.tryExecute(ctx, op)
	if err != nil {
		return approval.Operation{}, err
	}
	executed.ResolvedByEmail = &approvedByEmail
	approvedByID, err := s.q.GetStaffUserIDByEmail(ctx, approvedByEmail)
	if err != nil {
		return approval.Operation{}, err
	}
	if err := s.q.UpdateBalanceOperationStatus(ctx, sqlcgen.UpdateBalanceOperationStatusParams{
		ID:              executed.ID,
		Status:          sqlcgen.OperationStatus(executed.Status),
		ResolvedBy:      &approvedByID,
		ResolutionNotes: executed.ResolutionNotes,
	}); err != nil {
		return approval.Operation{}, err
	}
	return executed, nil
}

// Reject — nunca toca el ledger. Lanza shared.ErrInvalidState si la
// operación no estaba pending_approval.
func (s *Store) Reject(ctx context.Context, operationID, rejectedByEmail, reason string) (approval.Operation, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return approval.Operation{}, err
	}
	defer tx.Rollback(ctx)

	op, err := s.getOperationForUpdate(ctx, tx, operationID)
	if err != nil {
		return approval.Operation{}, err
	}
	if op.Status != approval.OperationStatusPendingApproval {
		return approval.Operation{}, shared.ErrInvalidState
	}
	operable, err := s.IsOperable(ctx, op.ClientID)
	if err != nil {
		return approval.Operation{}, err
	}
	if !operable {
		return approval.Operation{}, shared.ErrForbidden
	}

	rejectedByID, err := s.q.GetStaffUserIDByEmail(ctx, rejectedByEmail)
	if err != nil {
		return approval.Operation{}, err
	}
	qtx := s.q.WithTx(tx)
	if err := qtx.UpdateBalanceOperationStatus(ctx, sqlcgen.UpdateBalanceOperationStatusParams{
		ID:              operationID,
		Status:          sqlcgen.OperationStatusRejected,
		ResolvedBy:      &rejectedByID,
		ResolutionNotes: &reason,
	}); err != nil {
		return approval.Operation{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return approval.Operation{}, err
	}

	op.Status = approval.OperationStatusRejected
	op.ResolvedByEmail = &rejectedByEmail
	op.ResolutionNotes = &reason
	return op, nil
}
