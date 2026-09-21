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

func (s *Store) GetClaim(ctx context.Context, ledgerEntryID string) (*ledger.MovementClaim, error) {
	row, err := s.q.GetClaimByLedgerEntry(ctx, ledgerEntryID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	c := mapper.ToMovementClaim(mapper.MovementClaimRow(row))
	return &c, nil
}

func (s *Store) GetClaimsByLedgerEntries(ctx context.Context, ledgerEntryIDs []string) ([]ledger.MovementClaim, error) {
	if len(ledgerEntryIDs) == 0 {
		return nil, nil
	}
	rows, err := s.q.ListClaimsByLedgerEntries(ctx, ledgerEntryIDs)
	if err != nil {
		return nil, err
	}
	out := make([]ledger.MovementClaim, 0, len(rows))
	for _, r := range rows {
		out = append(out, mapper.ToMovementClaim(mapper.MovementClaimRow(r)))
	}
	return out, nil
}

// FileClaim — lanza shared.ErrInvalidState si [ledgerEntryID] ya tiene
// reclamo (relación 1:1, ver docs/business/reclamos-de-movimientos.md).
func (s *Store) FileClaim(ctx context.Context, ledgerEntryID, reason, requestedByEmail string) (ledger.MovementClaim, error) {
	if existing, err := s.GetClaim(ctx, ledgerEntryID); err != nil {
		return ledger.MovementClaim{}, err
	} else if existing != nil {
		return ledger.MovementClaim{}, shared.ErrInvalidState
	}

	requestedByID, err := s.q.GetStaffUserIDByEmail(ctx, requestedByEmail)
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	clientID, err := s.q.GetLedgerEntryClientID(ctx, ledgerEntryID)
	if err != nil {
		return ledger.MovementClaim{}, err
	}

	row, err := s.q.InsertClaim(ctx, sqlcgen.InsertClaimParams{
		ClientID:      clientID,
		LedgerEntryID: ledgerEntryID,
		Reason:        reason,
		RequestedBy:   requestedByID,
	})
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	return ledger.MovementClaim{
		ID:               row.ID,
		LedgerEntryID:    row.LedgerEntryID,
		Reason:           row.Reason,
		Status:           ledger.ClaimStatus(row.Status),
		RequestedByEmail: requestedByEmail,
		CreatedAt:        row.CreatedAt,
	}, nil
}

// ResolveClaim — inFavor elige resolved_favor vs rejected. Nunca toca el
// Entry subyacente.
func (s *Store) ResolveClaim(ctx context.Context, claimID string, inFavor bool, resolutionNotes, resolvedByEmail string) (ledger.MovementClaim, error) {
	resolvedByID, err := s.q.GetStaffUserIDByEmail(ctx, resolvedByEmail)
	if err != nil {
		return ledger.MovementClaim{}, err
	}

	status := sqlcgen.ClaimStatusRejected
	if inFavor {
		status = sqlcgen.ClaimStatusResolvedFavor
	}
	if err := s.q.ResolveClaim(ctx, sqlcgen.ResolveClaimParams{
		ID:              claimID,
		Status:          status,
		ResolvedBy:      &resolvedByID,
		ResolutionNotes: &resolutionNotes,
	}); err != nil {
		return ledger.MovementClaim{}, err
	}

	row, err := s.q.GetClaimByID(ctx, claimID)
	if err != nil {
		return ledger.MovementClaim{}, err
	}
	return mapper.ToMovementClaim(mapper.MovementClaimRow(row)), nil
}
