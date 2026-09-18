# Portal de autoservicio del Tarjetahabiente

- Estado: **Diseño completo, implementación pendiente** — espera al CRUD
  de Clientes y al CRUD de Tarjetahabientes (ver "Dependencias" en
  `docs/business/autoservicio-tarjetahabiente.md`). Se documenta ahora
  para no perder el diseño ya acordado (2026-09-17).
- ADR/TDR relacionados: `docs/adr/0002-flutter-web-mobile-two-apps.md`,
  `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 6, 11 y 12
- Roles/actores involucrados: Tarjetahabiente únicamente (plano de
  identidad `cardholder_users`, separado de staff) — ver
  `docs/business/roles-and-permissions.md`, "Plano de autoservicio"

## Objetivo
Darle al Tarjetahabiente un punto de entrada web (app `cardholder/`,
scaffold ya existente pero vacío) para ver y operar sus propias cuentas,
sin depender de un Operador — la analogía es un portal bancario, no una
extensión de la consola administrativa.

## Contexto / motivación
Ver `docs/business/autoservicio-tarjetahabiente.md` para el porqué
completo — resumen: es un plano de negocio **completamente independiente**
de la gestión de saldos del staff (sin Concentradora/Colectora, sin
`approval_rules`).

## Nota de alcance de esta iteración
- Repositorio fake, mismo patrón que `admin/` — sin backend real.
- **Login únicamente** — el registro/activación de la cuenta se asume ya
  hecho (probablemente vía app móvil, no documentado todavía). Ver
  "Onboarding" en `docs/business/autoservicio-tarjetahabiente.md`.
- Un Tarjetahabiente puede tener más de una tarjeta (el modelo ya lo
  soporta, `CardRepository.listByCardholder` devuelve una lista) — si
  tiene más de una, la pantalla de inicio necesita un selector, similar a
  un banco con varias cuentas.
- MFA no implementado — ver nota en el doc de negocio.

## Pantallas / flujo principal
1. **Login**: email + contraseña (o el mecanismo que se defina para
   `cardholder_users`, ver `data-classification.md`) → sesión con el/los
   `cardholderId` asociados a ese usuario.
2. **Inicio / selector de tarjeta** (si tiene más de una): saldo actual
   de cada tarjeta, estado (activa/congelada/bloqueada).
3. **Detalle de una tarjeta**:
   - Saldo actual, destacado (mismo criterio visual que ya usa
     `CardDetailView` en `admin/`).
   - **Estado de cuenta**: movimientos (`LedgerEntry`) de esa tarjeta,
     con filtro por **rango de fechas** (nuevo — hoy no existe ni en
     `admin/`, que solo filtra por Tipo/Estado/Empresa) y un resumen del
     periodo (total de créditos, total de débitos). Reutiliza
     `LedgerRepository.listEntries`, solo agrega el filtro de fecha en la
     UI.
   - Botón **Congelar** (si está `active`) o **Descongelar** (si está
     `frozen` por el propio Tarjetahabiente) — deshabilitado/oculto si
     está `blocked` por el staff, con un mensaje explicando que debe
     contactar a su administrador. Ver "Congelar vs. bloquear" en el doc
     de negocio.
   - Botón **Transferir** → ver
     `docs/feature/transferencia-c2c-tarjetahabiente/README.md` (flujo
     propio, documentado aparte por su complejidad).
   - Cada movimiento permite **presentar un reclamo** (reutiliza
     `LedgerRepository.fileClaim`, mismo flujo que ya existe para
     Operador, solo que `requestedByEmail` es el correo del propio
     Tarjetahabiente).

## Reglas de negocio
Ver `docs/business/autoservicio-tarjetahabiente.md` — no se repiten aquí.

## Casos borde / fuera de alcance
- Registro/activación de cuenta desde la web: fuera de alcance, ver
  "Onboarding" en el doc de negocio.
- Recuperación de contraseña: fuera de alcance de esta iteración, igual
  que en `docs/feature/login-administrativo/`.
- MFA: fuera de alcance, ver nota en el doc de negocio.
- Notificaciones (push/email) de movimientos: fuera de alcance.
- Descargar/exportar el estado de cuenta (PDF, CSV): fuera de alcance de
  esta primera versión — el resumen de periodo en pantalla cubre el "más
  bancario" pedido, exportar es una extensión futura.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
