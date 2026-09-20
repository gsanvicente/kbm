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

	origin, err := s.GetByID(ctx, originCardID)
	if err != nil {
		return nil, err
	}

	hash := hashPAN(pan)
	row, err := s.q.GetCardByClientAndPANHash(ctx, sqlcgen.GetCardByClientAndPANHashParams{
		ClientID:     origin.ClientID,
		PanHash:      &hash,
		CardholderID: origin.CardholderID,
	})
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	if errors.Is(err, pgx.ErrNoRows) {
		s.attemptsMu.Lock()
		next := s.failedAttempts[cardholderID] + 1
		s.failedAttempts[cardholderID] = next
		s.attemptsMu.Unlock()
		if next >= maxFailedAttempts {
			return nil, shared.ErrTooManyFailedAttempts
		}
		return nil, nil
	}

	match := mapper.ToCard(mapper.CardRow(row))

	name := "Tarjetahabiente" // ver ADR-0010, "Alternativas consideradas": sin onboarding, no siempre hay nombre que mostrar.
	if match.CardholderID != nil {
		if fullName, chErr := s.q.GetCardholderNameByID(ctx, *match.CardholderID); chErr == nil {
			name = fullName
		}
	}

	return &ports.ResolvedTransferDestination{Card: match, CardholderName: name}, nil
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
