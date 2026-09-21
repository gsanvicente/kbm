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
	var (
		outAccount ledger.Account
		outEntries []ledger.Entry
	)
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		account, err := q.GetLedgerAccountByCardID(ctx, cardID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}

		balance, err := q.GetLatestLedgerBalance(ctx, account.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		// pgx.ErrNoRows — cuenta recién creada, sin movimientos todavía: nace
		// en 0, igual que el adaptador en memoria.

		rows, err := q.ListLedgerEntriesByAccountID(ctx, account.ID)
		if err != nil {
			return err
		}
		outEntries = make([]ledger.Entry, 0, len(rows))
		for _, r := range rows {
			outEntries = append(outEntries, mapper.ToLedgerEntry(cardID, mapper.LedgerEntryRow(r)))
		}
		outAccount = mapper.ToLedgerAccount(cardID, balance, account.Currency)
		return nil
	})
	if err != nil {
		return ledger.Account{}, nil, err
	}
	return outAccount, outEntries, nil
}

// PostEntry — bloquea la fila de ledger_accounts (FOR UPDATE) antes de
// leer el saldo vigente, para que dos operaciones concurrentes sobre la
// misma tarjeta se serialicen — mismo propósito que el mutex por cuenta
// del adaptador en memoria (store.go, ledgerMu), aplicado a nivel de fila
// de Postgres en vez de en memoria de proceso.
func (s *Store) PostEntry(ctx context.Context, cardID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error) {
	var result ledger.Entry
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		account, err := q.GetLedgerAccountByCardIDForUpdate(ctx, cardID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}

		current, err := q.GetLatestLedgerBalance(ctx, account.ID)
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
		row, err := q.InsertLedgerEntry(ctx, sqlcgen.InsertLedgerEntryParams{
			ClientID:        account.ClientID,
			LedgerAccountID: account.ID,
			EntryType:       sqlcgen.LedgerEntryType(entryType),
			Amount:          amount,
			BalanceAfter:    newBalance,
			Description:     &desc,
		})
		if err != nil {
			return err
		}
		result = mapper.ToLedgerEntry(cardID, mapper.LedgerEntryRow(row))
		return nil
	})
	if err != nil {
		return ledger.Entry{}, err
	}
	return result, nil
}
