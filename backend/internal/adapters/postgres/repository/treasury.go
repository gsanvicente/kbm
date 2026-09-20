package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/treasury"
)

func (s *Store) GetConcentratorAccount(ctx context.Context, clientID string) (*treasury.ConcentratorAccount, error) {
	row, err := s.q.GetConcentratorAccountByClient(ctx, clientID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	balance, err := s.q.GetLatestConcentratorBalance(ctx, row.ID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	account := mapper.ToConcentratorAccount(row.ID, row.ClientID, row.Currency, balance)
	return &account, nil
}

func (s *Store) CreateConcentratorAccount(ctx context.Context, clientID string) (treasury.ConcentratorAccount, error) {
	row, err := s.q.CreateConcentratorAccount(ctx, clientID)
	if err != nil {
		return treasury.ConcentratorAccount{}, err
	}
	return mapper.ToConcentratorAccount(row.ID, row.ClientID, row.Currency, 0), nil
}

func (s *Store) ListConcentratorEntries(ctx context.Context, concentratorAccountID string) ([]treasury.ConcentratorEntry, error) {
	rows, err := s.q.ListConcentratorEntries(ctx, concentratorAccountID)
	if err != nil {
		return nil, err
	}
	out := make([]treasury.ConcentratorEntry, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToConcentratorEntry(mapper.ConcentratorEntryRow(r)))
	}
	return out, nil
}

// PostConcentratorEntry — bloquea la fila de concentrator_accounts (FOR
// UPDATE) antes de leer el saldo vigente, mismo patrón que
// LedgerRepository.PostEntry en ledger.go.
func (s *Store) PostConcentratorEntry(ctx context.Context, concentratorAccountID string, entryType ledger.EntryType, amount float64, description string) (treasury.ConcentratorEntry, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return treasury.ConcentratorEntry{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	if err := qtx.LockConcentratorAccount(ctx, concentratorAccountID); err != nil {
		return treasury.ConcentratorEntry{}, err
	}

	current, err := qtx.GetLatestConcentratorBalance(ctx, concentratorAccountID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return treasury.ConcentratorEntry{}, err
	}

	newBalance := current
	if entryType == ledger.EntryCredit {
		newBalance += amount
	} else {
		newBalance -= amount
	}
	if newBalance < 0 {
		return treasury.ConcentratorEntry{}, shared.ErrInsufficientFunds
	}

	desc := description
	row, err := qtx.InsertConcentratorEntry(ctx, sqlcgen.InsertConcentratorEntryParams{
		ConcentratorAccountID: concentratorAccountID,
		EntryType:             sqlcgen.LedgerEntryType(entryType),
		Amount:                amount,
		BalanceAfter:          newBalance,
		Description:           &desc,
	})
	if err != nil {
		return treasury.ConcentratorEntry{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return treasury.ConcentratorEntry{}, err
	}
	return mapper.ToConcentratorEntry(mapper.ConcentratorEntryRow(row)), nil
}

func (s *Store) ListCollectorDeposits(ctx context.Context, clientID string) ([]treasury.CollectorDeposit, error) {
	rows, err := s.q.ListCollectorDepositsByClient(ctx, clientID)
	if err != nil {
		return nil, err
	}
	out := make([]treasury.CollectorDeposit, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToCollectorDeposit(mapper.CollectorDepositRow(r)))
	}
	return out, nil
}

func (s *Store) RegisterDeposit(ctx context.Context, clientID string, amount float64, reference, registeredByEmail string) (treasury.CollectorDeposit, error) {
	registeredByID, err := s.q.GetStaffUserIDByEmail(ctx, registeredByEmail)
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	row, err := s.q.InsertCollectorDeposit(ctx, sqlcgen.InsertCollectorDepositParams{
		ClientID:     clientID,
		Amount:       amount,
		Reference:    reference,
		RegisteredBy: registeredByID,
	})
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	return treasury.CollectorDeposit{
		ID:                row.ID,
		ClientID:          row.ClientID,
		Amount:            row.Amount,
		Reference:         row.Reference,
		Status:            treasury.CollectorDepositStatus(row.Status),
		RegisteredByEmail: registeredByEmail,
		CreatedAt:         row.CreatedAt,
	}, nil
}

// ReconcileDeposit — mueve pending -> reconciled y acredita la
// Concentradora del mismo Cliente, en una transacción. Lanza
// shared.ErrInvalidState si el depósito ya fue conciliado.
func (s *Store) ReconcileDeposit(ctx context.Context, depositID, reconciledByEmail string) (treasury.CollectorDeposit, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	deposit, err := qtx.GetCollectorDepositForUpdate(ctx, depositID)
	if errors.Is(err, pgx.ErrNoRows) {
		return treasury.CollectorDeposit{}, shared.ErrNotFound
	}
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	if deposit.Status == sqlcgen.CollectorDepositStatusReconciled {
		return treasury.CollectorDeposit{}, shared.ErrInvalidState
	}

	reconciledByID, err := qtx.GetStaffUserIDByEmail(ctx, reconciledByEmail)
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	if err := qtx.ReconcileCollectorDeposit(ctx, sqlcgen.ReconcileCollectorDepositParams{
		ID:           depositID,
		ReconciledBy: &reconciledByID,
	}); err != nil {
		return treasury.CollectorDeposit{}, err
	}

	account, err := qtx.GetConcentratorAccountByClient(ctx, deposit.ClientID)
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	current, err := qtx.GetLatestConcentratorBalance(ctx, account.ID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return treasury.CollectorDeposit{}, err
	}
	desc := "Conciliación de depósito " + deposit.Reference
	if _, err := qtx.InsertConcentratorEntry(ctx, sqlcgen.InsertConcentratorEntryParams{
		ConcentratorAccountID: account.ID,
		EntryType:             sqlcgen.LedgerEntryTypeCredit,
		Amount:                deposit.Amount,
		BalanceAfter:          current + deposit.Amount,
		Description:           &desc,
	}); err != nil {
		return treasury.CollectorDeposit{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return treasury.CollectorDeposit{}, err
	}

	updatedRow, err := s.q.GetCollectorDepositForUpdate(ctx, depositID)
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	return mapper.ToCollectorDeposit(mapper.CollectorDepositRow(updatedRow)), nil
}
