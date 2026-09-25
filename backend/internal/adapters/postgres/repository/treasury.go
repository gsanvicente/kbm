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
	var result *treasury.ConcentratorAccount
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetConcentratorAccountByClient(ctx, clientID)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		balance, err := q.GetLatestConcentratorBalance(ctx, row.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		account := mapper.ToConcentratorAccount(row.ID, row.ClientID, row.Currency, balance)
		result = &account
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *Store) CreateConcentratorAccount(ctx context.Context, clientID string) (treasury.ConcentratorAccount, error) {
	var result treasury.ConcentratorAccount
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.CreateConcentratorAccount(ctx, clientID)
		if err != nil {
			return err
		}
		result = mapper.ToConcentratorAccount(row.ID, row.ClientID, row.Currency, 0)
		return nil
	})
	if err != nil {
		return treasury.ConcentratorAccount{}, err
	}
	return result, nil
}

func (s *Store) ListConcentratorEntries(ctx context.Context, concentratorAccountID string) ([]treasury.ConcentratorEntry, error) {
	var out []treasury.ConcentratorEntry
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListConcentratorEntries(ctx, concentratorAccountID)
		if err != nil {
			return err
		}
		out = make([]treasury.ConcentratorEntry, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToConcentratorEntry(mapper.ConcentratorEntryRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// PostConcentratorEntry — bloquea la fila de concentrator_accounts (FOR
// UPDATE) antes de leer el saldo vigente, mismo patrón que
// LedgerRepository.PostEntry en ledger.go.
func (s *Store) PostConcentratorEntry(ctx context.Context, concentratorAccountID string, entryType ledger.EntryType, amount float64, description string) (treasury.ConcentratorEntry, error) {
	var result treasury.ConcentratorEntry
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		if err := q.LockConcentratorAccount(ctx, concentratorAccountID); err != nil {
			return err
		}

		current, err := q.GetLatestConcentratorBalance(ctx, concentratorAccountID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}

		newBalance := current
		if entryType == ledger.EntryCredit {
			newBalance += amount
		} else {
			newBalance -= amount
		}
		if newBalance < 0 {
			return shared.ErrInsufficientFunds
		}

		desc := description
		row, err := q.InsertConcentratorEntry(ctx, sqlcgen.InsertConcentratorEntryParams{
			ConcentratorAccountID: concentratorAccountID,
			EntryType:             sqlcgen.LedgerEntryType(entryType),
			Amount:                amount,
			BalanceAfter:          newBalance,
			Description:           &desc,
		})
		if err != nil {
			return err
		}
		result = mapper.ToConcentratorEntry(mapper.ConcentratorEntryRow(row))
		return nil
	})
	if err != nil {
		return treasury.ConcentratorEntry{}, err
	}
	return result, nil
}

// GetStatement — el "Estado de cuenta para directivos" de ADR-0022,
// punto 5. Reusa GetConcentratorAccount + ListConcentratorEntries (cada
// uno ya con su propio withRLS) en vez de una consulta nueva — nil, nil
// si el Cliente todavía no tiene Cuenta Concentradora creada.
func (s *Store) GetStatement(ctx context.Context, clientID string) (*treasury.Statement, error) {
	account, err := s.GetConcentratorAccount(ctx, clientID)
	if err != nil {
		return nil, err
	}
	if account == nil {
		return nil, nil
	}
	entries, err := s.ListConcentratorEntries(ctx, account.ID)
	if err != nil {
		return nil, err
	}
	return &treasury.Statement{
		ConcentratorBalance: account.Balance,
		Currency:            account.Currency,
		Entries:             entries,
	}, nil
}

func (s *Store) ListCollectorDeposits(ctx context.Context, clientID string) ([]treasury.CollectorDeposit, error) {
	var out []treasury.CollectorDeposit
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListCollectorDepositsByClient(ctx, clientID)
		if err != nil {
			return err
		}
		out = make([]treasury.CollectorDeposit, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToCollectorDeposit(mapper.CollectorDepositRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *Store) RegisterDeposit(ctx context.Context, clientID string, amount float64, reference, registeredByEmail string) (treasury.CollectorDeposit, error) {
	var result treasury.CollectorDeposit
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		registeredByID, err := q.GetStaffUserIDByEmail(ctx, registeredByEmail)
		if err != nil {
			return err
		}
		row, err := q.InsertCollectorDeposit(ctx, sqlcgen.InsertCollectorDepositParams{
			ClientID:     clientID,
			Amount:       amount,
			Reference:    reference,
			RegisteredBy: registeredByID,
		})
		if err != nil {
			return err
		}
		result = treasury.CollectorDeposit{
			ID:                row.ID,
			ClientID:          row.ClientID,
			Amount:            row.Amount,
			Reference:         row.Reference,
			Status:            treasury.CollectorDepositStatus(row.Status),
			RegisteredByEmail: registeredByEmail,
			CreatedAt:         row.CreatedAt,
		}
		return logCallerAudit(ctx, q, "deposit_registered", "collector_deposit", row.ID, map[string]any{"client_id": clientID, "amount": amount, "reference": reference})
	})
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	return result, nil
}

// ReconcileDeposit — mueve pending -> reconciled y acredita la
// Concentradora del mismo Cliente, en una transacción. Lanza
// shared.ErrInvalidState si el depósito ya fue conciliado.
func (s *Store) ReconcileDeposit(ctx context.Context, depositID, reconciledByEmail string) (treasury.CollectorDeposit, error) {
	var result treasury.CollectorDeposit
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		deposit, err := q.GetCollectorDepositForUpdate(ctx, depositID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		if deposit.Status == sqlcgen.CollectorDepositStatusReconciled {
			return shared.ErrInvalidState
		}

		reconciledByID, err := q.GetStaffUserIDByEmail(ctx, reconciledByEmail)
		if err != nil {
			return err
		}
		if err := q.ReconcileCollectorDeposit(ctx, sqlcgen.ReconcileCollectorDepositParams{
			ID:           depositID,
			ReconciledBy: &reconciledByID,
		}); err != nil {
			return err
		}

		account, err := q.GetConcentratorAccountByClient(ctx, deposit.ClientID)
		if err != nil {
			return err
		}
		current, err := q.GetLatestConcentratorBalance(ctx, account.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		desc := "Conciliación de depósito " + deposit.Reference
		if _, err := q.InsertConcentratorEntry(ctx, sqlcgen.InsertConcentratorEntryParams{
			ConcentratorAccountID: account.ID,
			EntryType:             sqlcgen.LedgerEntryTypeCredit,
			Amount:                deposit.Amount,
			BalanceAfter:          current + deposit.Amount,
			Description:           &desc,
		}); err != nil {
			return err
		}

		updatedRow, err := q.GetCollectorDepositForUpdate(ctx, depositID)
		if err != nil {
			return err
		}
		result = mapper.ToCollectorDeposit(mapper.CollectorDepositRow(updatedRow))
		return logCallerAudit(ctx, q, "deposit_reconciled", "collector_deposit", depositID, map[string]any{"reconciled_by_email": reconciledByEmail})
	})
	if err != nil {
		return treasury.CollectorDeposit{}, err
	}
	return result, nil
}
