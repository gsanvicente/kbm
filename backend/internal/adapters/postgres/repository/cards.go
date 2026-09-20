package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// defaultMaxActiveCardsPerCardholder — mismo default que
// internal/adapters/memory/repository/store.go, ver
// docs/business/tarjetas-y-asignacion.md, "Límite de tarjetas activas por
// Tarjetahabiente".
const defaultMaxActiveCardsPerCardholder = 1

func (s *Store) ListByCardholder(ctx context.Context, cardholderID string) ([]card.Card, error) {
	rows, err := s.q.ListCardsByCardholder(ctx, &cardholderID)
	if err != nil {
		return nil, err
	}
	out := make([]card.Card, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToCard(mapper.CardRow(r)))
	}
	return out, nil
}

func (s *Store) ListByClient(ctx context.Context, clientID string) ([]card.Card, error) {
	rows, err := s.q.ListCardsByClient(ctx, clientID)
	if err != nil {
		return nil, err
	}
	out := make([]card.Card, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToCard(mapper.CardRow(r)))
	}
	return out, nil
}

func (s *Store) GetByID(ctx context.Context, id string) (card.Card, error) {
	row, err := s.q.GetCardByID(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return card.Card{}, shared.ErrNotFound
	}
	if err != nil {
		return card.Card{}, err
	}
	return mapper.ToCard(mapper.CardRow(row)), nil
}

// Assign — ver internal/application/ports.CardRepository.Assign. La
// disponibilidad (status = 'unassigned') se revalida atómicamente en el
// propio UPDATE (AssignCardIfAvailable, WHERE status = 'unassigned'), no
// con un SELECT previo separado — evita la carrera de dos asignaciones
// concurrentes a la misma tarjeta que un check-then-act permitiría.
func (s *Store) Assign(ctx context.Context, cardID, cardholderID string) (card.Card, error) {
	existing, err := s.GetByID(ctx, cardID)
	if err != nil {
		return card.Card{}, err
	}
	if !existing.IsAvailable() {
		return card.Card{}, shared.ErrCardNotAvailable
	}

	max := defaultMaxActiveCardsPerCardholder
	limitRow, err := s.q.GetClientMaxActiveCards(ctx, existing.ClientID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return card.Card{}, err
	}
	if err == nil && limitRow.Valid {
		max = int(limitRow.Int32)
	}

	active, err := s.q.CountActiveCardsByCardholder(ctx, &cardholderID)
	if err != nil {
		return card.Card{}, err
	}
	if int(active) >= max {
		return card.Card{}, &shared.CardLimitExceededError{Limit: max}
	}

	row, err := s.q.AssignCardIfAvailable(ctx, sqlcgen.AssignCardIfAvailableParams{
		ID:           cardID,
		CardholderID: &cardholderID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		// Alguien más la tomó entre el check de arriba y este UPDATE.
		return card.Card{}, shared.ErrCardNotAvailable
	}
	if err != nil {
		return card.Card{}, err
	}
	assigned := mapper.ToCard(mapper.CardRow(row))

	// El ledger_account nace en el momento de la asignación, con saldo
	// cero — ver docs/business/tarjetas-y-asignacion.md.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return card.Card{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)
	if _, err := qtx.GetLedgerAccountByCardID(ctx, cardID); errors.Is(err, pgx.ErrNoRows) {
		if _, err := qtx.CreateLedgerAccount(ctx, sqlcgen.CreateLedgerAccountParams{
			ClientID: assigned.ClientID,
			CardID:   cardID,
			Currency: "MXN",
		}); err != nil {
			return card.Card{}, err
		}
	} else if err != nil {
		return card.Card{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return card.Card{}, err
	}

	return assigned, nil
}

func (s *Store) SetBlocked(ctx context.Context, cardID string, blocked bool) (card.Card, error) {
	var row sqlcgen.SetCardBlockedRow
	var unblockedRow sqlcgen.SetCardUnblockedRow
	var err error
	if blocked {
		row, err = s.q.SetCardBlocked(ctx, cardID)
	} else {
		unblockedRow, err = s.q.SetCardUnblocked(ctx, cardID)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return card.Card{}, shared.ErrNotFound
	}
	if err != nil {
		return card.Card{}, err
	}
	if blocked {
		return mapper.ToCard(mapper.CardRow(row)), nil
	}
	return mapper.ToCard(mapper.CardRow(unblockedRow)), nil
}

// SetFrozen — ver internal/application/ports.CardRepository.SetFrozen. La
// pertenencia (cardholder_id = $2) y el estado de origen correcto (active
// para congelar, frozen para descongelar) se revalidan en el propio
// UPDATE — cero filas afectadas puede significar "no existe", "es de otro
// Tarjetahabiente" o "estado inválido"; distinguimos con un GetByID
// posterior, igual que Assign hace con la disponibilidad.
func (s *Store) SetFrozen(ctx context.Context, cardID, cardholderID string, frozen bool) (card.Card, error) {
	var row sqlcgen.SetCardFrozenByOwnerRow
	var unfrozenRow sqlcgen.SetCardUnfrozenByOwnerRow
	var err error
	if frozen {
		row, err = s.q.SetCardFrozenByOwner(ctx, sqlcgen.SetCardFrozenByOwnerParams{ID: cardID, CardholderID: &cardholderID})
	} else {
		unfrozenRow, err = s.q.SetCardUnfrozenByOwner(ctx, sqlcgen.SetCardUnfrozenByOwnerParams{ID: cardID, CardholderID: &cardholderID})
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return card.Card{}, err
	}
	if err == nil {
		if frozen {
			return mapper.ToCard(mapper.CardRow(row)), nil
		}
		return mapper.ToCard(mapper.CardRow(unfrozenRow)), nil
	}

	existing, getErr := s.GetByID(ctx, cardID)
	if getErr != nil {
		return card.Card{}, getErr // shared.ErrNotFound si de plano no existe
	}
	if existing.CardholderID == nil || *existing.CardholderID != cardholderID {
		return card.Card{}, shared.ErrNotFound
	}
	return card.Card{}, shared.ErrInvalidState
}

func (s *Store) FreezeAllForCardholder(ctx context.Context, cardholderID string) error {
	return s.q.FreezeAllUnblockedCardsForCardholder(ctx, &cardholderID)
}
