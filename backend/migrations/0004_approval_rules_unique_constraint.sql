-- Sin esto, dos filas para el mismo (client_id, operation_type) eran
-- posibles y `GetApprovalRule` (WHERE client_id = $1 AND operation_type =
-- $2) hubiera devuelto una arbitraria — nunca pasó porque solo el seed
-- escribía esta tabla, pero la nueva UI de configuración de Cliente
-- (docs/feature/configuracion-de-cliente/README.md) hace upsert real
-- desde ahora y necesita esta restricción para que `ON CONFLICT`
-- funcione.
ALTER TABLE approval_rules
    ADD CONSTRAINT approval_rules_client_operation_unique UNIQUE (client_id, operation_type);
