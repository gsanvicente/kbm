-- requested_by_email en los tres SELECT de abajo es en realidad "quién
-- lo presentó, para mostrar en pantalla" — un email de staff o el
-- nombre completo de un Tarjetahabiente (COALESCE), nunca ambos a la
-- vez (ver movement_claims_requester_check en
-- migrations/0007_cardholder_filed_claims.sql). El nombre de la columna
-- se mantuvo para no tocar el resto del código Go — "Solicitado por" ya
-- era una etiqueta genérica en admin/, nunca decía literalmente "email".

-- name: GetClaimByLedgerEntry :one
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status,
       COALESCE(rq.email::text, ch.full_name) AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
LEFT JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN cardholders ch ON ch.id = mc.requested_by_cardholder_id
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.ledger_entry_id = $1;

-- name: ListClaimsByLedgerEntries :many
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status,
       COALESCE(rq.email::text, ch.full_name) AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
LEFT JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN cardholders ch ON ch.id = mc.requested_by_cardholder_id
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.ledger_entry_id = ANY(sqlc.arg(ledger_entry_ids)::uuid[]);

-- name: GetClaimByID :one
SELECT mc.id, mc.ledger_entry_id, mc.reason, mc.status,
       COALESCE(rq.email::text, ch.full_name) AS requested_by_email,
       rs.email AS resolved_by_email, mc.resolution_notes, mc.created_at, mc.resolved_at
FROM movement_claims mc
LEFT JOIN users rq ON rq.id = mc.requested_by
LEFT JOIN cardholders ch ON ch.id = mc.requested_by_cardholder_id
LEFT JOIN users rs ON rs.id = mc.resolved_by
WHERE mc.id = $1;

-- name: GetLedgerEntryClientID :one
SELECT client_id FROM ledger_entries WHERE id = $1;

-- name: GetLedgerEntryCardholderID :one
-- Para el chequeo de pertenencia cuando quien pide/reclama es un
-- Tarjetahabiente (getClaim/fileClaim de alcance mixto) — mismo patrón
-- que ya usa getLedger en handler.go.
SELECT c.cardholder_id
FROM ledger_entries le
JOIN ledger_accounts la ON la.id = le.ledger_account_id
JOIN cards c ON c.id = la.card_id
WHERE le.id = $1;

-- name: InsertClaim :one
INSERT INTO movement_claims (client_id, ledger_entry_id, reason, requested_by)
VALUES ($1, $2, $3, $4)
RETURNING id, ledger_entry_id, reason, status, requested_by, resolved_by, resolution_notes, created_at, resolved_at;

-- name: InsertClaimAsCardholder :one
INSERT INTO movement_claims (client_id, ledger_entry_id, reason, requested_by_cardholder_id)
VALUES ($1, $2, $3, $4)
RETURNING id, ledger_entry_id, reason, status, requested_by_cardholder_id, resolved_by, resolution_notes, created_at, resolved_at;

-- name: ResolveClaim :exec
UPDATE movement_claims
SET status = $2, resolved_by = $3, resolution_notes = $4, resolved_at = now()
WHERE id = $1;
