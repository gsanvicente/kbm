package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

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
	var out []card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListCardsByCardholder(ctx, &cardholderID)
		if err != nil {
			return err
		}
		out = make([]card.Card, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToCard(mapper.CardRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *Store) ListByClient(ctx context.Context, clientID string) ([]card.Card, error) {
	var out []card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListCardsByClient(ctx, clientID)
		if err != nil {
			return err
		}
		out = make([]card.Card, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToCard(mapper.CardRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *Store) getByIDTx(ctx context.Context, q *sqlcgen.Queries, id string) (card.Card, error) {
	row, err := q.GetCardByID(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return card.Card{}, shared.ErrNotFound
	}
	if err != nil {
		return card.Card{}, err
	}
	return mapper.ToCard(mapper.CardRow(row)), nil
}

func (s *Store) GetByID(ctx context.Context, id string) (card.Card, error) {
	var out card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		out, err = s.getByIDTx(ctx, q, id)
		return err
	})
	if err != nil {
		return card.Card{}, err
	}
	return out, nil
}

// Assign — ver internal/application/ports.CardRepository.Assign. La
// disponibilidad (status = 'unassigned') se revalida atómicamente en el
// propio UPDATE (AssignCardIfAvailable, WHERE status = 'unassigned'), no
// con un SELECT previo separado — evita la carrera de dos asignaciones
// concurrentes a la misma tarjeta que un check-then-act permitiría. Todo
// en una sola transacción con RLS ya fijado — antes eran dos ciclos
// (GetByID por su cuenta, luego un tx aparte para el ledger_account),
// ahora es uno solo.
func (s *Store) Assign(ctx context.Context, cardID, cardholderID string) (card.Card, error) {
	var assigned card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		existing, err := s.getByIDTx(ctx, q, cardID)
		if err != nil {
			return err
		}
		if !existing.IsAvailable() {
			return shared.ErrCardNotAvailable
		}

		max := defaultMaxActiveCardsPerCardholder
		limitRow, err := q.GetClientMaxActiveCards(ctx, existing.ClientID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		if err == nil && limitRow.Valid {
			max = int(limitRow.Int32)
		}

		active, err := q.CountActiveCardsByCardholder(ctx, &cardholderID)
		if err != nil {
			return err
		}
		if int(active) >= max {
			return &shared.CardLimitExceededError{Limit: max}
		}

		row, err := q.AssignCardIfAvailable(ctx, sqlcgen.AssignCardIfAvailableParams{
			ID:           cardID,
			CardholderID: &cardholderID,
		})
		if errors.Is(err, pgx.ErrNoRows) {
			// Alguien más la tomó entre el check de arriba y este UPDATE.
			return shared.ErrCardNotAvailable
		}
		if err != nil {
			return err
		}
		assigned = mapper.ToCard(mapper.CardRow(row))

		// El ledger_account nace en el momento de la asignación, con saldo
		// cero — ver docs/business/tarjetas-y-asignacion.md.
		if _, err := q.GetLedgerAccountByCardID(ctx, cardID); errors.Is(err, pgx.ErrNoRows) {
			if _, err := q.CreateLedgerAccount(ctx, sqlcgen.CreateLedgerAccountParams{
				ClientID: assigned.ClientID,
				CardID:   cardID,
				Currency: "MXN",
			}); err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return card.Card{}, err
	}
	return assigned, nil
}

func (s *Store) SetBlocked(ctx context.Context, cardID string, blocked bool) (card.Card, error) {
	var row sqlcgen.SetCardBlockedRow
	var unblockedRow sqlcgen.SetCardUnblockedRow
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		if blocked {
			row, err = q.SetCardBlocked(ctx, cardID)
		} else {
			unblockedRow, err = q.SetCardUnblocked(ctx, cardID)
		}
		return err
	})
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
	var result card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var row sqlcgen.SetCardFrozenByOwnerRow
		var unfrozenRow sqlcgen.SetCardUnfrozenByOwnerRow
		var err error
		if frozen {
			row, err = q.SetCardFrozenByOwner(ctx, sqlcgen.SetCardFrozenByOwnerParams{ID: cardID, CardholderID: &cardholderID})
		} else {
			unfrozenRow, err = q.SetCardUnfrozenByOwner(ctx, sqlcgen.SetCardUnfrozenByOwnerParams{ID: cardID, CardholderID: &cardholderID})
		}
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		if err == nil {
			if frozen {
				result = mapper.ToCard(mapper.CardRow(row))
			} else {
				result = mapper.ToCard(mapper.CardRow(unfrozenRow))
			}
			return nil
		}

		existing, getErr := s.getByIDTx(ctx, q, cardID)
		if getErr != nil {
			return getErr // shared.ErrNotFound si de plano no existe
		}
		if existing.CardholderID == nil || *existing.CardholderID != cardholderID {
			return shared.ErrNotFound
		}
		return shared.ErrInvalidState
	})
	if err != nil {
		return card.Card{}, err
	}
	return result, nil
}

func (s *Store) FreezeAllForCardholder(ctx context.Context, cardholderID string) error {
	return s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		return q.FreezeAllUnblockedCardsForCardholder(ctx, &cardholderID)
	})
}

func (s *Store) MaxActiveCardsPerCardholder(ctx context.Context, clientID string) (*int, error) {
	var result *int
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetClientMaxActiveCards(ctx, clientID)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		if !row.Valid {
			return nil
		}
		max := int(row.Int32)
		result = &max
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *Store) SetMaxActiveCardsPerCardholder(ctx context.Context, clientID string, max *int) (*int, error) {
	arg := pgtype.Int4{Valid: false}
	if max != nil {
		arg = pgtype.Int4{Int32: int32(*max), Valid: true}
	}
	var result *int
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.UpsertClientMaxActiveCards(ctx, sqlcgen.UpsertClientMaxActiveCardsParams{
			ClientID:                    clientID,
			MaxActiveCardsPerCardholder: arg,
		})
		if err != nil {
			return err
		}
		if row.MaxActiveCardsPerCardholder.Valid {
			v := int(row.MaxActiveCardsPerCardholder.Int32)
			result = &v
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}
