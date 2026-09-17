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

INSERT INTO cards (id, client_id, cardholder_id, masked_pan, status) VALUES
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '**** **** **** 1234', 'active'),
    ('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '**** **** **** 3456', 'active'),
    ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '**** **** **** 5678', 'active'),
    ('40000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000004', '**** **** **** 7890', 'blocked');

INSERT INTO ledger_accounts (id, client_id, card_id, currency) VALUES
    ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'USD'),
    ('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000003', 'USD'),
    ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002', 'USD'),
    ('50000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000004', 'USD');

-- Every client requires approval for transfers above 500, but not for loads.
INSERT INTO approval_rules (client_id, operation_type, requires_approval, min_amount) VALUES
    ('00000000-0000-0000-0000-000000000002', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000002', 'load', false, NULL),
    ('00000000-0000-0000-0000-000000000003', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000003', 'load', false, NULL);
