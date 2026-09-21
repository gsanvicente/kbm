-- Row-Level Security policies — see
-- docs/adr/0014-row-level-security-policies.md. migrations/0001_init.sql
-- already enabled RLS on the tenant-owned tables but deferred the
-- policies themselves until a verified caller identity existed (see
-- docs/adr/0013-jwt-session-authentication.md, which built that).
--
-- RLS has no effect on a table's owner or on a superuser, regardless of
-- policies — Postgres bypasses it unconditionally for both. The app
-- previously connected as `kbm` (POSTGRES_USER, a superuser that owns
-- every table from running the init scripts), so writing policies alone
-- would have been silently inert. kbm_app is a plain, non-superuser role
-- that owns nothing — it is actually subject to the policies below. This
-- migration still runs as `kbm` (docker's init mechanism always runs
-- init scripts as POSTGRES_USER), so `kbm` remains the role that owns
-- the schema and can grant privileges on it.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'kbm_app') THEN
        CREATE ROLE kbm_app WITH LOGIN PASSWORD 'kbm_app_dev_only';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE kbm TO kbm_app;
GRANT USAGE ON SCHEMA public TO kbm_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kbm_app;
-- Cualquier tabla que una migración futura agregue (corriendo como
-- `kbm`, el owner) también queda accesible para kbm_app sin un GRANT
-- manual adicional.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kbm_app;

-- app_client_accessible(target) — true si [target] está dentro del
-- alcance del llamador actual. El backend fija app.accessible_client_ids
-- una vez por transacción (SET LOCAL, ver
-- internal/adapters/postgres/repository/rls.go) a una lista separada por
-- comas de client_id (el propio más sus descendientes, ver
-- client_hierarchy) o al centinela '*' para alcance global (Super Admin,
-- o los dos endpoints de login, que corren antes de que exista ninguna
-- identidad de llamador que resolver). Sin valor fijado (current_setting
-- con missing_ok=true devuelve ''), no calza con ningún id real — falla
-- cerrado, nunca abierto.
CREATE OR REPLACE FUNCTION app_client_accessible(target_client_id uuid) RETURNS boolean AS $$
    SELECT current_setting('app.accessible_client_ids', true) = '*'
        OR target_client_id::text = ANY(string_to_array(current_setting('app.accessible_client_ids', true), ','));
$$ LANGUAGE sql STABLE;

CREATE POLICY tenant_isolation ON clients
    USING (app_client_accessible(id));

CREATE POLICY tenant_isolation ON cardholders
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON cards
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON ledger_accounts
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON ledger_entries
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON balance_operations
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON approval_rules
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON client_settings
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON movement_claims
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON concentrator_accounts
    USING (app_client_accessible(client_id));

-- concentrator_entries no tiene columna client_id propia (ver
-- migrations/0001_init.sql) — se resuelve vía su cuenta concentradora.
-- concentrator_accounts trae su propia política (arriba), así que esta
-- subquery queda filtrada dos veces por el mismo criterio; redundante
-- pero inofensivo.
CREATE POLICY tenant_isolation ON concentrator_entries
    USING (EXISTS (
        SELECT 1 FROM concentrator_accounts ca
        WHERE ca.id = concentrator_entries.concentrator_account_id
          AND app_client_accessible(ca.client_id)
    ));

CREATE POLICY tenant_isolation ON collector_deposits
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON client_apoderados
    USING (app_client_accessible(client_id));

CREATE POLICY tenant_isolation ON client_beneficiarios
    USING (app_client_accessible(client_id));
