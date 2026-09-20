-- name: GetLedgerAccountByCardID :one
SELECT id, client_id, card_id, currency FROM ledger_accounts WHERE card_id = $1;

-- name: GetLedgerAccountByCardIDForUpdate :one
SELECT id, client_id, card_id, currency FROM ledger_accounts WHERE card_id = $1 FOR UPDATE;

-- name: CreateLedgerAccount :one
INSERT INTO ledger_accounts (client_id, card_id, currency) VALUES ($1, $2, $3)
RETURNING id, client_id, card_id, currency;

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
