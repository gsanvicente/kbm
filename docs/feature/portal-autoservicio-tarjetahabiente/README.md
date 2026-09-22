# Portal de autoservicio del Tarjetahabiente

- Estado: **Implementado** (2026-09-21) — login, activación de cuenta,
  detalle de tarjeta (saldo + Transferir + Bloqueo temporal), Movimientos
  (con filtro de periodo y resumen) y presentar un reclamo existen en
  `cardholder/`, con una navegación persistente (sidebar en pantallas
  anchas, barra inferior en angostas, homologada visualmente con
  `admin/`) en vez de una sola pantalla suelta — ver "Diseño" más abajo.
- ADR/TDR relacionados: `docs/adr/0002-flutter-web-mobile-two-apps.md`,
  `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`,
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`,
  `docs/adr/0013-jwt-session-authentication.md`,
  `docs/adr/0018-cardholder-filed-claims.md`,
  `docs/adr/0019-cardholder-self-activation.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 6, 11, 12 y 16
- Roles/actores involucrados: Tarjetahabiente únicamente (plano de
  identidad `cardholder_users`, separado de staff) — ver
  `docs/business/roles-and-permissions.md`, "Plano de autoservicio"

## Objetivo
Darle al Tarjetahabiente un punto de entrada web (app `cardholder/`) para
ver y operar sus propias cuentas, sin depender de un Operador — la
analogía es un portal bancario, no una extensión de la consola
administrativa.

## Contexto / motivación
Ver `docs/business/autoservicio-tarjetahabiente.md` para el porqué
completo — resumen: es un plano de negocio **completamente independiente**
de la gestión de saldos del staff (sin Concentradora/Colectora, sin
`approval_rules`).

## Nota de alcance de esta iteración
- `HttpCardholderBackend` habla con el backend Go compartido con
  `admin/` (ver `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`);
  `FakeCardholderBackend` (una sola clase, implementa las tres interfaces
  de auth/tarjetas/transferencias a la vez) sigue existiendo solo para
  los widget tests — ver "Nota de alcance" en
  `docs/feature/transferencia-c2c-tarjetahabiente/README.md` para el
  porqué de no separarla en varios repositorios.
- **Login únicamente** — el registro/activación de la cuenta se asume ya
  hecho (probablemente vía app móvil, no documentado todavía). Ver
  "Onboarding" en `docs/business/autoservicio-tarjetahabiente.md`. El
  login ya aplica la Capa 1 de
  `docs/business/desactivacion-de-tarjetahabientes.md`: un Tarjetahabiente
  inactivo no puede iniciar sesión (mismo mensaje genérico que una
  contraseña incorrecta).
- Un Tarjetahabiente puede tener más de una tarjeta — **implementado**:
  si tiene más de una, la pantalla de inicio muestra un selector; si solo
  tiene una, entra directo a su detalle.
- MFA no implementado — ver nota en el doc de negocio.
- **(2026-09-21)** El login emite un JWT (ver
  `docs/adr/0013-jwt-session-authentication.md`) que `cardholder/`
  adjunta como `Authorization: Bearer <token>` en toda petición
  posterior; expira a las 12h sin refresh. Todo endpoint que este
  Tarjetahabiente usa (tarjetas propias, ledger, self-freeze,
  transferencias) verifica que el `cardholderId` del token coincida con
  el del recurso pedido — pedir el de otro Tarjetahabiente se rechaza
  con el mismo 404 genérico que ya usaba el resto del sistema para
  "nunca revelar que el recurso existe pero es de alguien más". Todo
  intento de login (éxito o fallo con email conocido) queda registrado
  en `audit_log`, ver
  `docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`.

## Pantallas / flujo principal
1. **Login** — email + contraseña. **Implementado.** Desde la propia
   pantalla de login, un enlace **"¿Nuevo? Activa tu cuenta"** lleva a la
   activación (ver siguiente punto) — visible en web y mobile por igual.
1b. **Activar cuenta** — **implementado** (2026-09-21): email + número de
    identificación oficial (los mismos datos que el staff ya capturó al
    dar de alta al Tarjetahabiente) + nueva contraseña (mín. 8
    caracteres, doble captura). Sin infraestructura de correo/SMS, ver
    `docs/feature/activacion-de-tarjetahabiente/README.md` y
    `docs/adr/0019-cardholder-self-activation.md`.
2. **Inicio / selector de tarjeta** (si tiene más de una) — **implementado**,
   saldo y estado de cada tarjeta.
3. **Dentro de una tarjeta** (pestañas "Inicio" y "Movimientos" del
   mismo marco de navegación, ver "Diseño"):
   - **Inicio**: tarjeta (visual, nunca el PAN completo) + saldo actual,
     destacado. **Implementado.**
   - **Movimientos** (lista de la cuenta, más reciente primero) —
     **implementado**, con filtro por periodo (Todo/Este mes/Mes
     pasado/rango personalizado) y un resumen de Depósitos/Cargos/Neto
     del periodo seleccionado, puramente client-side sobre la misma
     lista ya cargada (sin parámetros de fecha en el backend).
   - Botón **Bloqueo temporal** (congelar/descongelar la propia
     tarjeta) — **implementado** (2026-09-19), ver
     `docs/business/autoservicio-tarjetahabiente.md`, "Congelar vs.
     bloquear una tarjeta". Solo disponible sobre una tarjeta `active`
     (para congelar) o `frozen` (para descongelar) — una tarjeta
     `blocked` por el staff sí muestra el mensaje de "contacta a tu
     administrador" en vez de cualquier acción de autoservicio, ni
     siquiera esta.
   - Botón **Transferir** — **implementado**, ver
     `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.
   - Presentar un reclamo por movimiento — **implementado** (2026-09-21):
     tocar un movimiento abre su detalle; si no tiene reclamo, un campo
     de motivo + "Presentar reclamo"; si ya tiene uno, su
     estado/motivo/notas de resolución (nunca puede resolverlo, solo
     verlo). Ver `docs/adr/0018-cardholder-filed-claims.md`.

## Diseño
El portal usa un marco de navegación persistente una vez dentro de una
tarjeta (`CardholderShell`), homologado con `admin/lib/app/admin_shell.dart`:
un sidebar navy fijo (248px, mismo `KoonsColors.sidebarBackground`/
`sidebarItemActive`/`sidebarText`) en pantallas anchas (≥900px,
web/desktop), o una `NavigationBar` inferior en angostas (móvil), con dos
destinos — Inicio y Movimientos. El topbar (blanco, borde inferior,
título de la sección a la izquierda, avatar + nombre + cerrar sesión a la
derecha) sigue el mismo formato que el `_TopBar` de `admin/`, con un
`onBack` opcional que `admin/` no necesita (para el selector de
tarjetas). La pantalla de login (logo, tamaños, layout) también se
homologó exactamente contra `admin/lib/features/auth/login_screen.dart`
— antes tenía un logo más chico y un contenedor más angosto, lo que hacía
que las dos apps se vieran como productos distintos en vez de un mismo
portal bancario con dos entradas. Todo esto es código duplicado
(ADR-0002), pero el **diseño no debe divergir** — mismo criterio que ya
aplica a la tarjeta (`PaymentCardVisual`, ver abajo).

La tarjeta se representa con `PaymentCardVisual`
(`cardholder/lib/shared_widgets/payment_card_visual.dart`) — el mismo
activo de marca que ya usa `admin/` (`admin/lib/features/cards/payment_card_visual.dart`):
la plantilla en blanco `assets/images/card_black_template.png` con el
número enmascarado, el nombre del Tarjetahabiente y la vigencia dibujados
encima, más una insignia de estado en la esquina. Es código duplicado
(ADR-0002: `admin/` y `cardholder/` no comparten runtime), pero el
**diseño no diverge** — una tarjeta debe verse igual sin importar desde
qué app se mire. El saldo se muestra aparte, nunca sobre la tarjeta
misma (una tarjeta física real tampoco lo hace) — mismo criterio que
`admin/lib/features/cards/card_detail_view.dart`. Es la misma decisión
de "portal bancario, no una extensión de la consola administrativa" del
objetivo de este documento, aplicada a la interfaz y no solo a las
reglas de negocio.

## Reglas de negocio
Ver `docs/business/autoservicio-tarjetahabiente.md` — no se repiten aquí.

## Casos borde / fuera de alcance
- Recuperación de contraseña (una vez ya activada): fuera de alcance de
  esta iteración, igual que en `docs/feature/login-administrativo/` — la
  activación solo resuelve el caso de "nunca la ha puesto".
- Notificar automáticamente al Tarjetahabiente que ya puede activar su
  cuenta: fuera de alcance, no hay infraestructura de mensajería en el
  proyecto — ver `docs/adr/0019-cardholder-self-activation.md`.
- MFA: fuera de alcance, ver nota en el doc de negocio.
- Notificaciones (push/email) de movimientos: fuera de alcance.
- Descargar/exportar el estado de cuenta (PDF, CSV): fuera de alcance de
  esta primera versión — el resumen de periodo en pantalla cubre el "más
  bancario" pedido, exportar es una extensión futura.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
