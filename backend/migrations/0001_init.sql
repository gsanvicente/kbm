-- Initial KBM schema. Tenant scoping: every tenant-owned table carries a
-- direct client_id column (denormalized) so Row-Level Security policies can
-- filter on it without joining through cards/cardholders. The app sets
-- `app.accessible_client_ids` (a GUC, computed from client_hierarchy) once
-- per request/transaction; RLS policies check membership against it.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

CREATE TYPE user_role AS ENUM ('super_admin', 'client_admin', 'operator', 'auditor');
CREATE TYPE card_status AS ENUM ('unassigned', 'active', 'blocked', 'frozen', 'cancelled');
CREATE TYPE card_network AS ENUM ('visa', 'mastercard');
CREATE TYPE ledger_entry_type AS ENUM ('debit', 'credit');
CREATE TYPE operation_type AS ENUM ('load', 'debit', 'transfer', 'block', 'unblock');
CREATE TYPE operation_status AS ENUM ('pending_approval', 'approved', 'rejected', 'executed', 'failed');
CREATE TYPE id_document_type AS ENUM ('INE', 'pasaporte', 'cedula_profesional');
CREATE TYPE claim_status AS ENUM ('open', 'in_review', 'resolved_favor', 'rejected');

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

-- A card is always created for a specific Cliente but can start out
-- unassigned (cardholder_id null) — the "pool" of available cards. Its
-- ledger_account is created only at assignment time, not before — see
-- docs/business/tarjetas-y-asignacion.md.
CREATE TABLE cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    cardholder_id uuid REFERENCES cardholders(id),
    external_processor_ref text,
    masked_pan text NOT NULL,
    network card_network NOT NULL DEFAULT 'visa',
    expiry_month smallint NOT NULL CHECK (expiry_month BETWEEN 1 AND 12),
    expiry_year smallint NOT NULL,
    status card_status NOT NULL DEFAULT 'unassigned',
    assigned_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((cardholder_id IS NULL) = (assigned_at IS NULL))
);

-- Per-Cliente configuration — same pattern as approval_rules. NULL means
-- no limit. Counts only active cards (docs/business/tarjetas-y-asignacion.md).
CREATE TABLE client_settings (
    client_id uuid PRIMARY KEY REFERENCES clients(id),
    max_active_cards_per_cardholder int,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ledger_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    card_id uuid NOT NULL UNIQUE REFERENCES cards(id),
    currency char(3) NOT NULL DEFAULT 'MXN',
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
    description text,
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

-- A dispute over an already-executed movement — distinct from
-- balance_operations (which is pre-execution, approval-gated). Never
-- mutates ledger_entries; see docs/business/reclamos-de-movimientos.md.
-- 1:1 with the movement it's about.
CREATE TABLE movement_claims (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    ledger_entry_id uuid NOT NULL UNIQUE REFERENCES ledger_entries(id),
    reason text NOT NULL,
    status claim_status NOT NULL DEFAULT 'open',
    requested_by uuid NOT NULL REFERENCES users(id),
    resolved_by uuid REFERENCES users(id),
    resolution_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CHECK ((status IN ('resolved_favor', 'rejected')) = (resolved_by IS NOT NULL AND resolved_at IS NOT NULL))
);

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
    -- Only for operation_type = 'transfer' — the other card in the same
    -- Cliente that receives the funds. See
    -- docs/feature/operacion-saldo-con-aprobacion/README.md, "Destino de
    -- una transferencia".
    destination_card_id uuid REFERENCES cards(id),
    status operation_status NOT NULL DEFAULT 'pending_approval',
    requested_by uuid NOT NULL REFERENCES users(id),
    -- Whoever resolved it, approving or rejecting — same naming as
    -- movement_claims.resolved_by, not "approved_by": a rejection is
    -- also a resolution.
    resolved_by uuid REFERENCES users(id),
    resolution_notes text,
    approval_rule_id uuid REFERENCES approval_rules(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((operation_type = 'transfer') = (destination_card_id IS NOT NULL))
);

CREATE TYPE collector_deposit_status AS ENUM ('pending', 'reconciled');

-- The real pooled account behind a Client's Dispersiones/Deducciones —
-- 1:1 with a client, never with a card. See
-- docs/business/tesoreria-cliente.md.
CREATE TABLE concentrator_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL UNIQUE REFERENCES clients(id),
    currency text NOT NULL DEFAULT 'MXN',
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Same append-only pattern as ledger_entries, one level up (Cliente
-- instead of Tarjeta). A Dispersión debits this, a Deducción credits it;
-- a reconciled collector_deposit also credits it. Transferencia never
-- touches it (internal to the client's own pool already).
CREATE TABLE concentrator_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concentrator_account_id uuid NOT NULL REFERENCES concentrator_accounts(id),
    entry_type ledger_entry_type NOT NULL,
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    balance_after numeric(18,2) NOT NULL,
    description text,
    related_operation_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER concentrator_entries_no_update
    BEFORE UPDATE OR DELETE ON concentrator_entries
    FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- The Cuenta Colectora's deposits — registering one never moves the
-- Concentradora's balance by itself; only reconciling does. See
-- docs/business/tesoreria-cliente.md, "El flujo de fondeo: dos pasos, no
-- uno" for why this is deliberately not a single step.
CREATE TABLE collector_deposits (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    reference text NOT NULL,
    status collector_deposit_status NOT NULL DEFAULT 'pending',
    registered_by uuid NOT NULL REFERENCES users(id),
    reconciled_by uuid REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    reconciled_at timestamptz,
    CHECK ((status = 'reconciled') = (reconciled_by IS NOT NULL AND reconciled_at IS NOT NULL))
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
CREATE INDEX ON cards (client_id, status);
CREATE INDEX ON ledger_entries (ledger_account_id);
CREATE INDEX ON movement_claims (status);
CREATE INDEX ON balance_operations (client_id, status);
CREATE INDEX ON audit_log (entity_type, entity_id);
CREATE INDEX ON concentrator_entries (concentrator_account_id);
CREATE INDEX ON collector_deposits (client_id, status);

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
ALTER TABLE client_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE movement_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE concentrator_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE concentrator_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE collector_deposits ENABLE ROW LEVEL SECURITY;
