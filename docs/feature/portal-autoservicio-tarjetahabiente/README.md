# Portal de autoservicio del Tarjetahabiente

- Estado: **Parcialmente implementado** (2026-09-19) — login, detalle de
  tarjeta (saldo + Transferir) y ahora también Movimientos (lista de la
  cuenta, sin filtro de fechas) existen en `cardholder/`, con una
  navegación persistente (rail en pantallas anchas, barra inferior en
  angostas) en vez de una sola pantalla suelta — ver "Diseño" más abajo.
  Filtro de fechas/resumen de periodo, Congelar/Descongelar y Reclamos
  (puntos en "Pantallas" más abajo) siguen sin implementarse.
- ADR/TDR relacionados: `docs/adr/0002-flutter-web-mobile-two-apps.md`,
  `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`,
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 6, 11 y 12
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
- Repositorio fake, mismo patrón que `admin/` — sin backend real. Vive en
  una sola clase, `FakeCardholderBackend` (implementa las tres interfaces
  de auth/tarjetas/transferencias a la vez) — ver "Nota de alcance" en
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

## Pantallas / flujo principal
1. **Login** — email + contraseña. **Implementado.**
2. **Inicio / selector de tarjeta** (si tiene más de una) — **implementado**,
   saldo y estado de cada tarjeta.
3. **Dentro de una tarjeta** (pestañas "Inicio" y "Movimientos" del
   mismo marco de navegación, ver "Diseño"):
   - **Inicio**: tarjeta (visual, nunca el PAN completo) + saldo actual,
     destacado. **Implementado.**
   - **Movimientos** (lista de la cuenta, más reciente primero):
     **implementado**, sin filtro por rango de fechas ni resumen del
     periodo — eso sigue **pendiente**.
   - Botón **Congelar/Descongelar**: **pendiente**, no construido en esta
     pasada — una tarjeta `blocked` por el staff sí muestra un mensaje de
     "contacta a tu administrador" en vez del botón Transferir, pero el
     propio autocongelamiento del Tarjetahabiente no existe todavía.
   - Botón **Transferir** — **implementado**, ver
     `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.
   - Presentar un reclamo por movimiento: **pendiente** — ya hay
     movimientos individuales que reclamar (punto anterior), pero la
     acción en sí no está construida.

## Diseño
El portal usa un marco de navegación persistente una vez dentro de una
tarjeta (`CardholderShell`): un `NavigationRail` en pantallas anchas
(≥900px, web/desktop) o una `NavigationBar` inferior en angostas
(móvil), con dos destinos — Inicio y Movimientos — en vez de pantallas
sueltas sin relación visual entre sí.

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
