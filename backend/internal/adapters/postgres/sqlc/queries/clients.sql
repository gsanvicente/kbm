-- Sin filtrado por rol/sesión a propósito — este backend no tiene todavía
-- un AuthorizationPort real (ver internal/application/ports/doc.go, "planned").
-- admin/'s HttpClientRepository.listAccessibleClients hace el mismo
-- filtrado client-side que ya hacía FakeClientRepository, ahora sobre
-- datos reales en vez de una lista en memoria — ver
-- docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
-- name: ListAllClients :many
SELECT id, name, parent_client_id, is_active, razon_social, nombre_comercial, rfc,
       fecha_constitucion, objeto_social, acta_numero_escritura, acta_notario, acta_plaza,
       acta_fecha, acta_folio_rpc, address_street, address_neighborhood, address_city,
       address_state, address_postal_code, address_country
FROM clients
ORDER BY name;

-- name: GetClientByID :one
SELECT id, name, parent_client_id, is_active, razon_social, nombre_comercial, rfc,
       fecha_constitucion, objeto_social, acta_numero_escritura, acta_notario, acta_plaza,
       acta_fecha, acta_folio_rpc, address_street, address_neighborhood, address_city,
       address_state, address_postal_code, address_country
FROM clients
WHERE id = $1;

-- name: CreateClient :one
INSERT INTO clients (
    name, parent_client_id, razon_social, nombre_comercial, rfc, fecha_constitucion,
    objeto_social, acta_numero_escritura, acta_notario, acta_plaza, acta_fecha,
    acta_folio_rpc, address_street, address_neighborhood, address_city, address_state,
    address_postal_code, address_country
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18
)
RETURNING id, name, parent_client_id, is_active, razon_social, nombre_comercial, rfc,
          fecha_constitucion, objeto_social, acta_numero_escritura, acta_notario, acta_plaza,
          acta_fecha, acta_folio_rpc, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country;

-- name: UpdateClient :one
-- parent_client_id e is_active nunca se tocan aquí — re-parentar sigue
-- fuera de alcance, y activar/desactivar es SetClientActive.
UPDATE clients SET
    name = $2, razon_social = $3, nombre_comercial = $4, rfc = $5, fecha_constitucion = $6,
    objeto_social = $7, acta_numero_escritura = $8, acta_notario = $9, acta_plaza = $10,
    acta_fecha = $11, acta_folio_rpc = $12, address_street = $13, address_neighborhood = $14,
    address_city = $15, address_state = $16, address_postal_code = $17, address_country = $18,
    updated_at = now()
WHERE id = $1
RETURNING id, name, parent_client_id, is_active, razon_social, nombre_comercial, rfc,
          fecha_constitucion, objeto_social, acta_numero_escritura, acta_notario, acta_plaza,
          acta_fecha, acta_folio_rpc, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country;

-- name: SetClientActiveByIDs :many
-- El llamador ya resolvió [clientId] + todos sus descendientes (ver
-- ListDescendantIDs) — un solo UPDATE en cascada, en vez de N.
UPDATE clients SET is_active = $1, updated_at = now()
WHERE id = ANY(sqlc.arg(client_ids)::uuid[])
RETURNING id, name, parent_client_id, is_active, razon_social, nombre_comercial, rfc,
          fecha_constitucion, objeto_social, acta_numero_escritura, acta_notario, acta_plaza,
          acta_fecha, acta_folio_rpc, address_street, address_neighborhood, address_city,
          address_state, address_postal_code, address_country;

-- name: ListDescendantClientIDs :many
SELECT descendant_id FROM client_hierarchy WHERE ancestor_id = $1 AND descendant_id != ancestor_id;

-- name: InsertHierarchySelf :exec
INSERT INTO client_hierarchy (ancestor_id, descendant_id, depth) VALUES ($1::uuid, $1::uuid, 0);

-- name: InsertHierarchyFromParent :exec
-- Cierre transitivo: por cada ancestro de [parent_id] (incluido él
-- mismo, ver InsertHierarchySelf), [child_id] también es su
-- descendiente, a una profundidad más. Ver migrations/0001_init.sql,
-- comentario de client_hierarchy.
INSERT INTO client_hierarchy (ancestor_id, descendant_id, depth)
SELECT ancestor_id, sqlc.arg(child_id)::uuid, depth + 1
FROM client_hierarchy
WHERE descendant_id = sqlc.arg(parent_id)::uuid;

-- name: IsClientOperable :one
-- true solo si [client_id] y TODA su cadena de ancestros (client_hierarchy
-- ya incluye a [client_id] mismo a profundidad 0) están activos.
SELECT NOT EXISTS (
    SELECT 1 FROM client_hierarchy ch
    JOIN clients c ON c.id = ch.ancestor_id
    WHERE ch.descendant_id = $1 AND NOT c.is_active
) AS operable;

-- name: ListApoderadosByClient :many
SELECT id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
       tipo_poder, descripcion_poder_especial, numero_escritura, notario, fecha_instrumento,
       vigencia, es_principal
FROM client_apoderados
WHERE client_id = $1
ORDER BY es_principal DESC, created_at;

-- name: CreateApoderado :one
INSERT INTO client_apoderados (
    client_id, full_name, id_document_type, id_document_number, curp, rfc, tipo_poder,
    descripcion_poder_especial, numero_escritura, notario, fecha_instrumento, vigencia,
    es_principal
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
)
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          tipo_poder, descripcion_poder_especial, numero_escritura, notario, fecha_instrumento,
          vigencia, es_principal;

-- name: DeleteApoderadosByClient :exec
DELETE FROM client_apoderados WHERE client_id = $1;

-- name: ListBeneficiariosByClient :many
SELECT id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
       porcentaje_participacion, is_politically_exposed, es_mayoritario
FROM client_beneficiarios
WHERE client_id = $1
ORDER BY es_mayoritario DESC, created_at;

-- name: CreateBeneficiario :one
INSERT INTO client_beneficiarios (
    client_id, full_name, id_document_type, id_document_number, curp, rfc,
    porcentaje_participacion, is_politically_exposed, es_mayoritario
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9
)
RETURNING id, client_id, full_name, id_document_type, id_document_number, curp, rfc,
          porcentaje_participacion, is_politically_exposed, es_mayoritario;

-- name: DeleteBeneficiariosByClient :exec
DELETE FROM client_beneficiarios WHERE client_id = $1;
