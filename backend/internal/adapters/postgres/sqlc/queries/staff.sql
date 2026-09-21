-- name: GetStaffUserForLogin :one
SELECT id, client_id, email, full_name, password_hash, role, is_active FROM users WHERE email = $1;

-- name: GetStaffUserIDByEmail :one
-- Resuelve el email que admin/ maneja (Session.email) al uuid real que
-- las tablas de Tesorería/Aprobaciones/Reclamos exigen como
-- requested_by/registered_by/etc. — ver
-- docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
SELECT id FROM users WHERE email = $1;

-- name: ListStaffUsersByClient :many
-- Ver docs/adr/0017-staff-user-management-and-rls-on-users.md. Nunca
-- incluye Super Admin (client_id IS NULL) — no tiene sentido listarlo
-- "dentro" de ningún Cliente.
SELECT id, client_id, email, full_name, role, is_active FROM users
WHERE client_id = $1
ORDER BY full_name;

-- name: GetStaffUserByID :one
SELECT id, client_id, email, full_name, role, is_active FROM users WHERE id = $1;

-- name: CreateStaffUser :one
INSERT INTO users (client_id, email, full_name, password_hash, role)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, client_id, email, full_name, role, is_active;

-- name: UpdateStaffUser :one
-- email y client_id nunca cambian aquí — ver
-- docs/business/gestion-de-usuarios-staff.md, "Qué se puede editar".
UPDATE users SET full_name = $2, role = $3, updated_at = now()
WHERE id = $1
RETURNING id, client_id, email, full_name, role, is_active;

-- name: SetStaffUserActive :one
UPDATE users SET is_active = $2, updated_at = now()
WHERE id = $1
RETURNING id, client_id, email, full_name, role, is_active;

-- name: ResetStaffUserPassword :exec
UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1;
