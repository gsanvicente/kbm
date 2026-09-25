-- Conector SPEI — ver docs/adr/0021-conector-spei.md.

-- name: CreateBeneficiary :one
INSERT INTO payment_beneficiaries (client_id, cardholder_id, alias, clabe, bank_name)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, client_id, cardholder_id, alias, clabe, bank_name, cooling_until, created_at;

-- name: ListBeneficiariesByCardholder :many
SELECT id, client_id, cardholder_id, alias, clabe, bank_name, cooling_until, created_at
FROM payment_beneficiaries
WHERE cardholder_id = $1
ORDER BY alias;

-- name: GetBeneficiaryByID :one
SELECT id, client_id, cardholder_id, alias, clabe, bank_name, cooling_until, created_at
FROM payment_beneficiaries
WHERE id = $1;

-- name: CreateSPEIPayment :one
INSERT INTO spei_payments (client_id, account_id, beneficiary_id, amount, status, requested_by_cardholder_id)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, client_id, account_id, beneficiary_id, amount, status, requested_by_cardholder_id,
          resolved_by, resolution_notes, provider_reference, created_at, updated_at;

-- name: GetSPEIPaymentForUpdate :one
SELECT id, client_id, account_id, beneficiary_id, amount, status, requested_by_cardholder_id,
       resolved_by, resolution_notes, provider_reference, created_at, updated_at
FROM spei_payments
WHERE id = $1
FOR UPDATE;

-- name: UpdateSPEIPaymentStatus :exec
UPDATE spei_payments
SET status = $2, resolved_by = $3, resolution_notes = $4, provider_reference = $5, updated_at = now()
WHERE id = $1;

-- name: ListSPEIPaymentsByAccount :many
SELECT sp.id, sp.client_id, sp.account_id, sp.beneficiary_id, sp.amount, sp.status,
       sp.requested_by_cardholder_id, u.email AS resolved_by_email, sp.resolution_notes,
       sp.provider_reference, sp.created_at, sp.updated_at,
       pb.alias AS beneficiary_alias, pb.clabe AS beneficiary_clabe
FROM spei_payments sp
JOIN payment_beneficiaries pb ON pb.id = sp.beneficiary_id
LEFT JOIN users u ON u.id = sp.resolved_by
WHERE sp.account_id = $1
ORDER BY sp.created_at DESC;

-- name: ListPendingSPEIPaymentsByClients :many
SELECT sp.id, sp.client_id, sp.account_id, sp.beneficiary_id, sp.amount, sp.status,
       sp.requested_by_cardholder_id, u.email AS resolved_by_email, sp.resolution_notes,
       sp.provider_reference, sp.created_at, sp.updated_at,
       pb.alias AS beneficiary_alias, pb.clabe AS beneficiary_clabe,
       ch.full_name AS requested_by_full_name
FROM spei_payments sp
JOIN payment_beneficiaries pb ON pb.id = sp.beneficiary_id
JOIN cardholders ch ON ch.id = sp.requested_by_cardholder_id
LEFT JOIN users u ON u.id = sp.resolved_by
WHERE sp.client_id = ANY(sqlc.arg(client_ids)::uuid[]) AND sp.status = 'pending_approval'
ORDER BY sp.created_at;

-- name: ListSPEIPaymentsByClients :many
-- Historial completo (cualquier estatus) para el reporte de staff — ver
-- docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. A
-- diferencia de ListPendingSPEIPaymentsByClients, nunca filtra por
-- status.
SELECT sp.id, sp.client_id, sp.account_id, sp.beneficiary_id, sp.amount, sp.status,
       sp.requested_by_cardholder_id, u.email AS resolved_by_email, sp.resolution_notes,
       sp.provider_reference, sp.created_at, sp.updated_at,
       pb.alias AS beneficiary_alias, pb.clabe AS beneficiary_clabe,
       ch.full_name AS requested_by_full_name
FROM spei_payments sp
JOIN payment_beneficiaries pb ON pb.id = sp.beneficiary_id
JOIN cardholders ch ON ch.id = sp.requested_by_cardholder_id
LEFT JOIN users u ON u.id = sp.resolved_by
WHERE sp.client_id = ANY(sqlc.arg(client_ids)::uuid[])
ORDER BY sp.created_at DESC;

-- name: ListSPEIDepositsByClients :many
-- Reporte de depósitos SPEI cross-cliente para staff — ver
-- docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. Distinto
-- de ListSPEIDepositsByAccount (self-only, un Tarjetahabiente).
SELECT sd.id, sd.client_id, sd.account_id, sd.amount, sd.provider_reference, sd.created_at,
       ch.full_name AS cardholder_full_name
FROM spei_deposits sd
JOIN individual_accounts ia ON ia.id = sd.account_id
JOIN cardholders ch ON ch.id = ia.cardholder_id
WHERE sd.client_id = ANY(sqlc.arg(client_ids)::uuid[])
ORDER BY sd.created_at DESC;

-- name: ListBeneficiariesByClients :many
-- Directorio agregado de Beneficiarios de Pago para staff — ver
-- docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, puntos 2 y
-- 3. payment_count/total_amount cuentan solo pagos 'executed' — dinero
-- que de verdad salió, nunca intentos pending/rejected/failed.
SELECT pb.id, pb.client_id, pb.cardholder_id, pb.alias, pb.clabe, pb.bank_name,
       pb.cooling_until, pb.created_at,
       ch.full_name AS cardholder_full_name,
       COALESCE(pay.payment_count, 0)::bigint AS payment_count,
       COALESCE(pay.total_amount, 0)::numeric AS total_amount
FROM payment_beneficiaries pb
JOIN cardholders ch ON ch.id = pb.cardholder_id
LEFT JOIN (
    SELECT beneficiary_id, count(*) AS payment_count, sum(amount) AS total_amount
    FROM spei_payments
    WHERE status = 'executed'
    GROUP BY beneficiary_id
) pay ON pay.beneficiary_id = pb.id
WHERE pb.client_id = ANY(sqlc.arg(client_ids)::uuid[])
ORDER BY pb.alias;

-- name: CountCardholdersByClabes :many
-- Corre SIN el filtro normal de client_ids/RLS a propósito (llamar con
-- withRLSBypass) — la bandera de "esta CLABE también la registró otro
-- Tarjetahabiente" debe cruzar tenants para tener sentido como señal de
-- posible cuenta mula. Nunca devuelve nada más que la CLABE y el conteo
-- — ver docs/security/threat-model.md punto 18.
SELECT clabe, count(DISTINCT cardholder_id)::bigint AS cardholder_count
FROM payment_beneficiaries
WHERE clabe = ANY(sqlc.arg(clabes)::text[])
GROUP BY clabe
HAVING count(DISTINCT cardholder_id) > 1;

-- name: ListSPEIDepositsByAccount :many
-- Para el comprobante propio de un depósito (ADR-0021, punto 9) y el
-- "Reportes y consultas: Depósitos" del documento de referencia —
-- ver internal/adapters/postgres/repository/spei.go, ListDeposits.
SELECT id, client_id, account_id, amount, provider_reference, created_at
FROM spei_deposits
WHERE account_id = $1
ORDER BY created_at DESC;

-- name: GetSPEIDepositByProviderReference :one
SELECT id, client_id, account_id, amount, provider_reference, created_at
FROM spei_deposits
WHERE provider_reference = $1;

-- name: CreateSPEIDeposit :one
-- ON CONFLICT DO NOTHING + cero filas devueltas es la señal de
-- idempotencia: ese provider_reference ya se procesó antes, ver
-- internal/adapters/postgres/repository/spei.go HandleDeposit.
INSERT INTO spei_deposits (client_id, account_id, amount, provider_reference)
VALUES ($1, $2, $3, $4)
ON CONFLICT (provider_reference) DO NOTHING
RETURNING id, client_id, account_id, amount, provider_reference, created_at;
