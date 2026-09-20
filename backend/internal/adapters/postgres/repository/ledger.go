package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

func (s *Store) GetByCard(ctx context.Context, cardID string) (ledger.Account, []ledger.Entry, error) {
	account, err := s.q.GetLedgerAccountByCardID(ctx, cardID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ledger.Account{}, nil, shared.ErrNotFound
	}
	if err != nil {
		return ledger.Account{}, nil, err
	}

	balance, err := s.q.GetLatestLedgerBalance(ctx, account.ID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return ledger.Account{}, nil, err
	}
	// pgx.ErrNoRows — cuenta recién creada, sin movimientos todavía: nace
	// en 0, igual que el adaptador en memoria.

	rows, err := s.q.ListLedgerEntriesByAccountID(ctx, account.ID)
	if err != nil {
		return ledger.Account{}, nil, err
	}
	entries := make([]ledger.Entry, 0, len(rows))
	for _, r := range rows {
		entries = append(entries, mapper.ToLedgerEntry(cardID, mapper.LedgerEntryRow(r)))
	}

	return mapper.ToLedgerAccount(cardID, balance, account.Currency), entries, nil
}

// PostEntry — bloquea la fila de ledger_accounts (FOR UPDATE) antes de
// leer el saldo vigente, para que dos operaciones concurrentes sobre la
// misma tarjeta se serialicen — mismo propósito que el mutex por cuenta
// del adaptador en memoria (store.go, ledgerMu), aplicado a nivel de fila
// de Postgres en vez de en memoria de proceso.
func (s *Store) PostEntry(ctx context.Context, cardID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return ledger.Entry{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	account, err := qtx.GetLedgerAccountByCardIDForUpdate(ctx, cardID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ledger.Entry{}, shared.ErrNotFound
	}
	if err != nil {
		return ledger.Entry{}, err
	}

	current, err := qtx.GetLatestLedgerBalance(ctx, account.ID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return ledger.Entry{}, err
	}

	newBalance := current
	if entryType == ledger.EntryCredit {
		newBalance += amount
	} else {
		newBalance -= amount
	}
	if newBalance < 0 {
		return ledger.Entry{}, shared.ErrInsufficientFunds
	}

	desc := description
	row, err := qtx.InsertLedgerEntry(ctx, sqlcgen.InsertLedgerEntryParams{
		ClientID:        account.ClientID,
		LedgerAccountID: account.ID,
		EntryType:       sqlcgen.LedgerEntryType(entryType),
		Amount:          amount,
		BalanceAfter:    newBalance,
		Description:     &desc,
	})
	if err != nil {
		return ledger.Entry{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return ledger.Entry{}, err
	}

	return mapper.ToLedgerEntry(cardID, mapper.LedgerEntryRow(row)), nil
}
