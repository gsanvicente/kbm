package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/application/ports"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// ResolveDestination — ver
// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Flujo
// principal" y "Seguridad", y
// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md. El PAN recibido en
// [pan] vive solo en esta llamada — nunca se persiste ni se loguea. Sin
// filtro de status a propósito, igual que
// internal/adapters/memory/repository/transfer.go: una tarjeta
// bloqueada/congelada que calce por PAN sigue siendo "encontrada" aquí —
// comportamiento heredado del adaptador en memoria, no una decisión nueva
// de este adaptador.
func (s *Store) ResolveDestination(ctx context.Context, cardholderID, originCardID, pan string) (*ports.ResolvedTransferDestination, error) {
	s.attemptsMu.Lock()
	tooMany := s.failedAttempts[cardholderID] >= maxFailedAttempts
	s.attemptsMu.Unlock()
	if tooMany {
		return nil, shared.ErrTooManyFailedAttempts
	}

	var result *ports.ResolvedTransferDestination
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		origin, err := s.getByIDTx(ctx, q, originCardID)
		if err != nil {
			return err
		}

		hash := hashPAN(pan)
		row, err := q.GetCardByClientAndPANHash(ctx, sqlcgen.GetCardByClientAndPANHashParams{
			ClientID:     origin.ClientID,
			PanHash:      &hash,
			CardholderID: origin.CardholderID,
		})
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}

		if errors.Is(err, pgx.ErrNoRows) {
			s.attemptsMu.Lock()
			next := s.failedAttempts[cardholderID] + 1
			s.failedAttempts[cardholderID] = next
			s.attemptsMu.Unlock()
			if next >= maxFailedAttempts {
				return shared.ErrTooManyFailedAttempts
			}
			return nil
		}

		match := mapper.ToCard(mapper.CardRow(row))

		name := "Tarjetahabiente" // ver ADR-0010, "Alternativas consideradas": sin onboarding, no siempre hay nombre que mostrar.
		if match.CardholderID != nil {
			if fullName, chErr := q.GetCardholderNameByID(ctx, *match.CardholderID); chErr == nil {
				name = fullName
			}
		}

		result = &ports.ResolvedTransferDestination{Card: match, CardholderName: name}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Execute — débito inmediato en origen, crédito inmediato en destino,
// nunca a medias (ver docs/business/saldo-y-ledger.md). Dos llamadas
// independientes a PostEntry, cada una con su propia transacción — mismo
// criterio que internal/adapters/memory/repository/transfer.go.
func (s *Store) Execute(ctx context.Context, originCardID, destinationCardID string, amount float64) error {
	if _, err := s.PostEntry(ctx, originCardID, ledger.EntryDebit, amount, "Transferencia enviada"); err != nil {
		return err
	}
	if _, err := s.PostEntry(ctx, destinationCardID, ledger.EntryCredit, amount, "Transferencia recibida"); err != nil {
		return err
	}
	return nil
}
