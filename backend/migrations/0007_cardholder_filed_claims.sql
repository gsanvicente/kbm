-- Permite que un Tarjetahabiente presente un reclamo sobre su propio
-- movimiento — ver docs/business/reclamos-de-movimientos.md,
-- "Quién puede presentar un reclamo". Hasta ahora `requested_by`
-- apuntaba únicamente a `users` (staff); un Tarjetahabiente no tiene fila
-- ahí. Se agrega una columna paralela hacia `cardholders`, con un CHECK
-- que exige exactamente una de las dos (nunca ambas, nunca ninguna) —
-- mismo criterio de "un plano de identidad u otro, nunca mezclados" que
-- ya separa `users` de `cardholder_users` en todo el proyecto.
ALTER TABLE movement_claims ALTER COLUMN requested_by DROP NOT NULL;
ALTER TABLE movement_claims ADD COLUMN requested_by_cardholder_id uuid REFERENCES cardholders(id);
ALTER TABLE movement_claims ADD CONSTRAINT movement_claims_requester_check
    CHECK ((requested_by IS NOT NULL) <> (requested_by_cardholder_id IS NOT NULL));
