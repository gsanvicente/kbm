-- name: GetApprovalRule :one
SELECT client_id, operation_type, requires_approval, min_amount, id
FROM approval_rules
WHERE client_id = $1 AND operation_type = $2;

-- name: ListBalanceOperationsByClients :many
SELECT bo.id, bo.client_id, bo.card_id, bo.operation_type, bo.amount, bo.destination_card_id,
       bo.status, rq.email AS requested_by_email, rs.email AS resolved_by_email,
       bo.resolution_notes, bo.created_at, bo.updated_at
FROM balance_operations bo
JOIN users rq ON rq.id = bo.requested_by
LEFT JOIN users rs ON rs.id = bo.resolved_by
WHERE bo.client_id = ANY(sqlc.arg(client_ids)::uuid[])
ORDER BY bo.created_at DESC;

-- name: ListPendingBalanceOperationsByClients :many
SELECT bo.id, bo.client_id, bo.card_id, bo.operation_type, bo.amount, bo.destination_card_id,
       bo.status, rq.email AS requested_by_email, rs.email AS resolved_by_email,
       bo.resolution_notes, bo.created_at, bo.updated_at
FROM balance_operations bo
JOIN users rq ON rq.id = bo.requested_by
LEFT JOIN users rs ON rs.id = bo.resolved_by
WHERE bo.client_id = ANY(sqlc.arg(client_ids)::uuid[]) AND bo.status = 'pending_approval'
ORDER BY bo.created_at DESC;

-- name: GetBalanceOperationForUpdate :one
SELECT bo.id, bo.client_id, bo.card_id, bo.operation_type, bo.amount, bo.destination_card_id,
       bo.status, rq.email AS requested_by_email, rs.email AS resolved_by_email,
       bo.resolution_notes, bo.created_at, bo.updated_at
FROM balance_operations bo
JOIN users rq ON rq.id = bo.requested_by
LEFT JOIN users rs ON rs.id = bo.resolved_by
WHERE bo.id = $1
FOR UPDATE OF bo;

-- name: InsertBalanceOperation :one
INSERT INTO balance_operations (client_id, card_id, operation_type, amount, destination_card_id, status, requested_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, client_id, card_id, operation_type, amount, destination_card_id, status,
          requested_by, resolved_by, resolution_notes, created_at, updated_at;

-- name: UpdateBalanceOperationStatus :exec
UPDATE balance_operations
SET status = $2, resolved_by = $3, resolution_notes = $4, updated_at = now()
WHERE id = $1;

-- name: GetWeeklyOperationVolume :many
-- Volumen real ejecutado por semana/tipo, últimas 12 semanas — reemplaza
-- el dato sintético que admin/'s FakeBalanceOperationRepository generaba
-- (ver docs/feature/panel-directivo/README.md, "Visión futura": esto
-- desaparece en cuanto haya backend real).
SELECT date_trunc('week', created_at)::date AS week_start, operation_type, SUM(amount)::float8 AS total
FROM balance_operations
WHERE client_id = ANY(sqlc.arg(client_ids)::uuid[])
  AND status = 'executed'
  AND created_at >= now() - interval '12 weeks'
GROUP BY week_start, operation_type
ORDER BY week_start;
