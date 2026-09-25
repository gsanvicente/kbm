-- name: GetCardByID :one
SELECT id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at
FROM cards
WHERE id = $1;

-- name: ListCardsByCardholder :many
SELECT id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at
FROM cards
WHERE cardholder_id = $1
ORDER BY id;

-- name: ListCardsByClient :many
SELECT id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at
FROM cards
WHERE client_id = $1
ORDER BY id;

-- name: CountActiveCardsByCardholder :one
SELECT count(*) FROM cards WHERE cardholder_id = $1 AND status = 'active';

-- name: GetClientMaxActiveCards :one
SELECT max_active_cards_per_cardholder FROM client_settings WHERE client_id = $1;

-- name: UpsertClientMaxActiveCards :one
-- $2 en NULL borra el override (vuelve a usar el default de la
-- aplicación) sin eliminar la fila — ver
-- docs/feature/configuracion-de-cliente/README.md.
INSERT INTO client_settings (client_id, max_active_cards_per_cardholder)
VALUES ($1, $2)
ON CONFLICT (client_id) DO UPDATE SET
    max_active_cards_per_cardholder = EXCLUDED.max_active_cards_per_cardholder,
    updated_at = now()
RETURNING client_id, max_active_cards_per_cardholder;

-- name: AssignCardIfAvailable :one
-- account_id ($3) — la Cuenta Individual del Tarjetahabiente destino, ver
-- docs/adr/0020-cuenta-individual-tarjetahabiente.md. Debe existir de
-- antemano (nace al dar de alta al Tarjetahabiente, no aquí).
UPDATE cards
SET cardholder_id = $2, account_id = $3, status = 'active', assigned_at = now(), blocked_reason = NULL, updated_at = now()
WHERE id = $1 AND status = 'unassigned'
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: SetCardBlocked :one
UPDATE cards
SET status = 'blocked', blocked_reason = 'manual', updated_at = now()
WHERE id = $1
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: SetCardUnblocked :one
UPDATE cards
SET status = 'active', blocked_reason = NULL, updated_at = now()
WHERE id = $1
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: SetCardFrozenByOwner :one
UPDATE cards
SET status = 'frozen', updated_at = now()
WHERE id = $1 AND cardholder_id = $2 AND status = 'active'
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: SetCardUnfrozenByOwner :one
UPDATE cards
SET status = 'active', updated_at = now()
WHERE id = $1 AND cardholder_id = $2 AND status = 'frozen'
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: FreezeAllUnblockedCardsForCardholder :exec
UPDATE cards
SET status = 'blocked', blocked_reason = 'cardholder_inactive', updated_at = now()
WHERE cardholder_id = $1 AND status != 'blocked';

-- name: GetCardByClientAndPANHash :one
SELECT id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at
FROM cards
WHERE client_id = $1 AND pan_hash = $2 AND cardholder_id IS DISTINCT FROM $3
LIMIT 1;

-- name: CancelCard :one
-- Terminal, nunca reversible — ver
-- docs/business/tarjetas-y-asignacion.md, "Reemplazo de tarjeta".
UPDATE cards
SET status = 'cancelled', cancelled_reason = $2, updated_at = now()
WHERE id = $1
RETURNING id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at;

-- name: ListAvailableCardsByClient :many
SELECT id, client_id, cardholder_id, account_id, masked_pan, network, expiry_month, expiry_year, status, blocked_reason, cancelled_reason, assigned_at
FROM cards
WHERE client_id = $1 AND status = 'unassigned'
ORDER BY id;
