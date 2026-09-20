-- name: GetStaffUserForLogin :one
SELECT id, client_id, email, password_hash, role, is_active FROM users WHERE email = $1;

-- name: GetStaffUserIDByEmail :one
-- Resuelve el email que admin/ maneja (Session.email) al uuid real que
-- las tablas de Tesorería/Aprobaciones/Reclamos exigen como
-- requested_by/registered_by/etc. — ver
-- docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
SELECT id FROM users WHERE email = $1;
