-- name: GetCardholderForLogin :one
SELECT ch.id, ch.client_id, ch.full_name, ch.email, ch.is_active, cu.password_hash
FROM cardholder_users cu
JOIN cardholders ch ON ch.id = cu.cardholder_id
WHERE cu.email = $1;

-- name: GetCardholderForActivation :one
SELECT id, client_id, full_name, id_document_number, is_active, activation_failed_attempts
FROM cardholders
WHERE email = $1;

-- name: IncrementActivationFailedAttempts :exec
UPDATE cardholders SET activation_failed_attempts = activation_failed_attempts + 1
WHERE id = $1;

-- name: ResetActivationAttempts :one
UPDATE cardholders SET activation_failed_attempts = 0, updated_at = now()
WHERE id = $1
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          date_of_birth, nationality, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country, is_politically_exposed,
          email, phone, is_active;

-- name: HasCardholderUser :one
SELECT EXISTS (SELECT 1 FROM cardholder_users WHERE cardholder_id = $1);

-- name: CreateCardholderUser :one
INSERT INTO cardholder_users (cardholder_id, email, password_hash)
VALUES ($1, $2, $3)
RETURNING id;

-- name: GetCardholderNameByID :one
SELECT full_name FROM cardholders WHERE id = $1;

-- name: ListCardholdersByClient :many
SELECT id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
       date_of_birth, nationality, address_street, address_neighborhood, address_city,
       address_state, address_postal_code, address_country, is_politically_exposed,
       email, phone, is_active
FROM cardholders
WHERE client_id = $1
ORDER BY full_name;

-- name: ListCardholdersByClients :many
SELECT id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
       date_of_birth, nationality, address_street, address_neighborhood, address_city,
       address_state, address_postal_code, address_country, is_politically_exposed,
       email, phone, is_active
FROM cardholders
WHERE client_id = ANY(sqlc.arg(client_ids)::uuid[])
ORDER BY full_name;

-- name: GetCardholderByID :one
SELECT id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
       date_of_birth, nationality, address_street, address_neighborhood, address_city,
       address_state, address_postal_code, address_country, is_politically_exposed,
       email, phone, is_active
FROM cardholders
WHERE id = $1;

-- name: CreateCardholder :one
INSERT INTO cardholders (
    client_id, full_name, id_document_type, id_document_number, curp, rfc,
    date_of_birth, nationality, address_street, address_neighborhood, address_city,
    address_state, address_postal_code, address_country, is_politically_exposed,
    email, phone
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
)
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          date_of_birth, nationality, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country, is_politically_exposed,
          email, phone, is_active;

-- name: UpdateCardholder :one
UPDATE cardholders SET
    full_name = $2, id_document_type = $3, id_document_number = $4, curp = $5, rfc = $6,
    date_of_birth = $7, nationality = $8, address_street = $9, address_neighborhood = $10,
    address_city = $11, address_state = $12, address_postal_code = $13, address_country = $14,
    is_politically_exposed = $15, email = $16, phone = $17, updated_at = now()
WHERE id = $1
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          date_of_birth, nationality, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country, is_politically_exposed,
          email, phone, is_active;

-- name: SetCardholderActive :one
UPDATE cardholders SET is_active = $2, updated_at = now()
WHERE id = $1
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          date_of_birth, nationality, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country, is_politically_exposed,
          email, phone, is_active;
