package ledger

import "time"

// EntryType mirrors admin/lib/core/models/ledger_entry_type.dart.
type EntryType string

const (
	EntryCredit EntryType = "credit"
	EntryDebit  EntryType = "debit"
)

// Entry es append-only por convención del llamador (internal/adapters/memory
// nunca expone un método para editar o borrar una ya creada) — ver
// docs/business/saldo-y-ledger.md.
type Entry struct {
	ID           string
	CardID       string
	Type         EntryType
	Amount       float64
	BalanceAfter float64
	Description  string
	CreatedAt    time.Time
}

// Account es 1:1 con una Card — a diferencia del esquema real
// (backend/migrations/0001_init.sql, donde ledger_accounts tiene su
// propio id), aquí el CardID hace también de identificador de la cuenta;
// ver docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md. El
// balance se recalcula en cada Entry nueva, nunca se guarda de forma
// independiente a las entradas que lo componen.
type Account struct {
	CardID   string
	Balance  float64
	Currency string
}
