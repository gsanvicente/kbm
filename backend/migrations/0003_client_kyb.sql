-- Full KYB expediente for a Cliente (persona moral) — the original
-- `clients` table only had id/name/parent/is_active, enough for the
-- hierarchy but never for the wizard admin/'s Dart fakes already
-- collect (razón social, RFC, acta constitutiva, apoderados,
-- beneficiarios controladores). See docs/business/kyb-cliente.md.
-- Nullable throughout: seed Clientes intentionally have no expediente
-- (see scripts/init-db/001_seed.sql), same as admin/lib/core/models/client.dart.
ALTER TABLE clients ADD COLUMN razon_social text;
ALTER TABLE clients ADD COLUMN nombre_comercial text;
ALTER TABLE clients ADD COLUMN rfc text;
ALTER TABLE clients ADD COLUMN fecha_constitucion date;
ALTER TABLE clients ADD COLUMN objeto_social text;
ALTER TABLE clients ADD COLUMN acta_numero_escritura text;
ALTER TABLE clients ADD COLUMN acta_notario text;
ALTER TABLE clients ADD COLUMN acta_plaza text;
ALTER TABLE clients ADD COLUMN acta_fecha date;
ALTER TABLE clients ADD COLUMN acta_folio_rpc text;
ALTER TABLE clients ADD COLUMN address_street text;
ALTER TABLE clients ADD COLUMN address_neighborhood text;
ALTER TABLE clients ADD COLUMN address_city text;
ALTER TABLE clients ADD COLUMN address_state text;
ALTER TABLE clients ADD COLUMN address_postal_code text;
ALTER TABLE clients ADD COLUMN address_country text DEFAULT 'México';

CREATE TYPE client_tipo_poder AS ENUM (
    'actos_de_administracion', 'pleitos_y_cobranzas', 'actos_de_dominio', 'especial'
);

-- Apoderados Legales — cada Cliente tiene exactamente un `es_principal`
-- (requerido) más cero o más adicionales, ver
-- admin/lib/core/models/apoderado_legal.dart. No hay CHECK de "exactamente
-- uno principal" a nivel de base de datos — se cumple en la capa de
-- aplicación, mismo criterio que el resto del schema (ver
-- balance_operations, sin constraint para su propia máquina de estados).
CREATE TABLE client_apoderados (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    full_name text NOT NULL,
    id_document_type id_document_type NOT NULL DEFAULT 'INE',
    id_document_number text NOT NULL,
    curp text,
    rfc text,
    tipo_poder client_tipo_poder NOT NULL,
    -- Solo aplica (y es requerido en la app) cuando tipo_poder = 'especial'.
    descripcion_poder_especial text,
    numero_escritura text NOT NULL,
    notario text NOT NULL,
    fecha_instrumento date NOT NULL,
    vigencia date,
    es_principal boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Beneficiarios Controladores (PLD/LFPIORPI) — un `es_mayoritario`
-- requerido más cero o más minoritarios, ver
-- admin/lib/core/models/beneficiario_controlador.dart.
CREATE TABLE client_beneficiarios (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES clients(id),
    full_name text NOT NULL,
    id_document_type id_document_type NOT NULL DEFAULT 'INE',
    id_document_number text NOT NULL,
    curp text,
    rfc text,
    porcentaje_participacion numeric(5,2) NOT NULL,
    is_politically_exposed boolean NOT NULL DEFAULT false,
    es_mayoritario boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON client_apoderados (client_id);
CREATE INDEX ON client_beneficiarios (client_id);

ALTER TABLE client_apoderados ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_beneficiarios ENABLE ROW LEVEL SECURITY;
