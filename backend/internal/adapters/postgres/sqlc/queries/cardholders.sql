-- name: GetCardholderForLogin :one
SELECT ch.id, ch.client_id, ch.full_name, ch.email, ch.is_active, cu.password_hash
FROM cardholder_users cu
JOIN cardholders ch ON ch.id = cu.cardholder_id
WHERE cu.email = $1;

-- name: GetCardholderNameByID :one
SELECT full_name FROM cardholders WHERE id = $1;
