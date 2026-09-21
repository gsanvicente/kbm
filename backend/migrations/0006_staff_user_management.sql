-- Gestión de usuarios de staff — ver
-- docs/adr/0017-staff-user-management-and-rls-on-users.md. Hasta esta
-- migración, `users` no tenía ni nombre ni RLS: los únicos usuarios
-- existían por seed, nunca por una pantalla de alta.

-- full_name — igual criterio que clients/cardholders: identificar a la
-- persona real detrás de la cuenta. `scripts/init-db/001_seed.sql` ya
-- provee full_name en su propio INSERT (para una base nueva, donde esta
-- migración corre ANTES que el seed) — los UPDATE de abajo solo importan
-- para una base ya existente que se actualiza incrementalmente (como se
-- aplicó aquí en vivo, sin recrear el contenedor).
ALTER TABLE users ADD COLUMN full_name text;
UPDATE users SET full_name = 'Super Admin' WHERE email = 'super.admin@koons.test';
UPDATE users SET full_name = 'Admin Holding' WHERE email = 'admin.holding@koons.test';
UPDATE users SET full_name = 'Admin Subsidiaria A' WHERE email = 'admin.subA@koons.test';
UPDATE users SET full_name = 'Operador Subsidiaria A' WHERE email = 'operador.subA@koons.test';
UPDATE users SET full_name = 'Auditor Subsidiaria A' WHERE email = 'auditor.subA@koons.test';
-- Cualquier otro usuario de staff que ya exista en un ambiente real y no
-- calce con el seed de desarrollo: backfill genérico a partir del email,
-- para que la columna pueda volverse NOT NULL sin fallar.
UPDATE users SET full_name = split_part(email::text, '@', 1) WHERE full_name IS NULL;
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

-- RLS — `users` se quedó fuera de la lista original de
-- migrations/0001_init.sql porque el login necesita leerla sin ninguna
-- identidad de llamador todavía (ver
-- docs/adr/0014-row-level-security-policies.md). Con la gestión de
-- usuarios de staff (crear/listar/editar) esa misma tabla ya necesita el
-- mismo aislamiento por tenant que cardholders — sin esto, un Admin
-- Cliente podría listar o crear usuarios de cualquier empresa con solo
-- cambiar el client_id en el request, ya que nada más lo impediría a
-- nivel de base de datos. app_client_accessible ya maneja client_id NULL
-- correctamente (el caso de Super Admin) sin cambios — ver
-- migrations/0005_row_level_security_policies.sql.
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON users
    USING (app_client_accessible(client_id));
