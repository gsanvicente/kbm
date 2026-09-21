package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// ManagementStore implementa ports.CardholderManagementRepository — ver
// internal/application/ports/cardholder_management.go. Nombre distinto
// de Store (que ya implementa CardholderAuthRepository) solo para que
// ambos puedan convivir sin ambigüedad al inyectarse en el handler;
// ambos envuelven el mismo *pgxpool.Pool.
type ManagementStore struct {
	*Store
}

func NewManagementStore(s *Store) *ManagementStore {
	return &ManagementStore{Store: s}
}

func (s *ManagementStore) getCardholderByIDTx(ctx context.Context, q *sqlcgen.Queries, cardholderID string) (*cardholder.Cardholder, error) {
	row, err := q.GetCardholderByID(ctx, cardholderID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	c := mapper.ToCardholder(mapper.CardholderRow(row))
	return &c, nil
}

func (s *ManagementStore) ListByClient(ctx context.Context, clientID string) ([]cardholder.Cardholder, error) {
	var out []cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListCardholdersByClient(ctx, clientID)
		if err != nil {
			return err
		}
		out = make([]cardholder.Cardholder, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToCardholder(mapper.CardholderRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *ManagementStore) ListByClients(ctx context.Context, clientIDs []string) ([]cardholder.Cardholder, error) {
	var out []cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListCardholdersByClients(ctx, clientIDs)
		if err != nil {
			return err
		}
		out = make([]cardholder.Cardholder, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToCardholder(mapper.CardholderRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *ManagementStore) GetByID(ctx context.Context, cardholderID string) (*cardholder.Cardholder, error) {
	var result *cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		result, err = s.getCardholderByIDTx(ctx, q, cardholderID)
		return err
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *ManagementStore) Create(ctx context.Context, draft cardholder.Cardholder) (cardholder.Cardholder, error) {
	var result cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		nationality := draft.Nationality
		country := draft.AddressCountry
		row, err := q.CreateCardholder(ctx, sqlcgen.CreateCardholderParams{
			ClientID:             draft.ClientID,
			FullName:             draft.FullName,
			IDDocumentType:       sqlcgen.IDDocumentType(draft.IDDocumentType),
			IDDocumentNumber:     draft.IDDocumentNumber,
			Curp:                 draft.CURP,
			Rfc:                  draft.RFC,
			DateOfBirth:          draft.DateOfBirth,
			Nationality:          &nationality,
			AddressStreet:        draft.AddressStreet,
			AddressNeighborhood:  draft.AddressNeighborhood,
			AddressCity:          draft.AddressCity,
			AddressState:         draft.AddressState,
			AddressPostalCode:    draft.AddressPostalCode,
			AddressCountry:       &country,
			IsPoliticallyExposed: draft.IsPoliticallyExposed,
			Email:                draft.Email,
			Phone:                draft.Phone,
		})
		if err != nil {
			return err
		}
		result = mapper.ToCardholder(mapper.CardholderRow(row))
		return logCallerAudit(ctx, q, "cardholder_created", "cardholder", row.ID, map[string]any{"client_id": row.ClientID, "full_name": row.FullName})
	})
	if err != nil {
		return cardholder.Cardholder{}, err
	}
	return result, nil
}

func (s *ManagementStore) Update(ctx context.Context, updated cardholder.Cardholder) (cardholder.Cardholder, error) {
	var result cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		existing, err := s.getCardholderByIDTx(ctx, q, updated.ID)
		if err != nil {
			return err
		}
		if existing == nil {
			return shared.ErrNotFound
		}
		if !existing.IsActive {
			// A diferencia de Cliente, un Tarjetahabiente inactivo no se
			// puede editar — ver docs/business/desactivacion-de-tarjetahabientes.md.
			return shared.ErrForbidden
		}

		nationality := updated.Nationality
		country := updated.AddressCountry
		row, err := q.UpdateCardholder(ctx, sqlcgen.UpdateCardholderParams{
			ID:                   updated.ID,
			FullName:             updated.FullName,
			IDDocumentType:       sqlcgen.IDDocumentType(updated.IDDocumentType),
			IDDocumentNumber:     updated.IDDocumentNumber,
			Curp:                 updated.CURP,
			Rfc:                  updated.RFC,
			DateOfBirth:          updated.DateOfBirth,
			Nationality:          &nationality,
			AddressStreet:        updated.AddressStreet,
			AddressNeighborhood:  updated.AddressNeighborhood,
			AddressCity:          updated.AddressCity,
			AddressState:         updated.AddressState,
			AddressPostalCode:    updated.AddressPostalCode,
			AddressCountry:       &country,
			IsPoliticallyExposed: updated.IsPoliticallyExposed,
			Email:                updated.Email,
			Phone:                updated.Phone,
		})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		result = mapper.ToCardholder(mapper.CardholderRow(row))
		return logCallerAudit(ctx, q, "cardholder_updated", "cardholder", updated.ID, nil)
	})
	if err != nil {
		return cardholder.Cardholder{}, err
	}
	return result, nil
}

func (s *ManagementStore) SetActive(ctx context.Context, cardholderID string, isActive bool) (cardholder.Cardholder, error) {
	var result cardholder.Cardholder
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.SetCardholderActive(ctx, sqlcgen.SetCardholderActiveParams{ID: cardholderID, IsActive: isActive})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		result = mapper.ToCardholder(mapper.CardholderRow(row))
		action := "cardholder_deactivated"
		if isActive {
			action = "cardholder_reactivated"
		}
		return logCallerAudit(ctx, q, action, "cardholder", cardholderID, nil)
	})
	if err != nil {
		return cardholder.Cardholder{}, err
	}
	return result, nil
}

func (s *ManagementStore) IsOperable(ctx context.Context, cardholderID string) (bool, error) {
	c, err := s.GetByID(ctx, cardholderID)
	if err != nil {
		return false, err
	}
	return c != nil && c.IsActive, nil
}
