-- Initial KBM schema. Tenant scoping: every tenant-owned table carries a
-- direct client_id column (denormalized) so Row-Level Security policies can
-- filter on it without joining through cards/cardholders. The app sets
-- `app.accessible_client_ids` (a GUC, computed from client_hierarchy) once
-- per request/transaction; RLS policies check membership against it.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

CREATE TYPE user_role AS ENUM ('super_admin', 'client_admin', 'operator', 'auditor');
CREATE TYPE card_status AS ENUM ('active', 'blocked', 'frozen', 'cancelled');
CREATE TYPE ledger_entry_type AS ENUM ('debit', 'credit');
CREATE TYPE operation_type AS ENUM ('load', 'debit', 'transfer', 'block', 'unblock');
CREATE TYPE operation_status AS ENUM ('pending_approval', 'approved', 'rejected', 'executed', 'failed');
CREATE TYPE id_document_type AS ENUM ('INE', 'pasaporte', 'cedula_profesional');

-- Clients (empresas), self-referencing for parent/child company groups.
CREATE TABLE clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    parent_client_id uuid REFERENCES clients(id),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Transitive closure of the client hierarchy (every client is its own
-- ancestor at depth 0), maintained by the application when a client is
-- created or re-parented. Lets N-level hierarchy queries stay O(1) instead
-- of recursive.
CREATE TABLE client_hierarchy (
    ancestor_id uuid NOT NULL REFERENCES clients(id),
    descendant_id uuid NOT NULL REFERENCES clients(id),
    depth int NOT NULL,
    PRIMARY KEY (ancestor_id, descendant_id)
);

-- Staff/admin users (Koons + client-side roles). Separate from
-- cardholder_users below: two distinct identity planes.
CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES clients(id), -- null only for super_admin
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    role user_role NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    mfa_enabled boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- KYC/PLD fields (curp, rfc, domicilio, id_politically_exposed) hold
-- sensitive personal data regulated under Mexico's LFPDPPP, not just
-- generic PII — see docs/business/kyc-tarjetahabiente.md and
-- docs/security/data-classification.md before adding new consumers of
-- this table (exports, reports, logs).
CREATE TABLE cardholders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    full_name text NOT NULL,
    id_document_type id_document_type NOT NULL DEFAULT 'INE',
    id_document_number text NOT NULL,
    curp text,
    rfc text,
    date_of_birth date,
    nationality text DEFAULT 'Mexicana',
    address_street text,
    address_neighborhood text,
    address_city text,
    address_state text,
    address_postal_code text,
    address_country text DEFAULT 'México',
    is_politically_exposed boolean NOT NULL DEFAULT false,
    email citext,
    phone text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Self-service login identity for the cardholder portal/app. Kept separate
-- from `users` so cardholder auth policy (MFA, session lifetime, password
-- rules) can differ from staff auth policy without conditional logic.
CREATE TABLE cardholder_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cardholder_id uuid NOT NULL UNIQUE REFERENCES cardholders(id),
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    cardholder_id uuid NOT NULL REFERENCES cardholders(id),
    external_processor_ref text,
    masked_pan text NOT NULL,
    status card_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ledger_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    card_id uuid NOT NULL UNIQUE REFERENCES cards(id),
    currency char(3) NOT NULL DEFAULT 'USD',
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Append-only ledger. No updated_at/deleted_at on purpose: entries are
-- immutable once written (see trigger below) so the balance history is a
-- reliable audit trail, not just a cache.
CREATE TABLE ledger_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    ledger_account_id uuid NOT NULL REFERENCES ledger_accounts(id),
    entry_type ledger_entry_type NOT NULL,
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    balance_after numeric(18,2) NOT NULL,
    related_operation_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'ledger_entries is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_entries_no_update
    BEFORE UPDATE OR DELETE ON ledger_entries
    FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE approval_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    operation_type operation_type NOT NULL,
    requires_approval boolean NOT NULL DEFAULT true,
    min_amount numeric(18,2),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE balance_operations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    card_id uuid NOT NULL REFERENCES cards(id),
    operation_type operation_type NOT NULL,
    amount numeric(18,2),
    status operation_status NOT NULL DEFAULT 'pending_approval',
    requested_by uuid NOT NULL REFERENCES users(id),
    approved_by uuid REFERENCES users(id),
    approval_rule_id uuid REFERENCES approval_rules(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Transactional outbox: written in the same DB transaction as the state
-- change it describes, so an event is never lost even if the queue/broker
-- is down. Relayed by cmd/worker via internal/adapters/outbox.
CREATE TABLE outbox_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz
);

CREATE TABLE audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id uuid,
    actor_type text NOT NULL, -- 'staff' | 'cardholder' | 'system'
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    metadata jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON cardholders (client_id);
CREATE INDEX ON cards (client_id);
CREATE INDEX ON cards (cardholder_id);
CREATE INDEX ON ledger_entries (ledger_account_id);
CREATE INDEX ON balance_operations (client_id, status);
CREATE INDEX ON audit_log (entity_type, entity_id);

-- Row-Level Security: enabled here, policies to be added alongside the
-- Postgres adapter once the session GUC (app.accessible_client_ids) is
-- wired from the authenticated request context.
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE cardholders ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE balance_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_rules ENABLE ROW LEVEL SECURITY;
