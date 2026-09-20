-- name: GetConcentratorAccountByClient :one
SELECT id, client_id, currency FROM concentrator_accounts WHERE client_id = $1;

-- name: LockConcentratorAccount :exec
SELECT id FROM concentrator_accounts WHERE id = $1 FOR UPDATE;

-- name: CreateConcentratorAccount :one
-- ON CONFLICT hace esto get-or-create — llamarlo dos veces para el mismo
-- Cliente (p.ej. una vez desde el server al crear el Cliente, otra desde
-- admin/ por compatibilidad con el flujo ya existente) nunca falla ni
-- duplica. Ver docs/business/tesoreria-cliente.md.
INSERT INTO concentrator_accounts (client_id, currency) VALUES ($1, 'MXN')
ON CONFLICT (client_id) DO UPDATE SET client_id = EXCLUDED.client_id
RETURNING id, client_id, currency;

-- name: GetLatestConcentratorBalance :one
SELECT balance_after FROM concentrator_entries
WHERE concentrator_account_id = $1
ORDER BY created_at DESC, id DESC
LIMIT 1;

-- name: ListConcentratorEntries :many
SELECT id, concentrator_account_id, entry_type, amount, balance_after, description, created_at
FROM concentrator_entries
WHERE concentrator_account_id = $1
ORDER BY created_at DESC;

-- name: InsertConcentratorEntry :one
INSERT INTO concentrator_entries (concentrator_account_id, entry_type, amount, balance_after, description)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, concentrator_account_id, entry_type, amount, balance_after, description, created_at;

-- name: ListCollectorDepositsByClient :many
SELECT cd.id, cd.client_id, cd.amount, cd.reference, cd.status,
       ru.email AS registered_by_email, rcu.email AS reconciled_by_email,
       cd.created_at, cd.reconciled_at
FROM collector_deposits cd
JOIN users ru ON ru.id = cd.registered_by
LEFT JOIN users rcu ON rcu.id = cd.reconciled_by
WHERE cd.client_id = $1
ORDER BY cd.created_at DESC;

-- name: GetCollectorDepositForUpdate :one
SELECT cd.id, cd.client_id, cd.amount, cd.reference, cd.status,
       ru.email AS registered_by_email, rcu.email AS reconciled_by_email,
       cd.created_at, cd.reconciled_at
FROM collector_deposits cd
JOIN users ru ON ru.id = cd.registered_by
LEFT JOIN users rcu ON rcu.id = cd.reconciled_by
WHERE cd.id = $1
FOR UPDATE OF cd;

-- name: InsertCollectorDeposit :one
INSERT INTO collector_deposits (client_id, amount, reference, registered_by)
VALUES ($1, $2, $3, $4)
RETURNING id, client_id, amount, reference, status, registered_by, reconciled_by, created_at, reconciled_at;

-- name: ReconcileCollectorDeposit :exec
UPDATE collector_deposits SET status = 'reconciled', reconciled_by = $2, reconciled_at = now()
WHERE id = $1;
