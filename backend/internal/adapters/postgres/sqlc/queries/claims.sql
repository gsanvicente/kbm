-- name: GetClaimByLedgerEntry :one
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status, rq.email AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.ledger_entry_id = $1;

-- name: ListClaimsByLedgerEntries :many
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status, rq.email AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.ledger_entry_id = ANY(sqlc.arg(ledger_entry_ids)::uuid[]);

-- name: GetClaimByID :one
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status, rq.email AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.id = $1;

-- name: GetLedgerEntryClientID :one
SELECT client_id FROM ledger_entries WHERE id = $1;

-- name: InsertClaim :one
INSERT INTO movement_claims (client_id, ledger_entry_id, reason, requested_by)
VALUES ($1, $2, $3, $4)
RETURNING id, ledger_entry_id, reason, status, requested_by, resolved_by, resolution_notes, created_at, resolved_at;

-- name: ResolveClaim :exec
UPDATE movement_claims
SET status = $2, resolved_by = $3, resolution_notes = $4, resolved_at = now()
WHERE id = $1;
