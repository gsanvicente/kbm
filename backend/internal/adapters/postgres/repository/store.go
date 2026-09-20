// Package repository implements the application layer's Card/Ledger/
// Cardholder-login/Transfer ports against a real Postgres database, via
// pgx + sqlc — see docs/tdr/0001-sqlc-pgx-over-orm.md and
// docs/adr/0011-processor-integration-architecture-and-postgres-default.md.
// Same four ports as internal/adapters/memory/repository.Store
// (CardRepository, LedgerRepository, CardholderAuthRepository,
// TransferService), and the same "one Store implements every port"
// rationale — see that package's doc comment.
package repository

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
)

// devOnlyHMACKey — mismo valor que
// internal/adapters/memory/repository/transfer.go, solo para que ambos
// adaptadores hasheen el mismo universo de PANes sintéticos de forma
// consistente en el demo (ver scripts/init-db/001_seed.sql). Nunca
// hardcodear esto en un backend real — ver
// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md, punto 3.
var devOnlyHMACKey = []byte("kbm-backend-fake-pan-hmac-key-dev-only")

func hashPAN(pan string) string {
	mac := hmac.New(sha256.New, devOnlyHMACKey)
	mac.Write([]byte(pan))
	return hex.EncodeToString(mac.Sum(nil))
}

const maxFailedAttempts = 5

// Store — el límite de intentos fallidos de una transferencia C2C es un
// throttle de sesión, no un dato de negocio (ver
// docs/security/threat-model.md punto 12): se mantiene en memoria de
// proceso igual que en el adaptador en memoria, incluso aquí — no hay
// necesidad real de que sobreviva un reinicio del backend.
type Store struct {
	pool *pgxpool.Pool
	q    *sqlcgen.Queries

	attemptsMu     sync.Mutex
	failedAttempts map[string]int
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{
		pool:           pool,
		q:              sqlcgen.New(pool),
		failedAttempts: map[string]int{},
	}
}

func (s *Store) Close() {
	s.pool.Close()
}
