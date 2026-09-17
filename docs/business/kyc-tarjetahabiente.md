# Datos KYC del Tarjetahabiente (expediente bancario)

> Referencia viva. Última revisión: 2026-09-17.

## Por qué existen estos campos

Un tarjetahabiente no es solo "nombre + contacto" — para operar como
sistema de gestión de saldos en México, el expediente necesita soportar
identificación oficial y prevención de lavado de dinero (PLD/AML), no solo
UX. Estos campos existen porque los pide la operación bancaria real, no
porque "podrían servir algún día" — evitamos recolectar de más
(minimización de datos, ver `docs/security/compliance-notes.md`).

## Campos del expediente

**Identificación legal**
- `curp` — Clave Única de Registro de Población (18 caracteres).
- `rfc` — Registro Federal de Contribuyentes (13 caracteres, persona
  física), opcional — relevante si el tarjetahabiente requiere
  facturación o reporte fiscal.
- `idDocumentType` / `idDocumentNumber` — tipo (INE, Pasaporte, Cédula
  profesional) + número del documento de identidad oficial. Reemplaza al
  campo genérico "documento" de la iteración anterior.
- `dateOfBirth` — fecha de nacimiento.
- `nationality` — nacionalidad.

**Domicilio** (requisito estándar de "comprobante de domicilio" en KYC)
- Calle y número, colonia, ciudad, estado, código postal, país.

**Perfil de cumplimiento (PLD/AML)**
- `isPoliticallyExposed` — Persona Políticamente Expuesta (PEP). Campo
  estándar de la regulación mexicana de prevención de lavado de dinero:
  cuentas de PEPs requieren monitoreo reforzado. Aquí solo se captura el
  dato — la lógica de monitoreo reforzado es una feature futura, no de
  esta iteración.

## Fuera de alcance de esta iteración

- **Validación real de CURP/RFC** (dígito verificador, estructura exacta):
  los campos son texto libre con longitud sugerida, sin validar el
  algoritmo de checksum real. Implementarlo es una TDR futura cuando haya
  backend real.
- **Monitoreo reforzado de PEPs**: se captura el flag, no se actúa sobre
  él todavía.
- **Enmascaramiento de campos sensibles por rol**: hoy, cualquier rol de
  staff que puede *ver* el detalle de un tarjetahabiente (ver
  `docs/business/roles-and-permissions.md`) ve el expediente completo,
  incluyendo CURP/RFC/domicilio. Decisión explícita para esta iteración:
  son roles internos ya autorizados a ver el perfil (incluido Auditor, que
  necesita ver todo para auditar). Si en el futuro se requiere
  enmascaramiento adicional (ej. mostrar solo los últimos 4 caracteres del
  CURP a ciertos roles), es una ADR nueva — es un cambio de modelo de
  autorización a nivel de campo, no solo de pantalla.

## Ver también
- `docs/security/data-classification.md` — clasificación de estos campos
  como PII sensible.
- `docs/security/compliance-notes.md` — LFPDPPP, no solo PCI-DSS.
- `docs/feature/detalle-y-gestion-tarjetahabiente/` — dónde se ven y
  editan estos campos.
