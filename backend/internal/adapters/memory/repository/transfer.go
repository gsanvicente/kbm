package repository

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"

	"github.com/koons/kbm/backend/internal/application/ports"
	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// devOnlyHMACKey simula la llave secreta que en un backend real viviría
// en un almacén de secretos (internal/platform/config), nunca
// hardcodeada — ver docs/adr/0009-pan-hash-transit-for-c2c-transfers.md,
// punto 3, y docs/tdr/0003-in-memory-repository-adapter.md.
var devOnlyHMACKey = []byte("kbm-backend-fake-pan-hmac-key-dev-only")

func hashPAN(pan string) string {
	mac := hmac.New(sha256.New, devOnlyHMACKey)
	mac.Write([]byte(pan))
	return hex.EncodeToString(mac.Sum(nil))
}

// ResolveDestination — ver
// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Flujo
// principal" y "Seguridad". El PAN recibido en [pan] vive solo en esta
// llamada — nunca se persiste ni se loguea, ver ADR-0009.
func (s *Store) ResolveDestination(ctx context.Context, cardholderID, originCardID, pan string) (*ports.ResolvedTransferDestination, error) {
	s.attemptsMu.Lock()
	if s.failedAttempts[cardholderID] >= maxFailedAttempts {
		s.attemptsMu.Unlock()
		return nil, shared.ErrTooManyFailedAttempts
	}
	s.attemptsMu.Unlock()

	origin, err := s.GetByID(ctx, originCardID)
	if err != nil {
		return nil, err
	}

	hash := hashPAN(pan)
	var match *card.Card
	s.cardsMu.RLock()
	for _, c := range s.cards {
		if c.ClientID != origin.ClientID {
			continue // fuera de alcance, ver ADR-0009 punto 5
		}
		if c.CardholderID == nil || origin.CardholderID == nil || *c.CardholderID == *origin.CardholderID {
			continue // "otro" Tarjetahabiente, no uno mismo
		}
		if s.panHashByCardID[c.ID] != hash {
			continue
		}
		found := c
		match = &found
		break
	}
	s.cardsMu.RUnlock()

	if match == nil {
		s.attemptsMu.Lock()
		next := s.failedAttempts[cardholderID] + 1
		s.failedAttempts[cardholderID] = next
		s.attemptsMu.Unlock()
		// El propio intento que llega al límite ya informa el bloqueo —
		// ver cardholder/lib/core/fake_backend.dart, mismo criterio.
		if next >= maxFailedAttempts {
			return nil, shared.ErrTooManyFailedAttempts
		}
		return nil, nil
	}

	s.cardholdersMu.RLock()
	name := "Tarjetahabiente" // ver "Alternativas consideradas" en ADR-0010: sin registro de onboarding, no siempre hay un nombre que mostrar
	if ch, ok := s.cardholders[*match.CardholderID]; ok {
		name = ch.FullName
	}
	s.cardholdersMu.RUnlock()

	return &ports.ResolvedTransferDestination{Card: *match, CardholderName: name}, nil
}

// Execute — débito inmediato en origen, crédito inmediato en destino,
// nunca a medias (ver docs/business/saldo-y-ledger.md).
func (s *Store) Execute(ctx context.Context, originCardID, destinationCardID string, amount float64) error {
	if _, err := s.PostEntry(ctx, originCardID, ledger.EntryDebit, amount, "Transferencia enviada"); err != nil {
		return err
	}
	if _, err := s.PostEntry(ctx, destinationCardID, ledger.EntryCredit, amount, "Transferencia recibida"); err != nil {
		return err
	}
	return nil
}
