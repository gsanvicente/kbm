-- Cuenta Individual del Tarjetahabiente — ver
-- docs/adr/0020-cuenta-individual-tarjetahabiente.md. El saldo deja de
-- vivir en la tarjeta (ledger_accounts.card_id) y pasa a vivir en una
-- Cuenta Individual del Tarjetahabiente, que nace al darlo de alta (no al
-- asignarle una tarjeta) y sobrevive a un reemplazo de tarjeta.
--
-- En esta primera implementación cada Tarjetahabiente tiene exactamente
-- una Cuenta Individual (cardholder_id UNIQUE) — permitir varias queda
-- fuera de esta pasada, sin flujo para crear una adicional; ningún
-- Tarjetahabiente sembrado hoy tiene más de una tarjeta activa
-- simultánea, así que no hay caso real que se pierda al migrar.
CREATE TABLE individual_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    cardholder_id uuid NOT NULL UNIQUE REFERENCES cardholders(id),
    -- CLABE — nullable hasta que se conecte un proveedor SPEI real, ver
    -- docs/adr/0021-conector-spei.md. La Cuenta es funcional (recibe
    -- Dispersión, tiene tarjeta activa) sin CLABE asignada todavía.
    clabe char(18) UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE individual_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON individual_accounts
    USING (app_client_accessible(client_id));

-- Tarjeta: instrumento de gasto sobre una Cuenta, ya no dueña del saldo.
ALTER TABLE cards ADD COLUMN account_id uuid REFERENCES individual_accounts(id);
-- Motivo de cancelación — mismo espíritu que blocked_reason, pero para el
-- estado terminal `cancelled` (nunca reversible), ver
-- docs/business/tarjetas-y-asignacion.md, "Reemplazo de tarjeta".
ALTER TABLE cards ADD COLUMN cancelled_reason text;

-- Backfill: una Cuenta Individual por Tarjetahabiente que ya tiene alguna
-- tarjeta (asignada o no) — cubre a todos los Tarjetahabientes sembrados,
-- incluso los que todavía no tienen ninguna tarjeta asignada (ver
-- "Prueba Activacion"/"Nueva Persona" en el seed local).
INSERT INTO individual_accounts (client_id, cardholder_id)
SELECT ch.client_id, ch.id
FROM cardholders ch;

-- Relaciona cada tarjeta ya asignada con la Cuenta de su Tarjetahabiente.
UPDATE cards c
SET account_id = ia.id
FROM individual_accounts ia
WHERE c.cardholder_id = ia.cardholder_id
  AND c.cardholder_id IS NOT NULL;

-- ledger_accounts pasa de colgar de la tarjeta a colgar de la Cuenta.
ALTER TABLE ledger_accounts ADD COLUMN account_id uuid REFERENCES individual_accounts(id);
UPDATE ledger_accounts la
SET account_id = c.account_id
FROM cards c
WHERE la.card_id = c.id;

-- Toda Cuenta Individual, tenga o no tarjeta todavía, nace con su propio
-- ledger_account — puede recibir un depósito SPEI antes de que llegue la
-- primera tarjeta (ver docs/adr/0021-conector-spei.md). card_id todavía
-- es NOT NULL en este punto; se relaja para poder insertar estas filas
-- sin tarjeta, y la columna completa se elimina más abajo de todos modos.
ALTER TABLE ledger_accounts ALTER COLUMN card_id DROP NOT NULL;
INSERT INTO ledger_accounts (client_id, account_id, currency)
SELECT ia.client_id, ia.id, 'MXN'
FROM individual_accounts ia
LEFT JOIN ledger_accounts la ON la.account_id = ia.id
WHERE la.id IS NULL;

-- Con el backfill hecho, account_id pasa a ser la relación real:
-- obligatoria y única (1 ledger_account por Cuenta, igual que antes era
-- 1 por tarjeta).
ALTER TABLE ledger_accounts ALTER COLUMN account_id SET NOT NULL;
ALTER TABLE ledger_accounts ADD CONSTRAINT ledger_accounts_account_id_key UNIQUE (account_id);
ALTER TABLE ledger_accounts DROP COLUMN card_id;
