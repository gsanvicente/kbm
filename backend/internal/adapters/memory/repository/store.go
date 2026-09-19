// Package repository implements the application layer's Card/Ledger/
// Cardholder-login/Transfer ports fully in memory — no Postgres, no
// persistence across restarts. See
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md and
// docs/tdr/0003-in-memory-repository-adapter.md.
//
// One Store struct implements every port in this slice (CardRepository,
// LedgerRepository, CardholderAuthRepository, TransferService) — same
// rationale as cardholder/lib/core/fake_backend.dart on the Dart side:
// they all read/mutate the same small universe of data, and splitting
// them into separate structs would just mean injecting them into each
// other for no real benefit at this size. Each aggregate still gets its
// own mutex, so this isn't a shortcut around correctness — see
// TDR-0003 for why.
package repository

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

const maxFailedAttempts = 5

// Ver Assign() — default cuando un Cliente no tiene override en
// maxActiveCardsByClient.
const defaultMaxActiveCardsPerCardholder = 1

type Store struct {
	cardsMu sync.RWMutex
	cards   map[string]card.Card

	ledgerMu sync.RWMutex
	accounts map[string]ledger.Account
	entries  map[string][]ledger.Entry // keyed by CardID

	cardholdersMu sync.RWMutex
	cardholders   map[string]cardholder.Cardholder

	// Config sembrada, no mutable en esta iteración — ver
	// docs/business/tarjetas-y-asignacion.md.
	maxActiveCardsByClient map[string]int

	// Solo para resolver una transferencia C2C — nunca se expone fuera de
	// este archivo. Ver docs/adr/0009-pan-hash-transit-for-c2c-transfers.md.
	panHashByCardID map[string]string

	attemptsMu     sync.Mutex
	failedAttempts map[string]int
}

func NewStore() *Store {
	s := &Store{
		cards:                  seedCards(),
		accounts:               map[string]ledger.Account{},
		entries:                map[string][]ledger.Entry{},
		cardholders:            seedCardholders(),
		maxActiveCardsByClient: seedCardLimits(),
		panHashByCardID:        map[string]string{},
		failedAttempts:         map[string]int{},
	}
	s.seedLedger()
	s.seedPANHashes()
	return s
}

// --- CardRepository ------------------------------------------------------

func (s *Store) ListByCardholder(_ context.Context, cardholderID string) ([]card.Card, error) {
	s.cardsMu.RLock()
	defer s.cardsMu.RUnlock()
	var out []card.Card
	for _, c := range s.cards {
		if c.CardholderID != nil && *c.CardholderID == cardholderID {
			out = append(out, c)
		}
	}
	sortCardsByID(out)
	return out, nil
}

func (s *Store) ListByClient(_ context.Context, clientID string) ([]card.Card, error) {
	s.cardsMu.RLock()
	defer s.cardsMu.RUnlock()
	var out []card.Card
	for _, c := range s.cards {
		if c.ClientID == clientID {
			out = append(out, c)
		}
	}
	sortCardsByID(out)
	return out, nil
}

func (s *Store) GetByID(_ context.Context, id string) (card.Card, error) {
	s.cardsMu.RLock()
	defer s.cardsMu.RUnlock()
	c, ok := s.cards[id]
	if !ok {
		return card.Card{}, shared.ErrNotFound
	}
	return c, nil
}

func (s *Store) Assign(_ context.Context, cardID, cardholderID string) (card.Card, error) {
	s.cardsMu.Lock()
	defer s.cardsMu.Unlock()

	c, ok := s.cards[cardID]
	if !ok {
		return card.Card{}, shared.ErrNotFound
	}
	if !c.IsAvailable() {
		return card.Card{}, shared.ErrCardNotAvailable
	}

	// Default de 1 tarjeta activa por tarjetahabiente para cualquier
	// Cliente sin override explícito en el mapa — ver
	// docs/business/tarjetas-y-asignacion.md, "Límite de tarjetas activas
	// por Tarjetahabiente". Nunca "sin límite": ese default cambió de
	// "sin restricción" a 1 explícitamente.
	max, hasOverride := s.maxActiveCardsByClient[c.ClientID]
	if !hasOverride {
		max = defaultMaxActiveCardsPerCardholder
	}
	active := 0
	for _, other := range s.cards {
		if other.CardholderID != nil && *other.CardholderID == cardholderID && other.Status == card.StatusActive {
			active++
		}
	}
	if active >= max {
		return card.Card{}, &shared.CardLimitExceededError{Limit: max}
	}

	holderID := cardholderID
	now := time.Now()
	c.CardholderID = &holderID
	c.Status = card.StatusActive
	c.BlockedReason = nil
	c.AssignedAt = &now
	s.cards[cardID] = c

	// Una tarjeta recién asignada nace con saldo cero — mismo criterio
	// que docs/business/tarjetas-y-asignacion.md ("su ledger_account se
	// crea en el momento de la asignación, no antes").
	s.ledgerMu.Lock()
	if _, exists := s.accounts[cardID]; !exists {
		s.accounts[cardID] = ledger.Account{CardID: cardID, Balance: 0, Currency: "MXN"}
	}
	s.ledgerMu.Unlock()

	return c, nil
}

func (s *Store) SetBlocked(_ context.Context, cardID string, blocked bool) (card.Card, error) {
	s.cardsMu.Lock()
	defer s.cardsMu.Unlock()

	c, ok := s.cards[cardID]
	if !ok {
		return card.Card{}, shared.ErrNotFound
	}

	if blocked {
		reason := card.BlockedReasonManual
		c.Status = card.StatusBlocked
		c.BlockedReason = &reason
	} else {
		c.Status = card.StatusActive
		c.BlockedReason = nil
	}
	s.cards[cardID] = c
	return c, nil
}

func (s *Store) SetFrozen(_ context.Context, cardID, cardholderID string, frozen bool) (card.Card, error) {
	s.cardsMu.Lock()
	defer s.cardsMu.Unlock()

	c, ok := s.cards[cardID]
	if !ok {
		return card.Card{}, shared.ErrNotFound
	}
	// Nunca revela si la tarjeta existe pero es de otra persona — mismo
	// criterio que el resto de este backend con datos de otro
	// Tarjetahabiente.
	if c.CardholderID == nil || *c.CardholderID != cardholderID {
		return card.Card{}, shared.ErrNotFound
	}

	if frozen {
		// Congelar solo aplica sobre "active" — nunca sobre "blocked"
		// (un bloqueo de staff no se toca desde aquí) ni sobre ya
		// "frozen".
		if c.Status != card.StatusActive {
			return card.Card{}, shared.ErrInvalidState
		}
		c.Status = card.StatusFrozen
	} else {
		// Descongelar solo aplica sobre "frozen" — si está "blocked",
		// esto nunca es la vía para revertirlo (ver SetBlocked).
		if c.Status != card.StatusFrozen {
			return card.Card{}, shared.ErrInvalidState
		}
		c.Status = card.StatusActive
	}
	s.cards[cardID] = c
	return c, nil
}

func (s *Store) FreezeAllForCardholder(_ context.Context, cardholderID string) error {
	s.cardsMu.Lock()
	defer s.cardsMu.Unlock()

	for id, c := range s.cards {
		if c.CardholderID == nil || *c.CardholderID != cardholderID {
			continue
		}
		if c.Status == card.StatusBlocked {
			continue // ya bloqueada, por el motivo que sea — no se toca
		}
		reason := card.BlockedReasonCardholderInactive
		c.Status = card.StatusBlocked
		c.BlockedReason = &reason
		s.cards[id] = c
	}
	return nil
}

func sortCardsByID(cards []card.Card) {
	sort.Slice(cards, func(i, j int) bool { return cards[i].ID < cards[j].ID })
}

// --- LedgerRepository ------------------------------------------------------

func (s *Store) GetByCard(_ context.Context, cardID string) (ledger.Account, []ledger.Entry, error) {
	s.ledgerMu.RLock()
	defer s.ledgerMu.RUnlock()
	account, ok := s.accounts[cardID]
	if !ok {
		return ledger.Account{}, nil, shared.ErrNotFound
	}
	entries := append([]ledger.Entry(nil), s.entries[cardID]...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].CreatedAt.After(entries[j].CreatedAt) })
	return account, entries, nil
}

func (s *Store) PostEntry(_ context.Context, cardID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error) {
	s.ledgerMu.Lock()
	defer s.ledgerMu.Unlock()

	account, ok := s.accounts[cardID]
	if !ok {
		return ledger.Entry{}, shared.ErrNotFound
	}

	newBalance := account.Balance
	if entryType == ledger.EntryCredit {
		newBalance += amount
	} else {
		newBalance -= amount
	}
	if newBalance < 0 {
		return ledger.Entry{}, shared.ErrInsufficientFunds
	}

	entry := ledger.Entry{
		ID:           fmt.Sprintf("entry-%d", time.Now().UnixNano()),
		CardID:       cardID,
		Type:         entryType,
		Amount:       amount,
		BalanceAfter: newBalance,
		Description:  description,
		CreatedAt:    time.Now(),
	}
	s.entries[cardID] = append(s.entries[cardID], entry)
	account.Balance = newBalance
	s.accounts[cardID] = account
	return entry, nil
}

// --- CardholderAuthRepository ------------------------------------------------------

func (s *Store) Login(_ context.Context, email, password string) (cardholder.Cardholder, error) {
	s.cardholdersMu.RLock()
	defer s.cardholdersMu.RUnlock()

	for _, ch := range s.cardholders {
		if ch.Email == email {
			// Capa 1 — ver docs/business/desactivacion-de-tarjetahabientes.md.
			// Mismo mensaje genérico para contraseña incorrecta e
			// inactivo, nunca se distingue el motivo.
			if ch.Password != password || !ch.IsActive {
				return cardholder.Cardholder{}, shared.ErrInvalidCredentials
			}
			// El límite de intentos fallidos de transferencia es por
			// sesión, nunca permanente — se reinicia en cada login
			// exitoso. Ver docs/security/threat-model.md punto 12.
			s.attemptsMu.Lock()
			delete(s.failedAttempts, ch.ID)
			s.attemptsMu.Unlock()
			return ch, nil
		}
	}
	return cardholder.Cardholder{}, shared.ErrInvalidCredentials
}
