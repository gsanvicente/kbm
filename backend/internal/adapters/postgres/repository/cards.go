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

		// La Cuenta Individual del Tarjetahabiente ya existe de antemano —
		// nace al darlo de alta (ManagementStore.Create), no aquí. Ver
		// docs/adr/0020-cuenta-individual-tarjetahabiente.md.
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}

		row, err := q.AssignCardIfAvailable(ctx, sqlcgen.AssignCardIfAvailableParams{
			ID:           cardID,
			CardholderID: &cardholderID,
			AccountID:    &acct.ID,
		})
		if errors.Is(err, pgx.ErrNoRows) {
			// Alguien más la tomó entre el check de arriba y este UPDATE.
			return shared.ErrCardNotAvailable
		}
		if err != nil {
			return err
		}
		assigned = mapper.ToCard(mapper.CardRow(row))
		return logCallerAudit(ctx, q, "card_assigned", "card", cardID, map[string]any{"cardholder_id": cardholderID})
	})
	if err != nil {
		return card.Card{}, err
	}
	return assigned, nil
}

// ReplaceCard — ver internal/application/ports.CardRepository.ReplaceCard.
// Atómico: cancela oldCardID y asigna newCardID a la misma Cuenta
// Individual y al mismo Tarjetahabiente — el saldo (ledger_accounts.
// account_id) y la CLABE nunca se tocan porque ninguno de los dos
// vive en card.Card. Ver docs/adr/0020-cuenta-individual-tarjetahabiente.md.
func (s *Store) ReplaceCard(ctx context.Context, oldCardID, newCardID string, reason card.CancelledReason) (card.Card, error) {
	var replaced card.Card
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		old, err := s.getByIDTx(ctx, q, oldCardID)
		if err != nil {
			return err
		}
		if old.AccountID == nil || old.CardholderID == nil {
			// Nunca fue asignada — no hay Cuenta ni Tarjetahabiente a los
			// que reasignar la tarjeta nueva.
			return shared.ErrNotFound
		}

		newCard, err := s.getByIDTx(ctx, q, newCardID)
		if err != nil {
			return err
		}
		if !newCard.IsAvailable() || newCard.ClientID != old.ClientID {
			return shared.ErrCardNotAvailable
		}

		reasonStr := string(reason)
		if _, err := q.CancelCard(ctx, sqlcgen.CancelCardParams{ID: oldCardID, CancelledReason: &reasonStr}); err != nil {
			return err
		}

		row, err := q.AssignCardIfAvailable(ctx, sqlcgen.AssignCardIfAvailableParams{
			ID:           newCardID,
			CardholderID: old.CardholderID,
			AccountID:    old.AccountID,
		})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrCardNotAvailable
		}
		if err != nil {
			return err
		}
		replaced = mapper.ToCard(mapper.CardRow(row))

		if err := logCallerAudit(ctx, q, "card_cancelled", "card", oldCardID, map[string]any{"reason": reasonStr}); err != nil {
			return err
		}
		return logCallerAudit(ctx, q, "card_replaced", "card", newCardID, map[string]any{"old_card_id": oldCardID, "cardholder_id": *old.CardholderID})
	})
	if err != nil {
		return card.Card{}, err
	}
	return replaced, nil
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
		if err != nil {
			return err
		}
		action := "card_blocked"
		if !blocked {
			action = "card_unblocked"
		}
		return logCallerAudit(ctx, q, action, "card", cardID, nil)
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
			action := "card_self_frozen"
			if !frozen {
				action = "card_self_unfrozen"
			}
			return logCallerAudit(ctx, q, action, "card", cardID, nil)
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
		return logCallerAudit(ctx, q, "client_settings_updated", "client", clientID, map[string]any{"max_active_cards_per_cardholder": max})
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}
