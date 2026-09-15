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

INSERT INTO cardholders (id, client_id, full_name, document_id, email) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Juan Perez', 'DOC-0001', 'juan.perez@cardholder.test'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Maria Gomez', 'DOC-0002', 'maria.gomez@cardholder.test');

INSERT INTO cardholder_users (id, cardholder_id, email, password_hash) VALUES
    ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'juan.perez@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf'))),
    ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'maria.gomez@cardholder.test', crypt('LocalDevOnly123!', gen_salt('bf')));

INSERT INTO cards (id, client_id, cardholder_id, masked_pan, status) VALUES
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '**** **** **** 1234', 'active'),
    ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '**** **** **** 5678', 'active');

INSERT INTO ledger_accounts (id, client_id, card_id, currency) VALUES
    ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'USD'),
    ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002', 'USD');

-- Every client requires approval for transfers above 500, but not for loads.
INSERT INTO approval_rules (client_id, operation_type, requires_approval, min_amount) VALUES
    ('00000000-0000-0000-0000-000000000002', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000002', 'load', false, NULL),
    ('00000000-0000-0000-0000-000000000003', 'transfer', true, 500.00),
    ('00000000-0000-0000-0000-000000000003', 'load', false, NULL);
