// Package mapper translates between sqlc-generated row structs and domain
// entities in both directions. Domain types never depend on generated SQL
// structs — see docs/tdr/0001-sqlc-pgx-over-orm.md.
package mapper

import (
	"time"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/ledger"
)

// CardRow mirrors the exact column list every query in
// internal/adapters/postgres/sqlc/queries/cards.sql selects (same names,
// types and order). sqlc generates one distinct (but structurally
// identical) Row struct per query rather than reusing one — callers
// convert their query's *Row type to this one with a plain Go struct
// conversion (valid because the underlying layouts match) before calling
// ToCard, instead of this package depending on every generated type.
type CardRow struct {
	ID            string
	ClientID      string
	CardholderID  *string
	MaskedPan     string
	Network       sqlcgen.CardNetwork
	ExpiryMonth   int16
	ExpiryYear    int16
	Status        sqlcgen.CardStatus
	BlockedReason sqlcgen.NullCardBlockedReason
	AssignedAt    *time.Time
}

func ToCard(r CardRow) card.Card {
	c := card.Card{
		ID:           r.ID,
		ClientID:     r.ClientID,
		CardholderID: r.CardholderID,
		MaskedPAN:    r.MaskedPan,
		Network:      card.Network(r.Network),
		ExpiryMonth:  int(r.ExpiryMonth),
		ExpiryYear:   int(r.ExpiryYear),
		Status:       card.Status(r.Status),
		AssignedAt:   r.AssignedAt,
	}
	if r.BlockedReason.Valid {
		reason := card.BlockedReason(r.BlockedReason.CardBlockedReason)
		c.BlockedReason = &reason
	}
	return c
}

func ToCardholder(id, clientID, fullName string, email *string, isActive bool, passwordHash string) cardholder.Cardholder {
	e := ""
	if email != nil {
		e = *email
	}
	return cardholder.Cardholder{
		ID:       id,
		ClientID: clientID,
		FullName: fullName,
		Email:    e,
		Password: passwordHash,
		IsActive: isActive,
	}
}

func ToLedgerAccount(cardID string, balance float64, currency string) ledger.Account {
	return ledger.Account{CardID: cardID, Balance: balance, Currency: currency}
}

// LedgerEntryRow mirrors ListLedgerEntriesByAccountIDRow /
// InsertLedgerEntryRow — same reasoning as CardRow above.
type LedgerEntryRow struct {
	ID              string
	ClientID        string
	LedgerAccountID string
	EntryType       sqlcgen.LedgerEntryType
	Amount          float64
	BalanceAfter    float64
	Description     *string
	CreatedAt       time.Time
}

// cardID viene del llamador (internal/adapters/postgres/repository), que
// ya lo sabe por contexto — la fila solo trae ledger_account_id, no el id
// de la tarjeta (ver ledger.Account, "1:1 con una Card... aquí el CardID
// hace también de identificador de la cuenta" no aplica en Postgres,
// donde ledger_accounts sí tiene su propio id — internal/domain/ledger/ledger.go).
func ToLedgerEntry(cardID string, r LedgerEntryRow) ledger.Entry {
	desc := ""
	if r.Description != nil {
		desc = *r.Description
	}
	return ledger.Entry{
		ID:           r.ID,
		CardID:       cardID,
		Type:         ledger.EntryType(r.EntryType),
		Amount:       r.Amount,
		BalanceAfter: r.BalanceAfter,
		Description:  desc,
		CreatedAt:    r.CreatedAt,
	}
}
