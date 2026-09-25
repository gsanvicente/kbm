-- GetLedgerAccountByCardID/ForUpdate — el ledger vive en la Cuenta
-- Individual desde docs/adr/0020-cuenta-individual-tarjetahabiente.md,
-- no en la tarjeta; se llega a él vía cards.account_id. La firma (recibe
-- un cardID) no cambió a propósito — todo el código Go que llama a estas
-- dos queries sigue igual, ver internal/adapters/postgres/repository/ledger.go.
-- name: GetLedgerAccountByCardID :one
SELECT la.id, la.client_id, la.account_id, la.currency
FROM ledger_accounts la
JOIN cards c ON c.account_id = la.account_id
WHERE c.id = $1;

-- name: GetLedgerAccountByCardIDForUpdate :one
SELECT la.id, la.client_id, la.account_id, la.currency
FROM ledger_accounts la
JOIN cards c ON c.account_id = la.account_id
WHERE c.id = $1
FOR UPDATE;

-- name: CreateLedgerAccount :one
INSERT INTO ledger_accounts (client_id, account_id, currency) VALUES ($1, $2, $3)
RETURNING id, client_id, account_id, currency;

-- name: GetLedgerAccountByAccountID :one
SELECT id, client_id, account_id, currency FROM ledger_accounts WHERE account_id = $1;

-- name: GetLedgerAccountByAccountIDForUpdate :one
-- Mismo propósito que GetLedgerAccountByCardIDForUpdate — bloquea la fila
-- para serializar movimientos concurrentes sobre la misma Cuenta
-- Individual. Usado por pagos/depósitos SPEI, que se dirigen a la Cuenta
-- directamente, no a través de una tarjeta (ver
-- internal/adapters/postgres/repository/spei.go).
SELECT id, client_id, account_id, currency FROM ledger_accounts WHERE account_id = $1
FOR UPDATE;

-- name: ListLedgerEntriesByAccountID :many
SELECT id, client_id, ledger_account_id, entry_type, amount, balance_after, description, created_at
FROM ledger_entries
WHERE ledger_account_id = $1
ORDER BY created_at DESC;

-- name: GetLatestLedgerBalance :one
SELECT balance_after FROM ledger_entries
WHERE ledger_account_id = $1
ORDER BY created_at DESC, id DESC
LIMIT 1;

-- name: InsertLedgerEntry :one
INSERT INTO ledger_entries (client_id, ledger_account_id, entry_type, amount, balance_after, description)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, client_id, ledger_account_id, entry_type, amount, balance_after, description, created_at;
