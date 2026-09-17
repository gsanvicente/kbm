-- LOCAL/TEST DATA ONLY. Never reuse these credentials or IDs beyond local
-- development; this file runs automatically against the dockerized
-- Postgres via /docker-entrypoint-initdb.d (see docker-compose.yml).

-- Test password for every seeded user below: "LocalDevOnly123!"
-- (bcrypt-hashed with pgcrypto so the app's real hashing path can be
-- exercised locally without hardcoding a plaintext-compatible hash).

INSERT INTO clients (id, name, parent_client_id) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Grupo Koons Holding', NULL),
    ('00000000-0000-0000-0000-000000000002', 'Koons Subsidiaria A', '00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000003', 'Koons Subsidiaria B', '00000000-0000-0000-0000-000000000001');

-- Transitive closure: every client is its own ancestor at depth 0, plus the
-- holding as ancestor of both subsidiaries at depth 1.
INSERT INTO client_hierarchy (ancestor_id, descendant_id, depth) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 0),
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 0),
    ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 0),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 1),
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 1);

INSERT INTO users (id, client_id, email, password_hash, role) VALUES
    ('10000000-0000-0000-0000-000000000001', NULL, 'super.admin@koons.test', crypt('LocalDevOnly123!', gen_salt('bf')), 'super_admin'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'admin.holding@koons.test', crypt('LocalDevOnly123!', gen_salt('bf')), 'client_admin'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'admin.subA@koons.test', crypt('LocalDevOnly123!', gen_salt('bf')), 'client_admin'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', 'operador.subA@koons.test', crypt('LocalDevOnly123!', gen_salt('bf')), 'operator'),
    ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 'auditor.subA@koons.test', crypt('LocalDevOnly123!', gen_salt('bf')), 'auditor');

-- Grupo Koons Holding intentionally has no cardholders of its own — a
-- holding typically doesn't issue cards directly, only its subsidiaries
-- do. Exercises the empty-state UI when drilling into the holding.
--
-- CURP/RFC values below are structurally plausible but fabricated for
-- local testing only — never real people's data. Carlos Ruiz is marked
-- as a Persona Políticamente Expuesta (PEP) on purpose, to exercise that
-- flag in the UI.
INSERT INTO cardholders (
    id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
    date_of_birth, nationality, address_street, address_neighborhood,
    address_city, address_state, address_postal_code, is_politically_exposed,
    email, phone
) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Juan Perez', 'INE', 'INE1234567890123', 'PERJ850312HDFRRN05', 'PERJ850312AB1', '1985-03-12', 'Mexicana', 'Av. Reforma 123', 'Juárez', 'Ciudad de México', 'CDMX', '06600', false, 'juan.perez@cardholder.test', '+52 55 1234 5601'),
    ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'Ana Torres', 'INE', 'INE2345678901234', 'TORA900825MDFRRN08', 'TORA900825CD2', '1990-08-25', 'Mexicana', 'Calle Insurgentes Sur 456', 'Roma Norte', 'Ciudad de México', 'CDMX', '06700', false, 'ana.torres@cardholder.test', '+52 55 1234 5603'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Maria Gomez', 'INE', 'INE3456789012345', 'GOMM880615MJCRZR03', 'GOMM880615EF3', '1988-06-15', 'Mexicana', 'Av. Vallarta 789', 'Americana', 'Guadalajara', 'Jalisco', '44160', false, 'maria.gomez@cardholder.test', '+52 33 1234 5602'),
    ('20000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'Carlos Ruiz', 'pasaporte', 'G12345678', 'RUIC750130HJCZRR07', 'RUIC750130GH4', '1975-01-30', 'Mexicana', 'Av. Chapultepec 321', 'Americana', 'Guadalajara', 'Jalisco', '44100', true, 'carlos.ruiz@cardholder.test', '+52 33 1234 5604');

INSERT INTO cardholder_users (id, cardholder_id, email, password_hash) VALUES
    ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'juan.perez@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf'))),
    ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'ana.torres@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf'))),
    ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'maria.gomez@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf'))),
    ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', 'carlos.ruiz@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf')));

-- Ana Torres intentionally has no card yet — exercises the empty-state UI
-- in docs/feature/tarjetas-de-tarjetahabiente/, and is the natural demo
-- target for assigning her one from the available pool below (Subsidiaria
-- A's limit is 1 active card/tarjetahabiente — she's under it, Juan is
-- already at it — see docs/feature/pool-y-asignacion-de-tarjetas/).
INSERT INTO cards (id, client_id, cardholder_id, masked_pan, network, expiry_month, expiry_year, status, assigned_at) VALUES
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '**** **** **** 1234', 'visa', 8, 2027, 'active', now()),
    ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '**** **** **** 5678', 'mastercard', 3, 2026, 'active', now()),
    ('40000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000004', '**** **** **** 7890', 'visa', 11, 2026, 'blocked', now());

-- Available pool: belongs to a Cliente already, not yet assigned to anyone.
INSERT INTO cards (id, client_id, cardholder_id, masked_pan, network, expiry_month, expiry_year, status, assigned_at) VALUES
    ('40000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', NULL, '**** **** **** 2001', 'visa', 5, 2028, 'unassigned', NULL),
    ('40000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002', NULL, '**** **** **** 2002', 'mastercard', 9, 2028, 'unassigned', NULL),
    ('40000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000003', NULL, '**** **** **** 3001', 'visa', 1, 2029, 'unassigned', NULL),
    ('40000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000003', NULL, '**** **** **** 3002', 'mastercard', 7, 2027, 'unassigned', NULL);

INSERT INTO ledger_accounts (id, client_id, card_id, currency) VALUES
    ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'MXN'),
    ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002', 'MXN'),
    ('50000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000004', 'MXN');

-- Movement history so the balance shown in the UI has real traceability
-- from day one (docs/business/saldo-y-ledger.md) — never a bare number
-- with no ledger_entries behind it. Explicit created_at so chronological
-- order is deterministic (all rows in one INSERT would otherwise share
-- the same now() value within the transaction).
INSERT INTO ledger_entries (id, client_id, ledger_account_id, entry_type, amount, balance_after, description, created_at) VALUES
    ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'credit', 1000.00, 1000.00, 'Carga inicial', '2026-01-10 09:00:00-06'),
    ('60000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'debit', 150.00, 850.00, 'Compra en restaurante', '2026-01-15 14:30:00-06'),
    ('60000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'credit', 400.00, 1250.00, 'Carga de fondos', '2026-01-20 10:00:00-06'),
    ('60000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000002', 'credit', 500.00, 500.00, 'Carga inicial', '2026-01-12 09:00:00-06'),
    ('60000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000002', 'debit', 159.50, 340.50, 'Compra en línea', '2026-01-18 16:45:00-06'),
    ('60000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000004', 'credit', 75.00, 75.00, 'Carga inicial', '2026-01-15 09:00:00-06');

-- Demo claim: Juan Perez disputes his "Compra en restaurante" debit.
-- Filed by the Operador, left "in_review" (a status no UI action sets
-- manually in this iteration — see docs/business/reclamos-de-movimientos.md)
-- so the badge styling has a real example to show.
INSERT INTO movement_claims (id, client_id, ledger_entry_id, reason, status, requested_by) VALUES
    ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', 'No reconozco este cargo.', 'in_review', '10000000-0000-0000-0000-000000000004');

-- Every client requires approval for transfers above 500, but not for loads.
INSERT INTO approval_rules (client_id, operation_type, requires_approval, min_amount) VALUES
    ('00000000-0000-0000-0000-000000000002', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000002', 'load', false, NULL),
    ('00000000-0000-0000-0000-000000000003', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000003', 'load', false, NULL);

-- Subsidiaria A is deliberately at capacity per-cardholder (1) to
-- demonstrate the rejection path; Subsidiaria B has room (2) to
-- demonstrate a successful assignment.
INSERT INTO client_settings (client_id, max_active_cards_per_cardholder) VALUES
    ('00000000-0000-0000-0000-000000000002', 1),
    ('00000000-0000-0000-0000-000000000003', 2);
