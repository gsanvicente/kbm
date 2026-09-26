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

func (s *Store) getClaimTx(ctx context.Context, q *sqlcgen.Queries, ledgerEntryID string) (*ledger.MovementClaim, error) {
	row, err := q.GetClaimByLedgerEntry(ctx, ledgerEntryID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	c := mapper.ToMovementClaim(mapper.MovementClaimRow(row))
	return &c, nil
}

func (s *Store) GetClaim(ctx context.Context, ledgerEntryID string) (*ledger.MovementClaim, error) {
	var result *ledger.MovementClaim
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		result, err = s.getClaimTx(ctx, q, ledgerEntryID)
		return err
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *Store) GetClaimsByLedgerEntries(ctx context.Context, ledgerEntryIDs []string) ([]ledger.MovementClaim, error) {
	if len(ledgerEntryIDs) == 0 {
		return nil, nil
	}
	var out []ledger.MovementClaim
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListClaimsByLedgerEntries(ctx, ledgerEntryIDs)
		if err != nil {
			return err
		}
		out = make([]ledger.MovementClaim, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToMovementClaim(mapper.MovementClaimRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// FileClaim — lanza shared.ErrInvalidState si [ledgerEntryID] ya tiene
// reclamo (relación 1:1, ver docs/business/reclamos-de-movimientos.md).
func (s *Store) FileClaim(ctx context.Context, ledgerEntryID, reason, requestedByEmail string) (ledger.MovementClaim, error) {
	var result ledger.MovementClaim
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		if existing, err := s.getClaimTx(ctx, q, ledgerEntryID); err != nil {
			return err
		} else if existing != nil {
			return shared.ErrInvalidState
		}

		requestedByID, err := q.GetStaffUserIDByEmail(ctx, requestedByEmail)
		if err != nil {
			return err
		}
		clientID, err := q.GetLedgerEntryClientID(ctx, ledgerEntryID)
		if err != nil {
			return err
		}

		row, err := q.InsertClaim(ctx, sqlcgen.InsertClaimParams{
			ClientID:      clientID,
			LedgerEntryID: ledgerEntryID,
			Reason:        reason,
			RequestedBy:   &requestedByID,
		})
		if err != nil {
			return err
		}
		result = ledger.MovementClaim{
			ID:               row.ID,
			LedgerEntryID:    row.LedgerEntryID,
			Reason:           row.Reason,
			Status:           ledger.ClaimStatus(row.Status),
			RequestedByEmail: requestedByEmail,
			CreatedAt:        row.CreatedAt,
		}
		return logCallerAudit(ctx, q, "claim_filed", "movement_claim", row.ID, map[string]any{"ledger_entry_id": ledgerEntryID, "reason": reason})
	})
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	return result, nil
}

// FileClaimAsCardholder — el propio Tarjetahabiente presenta un reclamo
// sobre su propio movimiento (ver
// docs/business/reclamos-de-movimientos.md, "Quién puede presentar un
// reclamo"). El chequeo de pertenencia (¿es realmente su movimiento?) ya
// lo hizo el handler antes de llegar aquí, vía GetEntryCardholderID —
// este método asume que ya se verificó.
func (s *Store) FileClaimAsCardholder(ctx context.Context, ledgerEntryID, reason, cardholderID string) (ledger.MovementClaim, error) {
	var result ledger.MovementClaim
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		if existing, err := s.getClaimTx(ctx, q, ledgerEntryID); err != nil {
			return err
		} else if existing != nil {
			return shared.ErrInvalidState
		}

		clientID, err := q.GetLedgerEntryClientID(ctx, ledgerEntryID)
		if err != nil {
			return err
		}
		cardholderName, err := q.GetCardholderNameByID(ctx, cardholderID)
		if err != nil {
			return err
		}

		row, err := q.InsertClaimAsCardholder(ctx, sqlcgen.InsertClaimAsCardholderParams{
			ClientID:                clientID,
			LedgerEntryID:           ledgerEntryID,
			Reason:                  reason,
			RequestedByCardholderID: &cardholderID,
		})
		if err != nil {
			return err
		}
		result = ledger.MovementClaim{
			ID:               row.ID,
			LedgerEntryID:    row.LedgerEntryID,
			Reason:           row.Reason,
			Status:           ledger.ClaimStatus(row.Status),
			RequestedByEmail: cardholderName,
			CreatedAt:        row.CreatedAt,
		}
		return logCallerAudit(ctx, q, "claim_filed", "movement_claim", row.ID, map[string]any{"ledger_entry_id": ledgerEntryID, "reason": reason})
	})
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	return result, nil
}

// GetEntryCardholderID — a quién pertenece la Cuenta Individual detrás de
// [ledgerEntryID], para el chequeo de pertenencia de los endpoints de
// alcance mixto (getClaim/fileClaim) — mismo patrón que ya usa getLedger
// en handler.go. Toda Cuenta Individual tiene un Tarjetahabiente (ver
// migrations/0009_cuenta_individual.sql: cardholder_id NOT NULL), así que
// el único caso nil es que [ledgerEntryID] no exista, cubierto abajo por
// ErrNotFound.
func (s *Store) GetEntryCardholderID(ctx context.Context, ledgerEntryID string) (*string, error) {
	var result *string
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		cardholderID, err := q.GetLedgerEntryCardholderID(ctx, ledgerEntryID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		result = &cardholderID
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// ResolveClaim — inFavor elige resolved_favor vs rejected. Nunca toca el
// Entry subyacente.
func (s *Store) ResolveClaim(ctx context.Context, claimID string, inFavor bool, resolutionNotes, resolvedByEmail string) (ledger.MovementClaim, error) {
	var result ledger.MovementClaim
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		resolvedByID, err := q.GetStaffUserIDByEmail(ctx, resolvedByEmail)
		if err != nil {
			return err
		}

		status := sqlcgen.ClaimStatusRejected
		if inFavor {
			status = sqlcgen.ClaimStatusResolvedFavor
		}
		if err := q.ResolveClaim(ctx, sqlcgen.ResolveClaimParams{
			ID:              claimID,
			Status:          status,
			ResolvedBy:      &resolvedByID,
			ResolutionNotes: &resolutionNotes,
		}); err != nil {
			return err
		}

		row, err := q.GetClaimByID(ctx, claimID)
		if err != nil {
			return err
		}
		result = mapper.ToMovementClaim(mapper.MovementClaimRow(row))
		return logCallerAudit(ctx, q, "claim_resolved", "movement_claim", claimID, map[string]any{"in_favor": inFavor, "resolved_by_email": resolvedByEmail})
	})
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	return result, nil
}
