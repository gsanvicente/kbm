-- Conector SPEI — ver docs/adr/0021-conector-spei.md. Depende de
-- migrations/0009_cuenta_individual.sql (SPEI no puede dirigirse a una
-- tarjeta, solo a la CLABE de una Cuenta Individual).

-- Reutiliza el mecanismo de approval_rules ya existente para
-- Dispersión/Deducción/Transferencia (docs/business/approval-policy.md,
-- punto 7 del ADR) — un pago SPEI a tercero es un OperationType más, no
-- un mecanismo de aprobación nuevo.
ALTER TYPE operation_type ADD VALUE 'spei_payment';

-- Beneficiario de Pago — nombre deliberadamente distinto de
-- BENEFICIARIO_CONTROLADOR (KYB, docs/business/domain-model.md): esa es
-- la persona dueña mayoritaria de un Cliente, esta es a quién un
-- Tarjetahabiente le puede enviar dinero por SPEI. bank_name se deriva
-- del catálogo de bancos por los primeros 3 dígitos de la CLABE (ver
-- internal/domain/clabe) — nunca es texto libre del cliente.
CREATE TABLE payment_beneficiaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    cardholder_id uuid NOT NULL REFERENCES cardholders(id),
    alias text NOT NULL,
    clabe char(18) NOT NULL,
    bank_name text NOT NULL,
    -- Periodo de enfriamiento (ADR-0021, "Seguridad") — mientras
    -- now() < cooling_until, este beneficiario solo puede recibir pagos
    -- por debajo de cooling_period_max_amount (aplicado en código, no
    -- aquí, para poder ajustar el monto sin migración).
    cooling_until timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE payment_beneficiaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON payment_beneficiaries
    USING (app_client_accessible(client_id));
CREATE INDEX payment_beneficiaries_cardholder_id_idx ON payment_beneficiaries(cardholder_id);

-- Pago SPEI saliente — tabla propia, no reutiliza balance_operations
-- (mismo criterio que "Compra" en ADR-0011: reglas propias, y aquí quien
-- origina es el propio Tarjetahabiente, no el staff sobre una tarjeta).
-- Debita la Cuenta Individual (nunca la Concentradora, punto 6 del ADR).
CREATE TABLE spei_payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    account_id uuid NOT NULL REFERENCES individual_accounts(id),
    beneficiary_id uuid NOT NULL REFERENCES payment_beneficiaries(id),
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    status operation_status NOT NULL DEFAULT 'pending_approval',
    requested_by_cardholder_id uuid NOT NULL REFERENCES cardholders(id),
    resolved_by uuid REFERENCES users(id),
    resolution_notes text,
    -- Referencia del proveedor SPEI simulado/real — sin proveedor real
    -- todavía, el simulador la genera al despachar (ver
    -- internal/adapters/spei). NULL mientras el pago sigue
    -- pending_approval/rejected/failed.
    provider_reference text UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE spei_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON spei_payments
    USING (app_client_accessible(client_id));
CREATE INDEX spei_payments_account_id_idx ON spei_payments(account_id);

-- Depósito SPEI entrante — concilia automáticamente (punto 8 del ADR),
-- a diferencia del depósito declarado en la Colectora
-- (docs/business/tesoreria-cliente.md): idempotente por
-- provider_reference (UNIQUE), nunca pasa por un segundo control humano.
CREATE TABLE spei_deposits (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    account_id uuid NOT NULL REFERENCES individual_accounts(id),
    amount numeric(18,2) NOT NULL CHECK (amount > 0),
    provider_reference text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE spei_deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON spei_deposits
    USING (app_client_accessible(client_id));
