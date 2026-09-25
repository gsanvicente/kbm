-- Cuenta Individual del Tarjetahabiente — ver
-- docs/adr/0020-cuenta-individual-tarjetahabiente.md.

-- name: CreateIndividualAccount :one
-- Nace al dar de alta al Tarjetahabiente (ver
-- ManagementStore.Create en cardholder_management.go), no al asignarle
-- una tarjeta. Sin CLABE todavía — se asigna al conectar un proveedor
-- SPEI real, ver docs/adr/0021-conector-spei.md.
INSERT INTO individual_accounts (client_id, cardholder_id)
VALUES ($1, $2)
RETURNING id, client_id, cardholder_id, clabe, created_at;

-- name: GetIndividualAccountByCardholderID :one
SELECT id, client_id, cardholder_id, clabe, created_at
FROM individual_accounts
WHERE cardholder_id = $1;

-- name: GetIndividualAccountByID :one
SELECT id, client_id, cardholder_id, clabe, created_at
FROM individual_accounts
WHERE id = $1;

-- name: GetIndividualAccountByCLABE :one
SELECT id, client_id, cardholder_id, clabe, created_at
FROM individual_accounts
WHERE clabe = $1;

-- name: SetIndividualAccountCLABE :one
UPDATE individual_accounts SET clabe = $2
WHERE id = $1
RETURNING id, client_id, cardholder_id, clabe, created_at;
