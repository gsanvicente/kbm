# Tesorería del Cliente (Cuenta Concentradora / Cuenta Colectora)

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1, 2, 4 y 10
- Roles/actores involucrados: Operador de Saldos (registra depósitos), Admin Cliente/Super Admin (concilian), Auditor (solo ve)

## Objetivo
Dar a cada Cliente su propia Cuenta Concentradora (el pool real que
respalda las Dispersiones/Deducciones de sus tarjetas) y su propia Cuenta
Colectora (punto de entrada para depósitos externos, con un paso de
conciliación antes de que el dinero esté disponible) — ver
`docs/business/tesoreria-cliente.md` para el porqué de estos dos
conceptos y cómo se relacionan.

## Contexto / motivación
Sin esto, una Dispersión "crea" saldo sin ninguna fuente. Esta feature le
da una fuente real (aunque todavía manual, sin banco conectado) y hace
que `docs/feature/operacion-saldo-con-aprobacion/` valide fondos también
del lado del Cliente, no solo de la tarjeta.

## Nota de alcance de esta iteración
- Repositorio fake (`TreasuryRepository`), mismo patrón que
  `LedgerRepository`/`BalanceOperationRepository` — sin backend real ni
  conexión bancaria.
- Una Concentradora y una Colectora por Cliente, sin consolidación entre
  empresa padre e hijas (ver "Alcance" en `docs/business/tesoreria-cliente.md`).
- No hay forma de rechazar/descartar un depósito ya registrado, ni de
  retirar dinero de la Concentradora — ver "Fuera de alcance" en el doc
  de negocio.

## Dónde vive esto en la UI
Cada Cliente ahora tiene su propia pantalla de detalle (antes, hacer clic
en un Cliente llevaba directo a su listado de Tarjetahabientes) con dos
pestañas, **Tesorería primero** (2026-09-19: se invirtió el orden
original — el dinero es la pregunta más frecuente al entrar al detalle
de una empresa, y mantiene la misma jerarquía de información que el
Panel directivo, que también lidera con cifras antes que con personas):
- **Tesorería**: muestra el saldo de la Concentradora, y dos secciones:
  - Historial de movimientos de la Concentradora (créditos por
    Deducciones/conciliaciones, débitos por Dispersiones).
  - Lista de depósitos de la Colectora (pendientes y conciliados), con
    un botón "Registrar depósito" y, por cada depósito pendiente, un
    botón "Conciliar" — ambos gateados por rol (ver más abajo).
- **Tarjetahabientes**: el listado y flujo que ya existía
  (`docs/feature/tarjetahabientes-por-cliente/`), sin cambios.

## Flujo principal
1. Un Operador (o Admin Cliente/Super Admin) con alcance sobre el Cliente
   entra a la pestaña "Tesorería" y pulsa "Registrar depósito": captura
   monto y una referencia/folio (texto libre, simula el dato que traería
   un comprobante bancario real).
2. El depósito aparece en la lista de la Colectora en estado "Pendiente"
   — el saldo de la Concentradora **no cambia todavía**.
3. Un Admin Cliente o Super Admin revisa el depósito pendiente y pulsa
   "Conciliar" — se le pide confirmar antes de aplicarlo (ver
   `docs/business/confirmaciones-de-accion.md`, no hay forma de deshacer
   una vez conciliado). El depósito pasa a "Conciliado" y el saldo de la
   Concentradora aumenta por ese monto — recién ahí queda disponible
   para Dispersiones.
4. Desde ese momento, una Dispersión sobre cualquier tarjeta de ese
   Cliente puede usar ese saldo (ver
   `docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
   "Flujo principal" y "Fondos insuficientes").

## Quién puede hacer qué
Ver la tabla en `docs/business/roles-and-permissions.md`, sección
"Tesorería del Cliente". Resumen: ver (todos), registrar depósito
(Operador+), conciliar (Admin Cliente+).

## Dos entry points para conciliar (revisado 2026-09-17)
Conciliar un depósito (mismo `TreasuryRepository.reconcileDeposit`, sin
duplicar lógica) está disponible desde **dos lugares**, a propósito:
1. **Tesorería del Cliente** (aquí mismo) — el lugar natural cuando ya
   estás revisando la Tesorería de una empresa específica, sin tener que
   salir a otra sección para actuar sobre lo que ya estás viendo.
2. **Pestaña "Depósitos por conciliar" del hub "Operaciones de saldo"**
   (`docs/feature/operacion-saldo-con-aprobacion/README.md`) — vista
   agregada de todos los depósitos pendientes en el alcance del usuario,
   entre todos sus Clientes, con un hipervínculo directo desde "Requiere
   tu atención" en el Panel directivo
   (`docs/feature/panel-directivo/README.md`).

No es una inconsistencia: es el mismo patrón que un inbox de correo
(archivar desde la bandeja o desde el mensaje abierto) — misma acción,
dos superficies según si estás explorando (el hub, entre Clientes) o
operando en contexto (Tesorería, un Cliente a la vez).

## Indicador de saldo en el encabezado (revisado 2026-09-19)
El encabezado (barra superior) muestra el saldo de la Cuenta
Concentradora entre el título de la sección actual y el bloque de
usuario, **solo para Admin Cliente** — puramente informativo, sin acción
ni navegación asociada (no es un botón).

- **Por qué solo Admin Cliente, no Super Admin:** el indicador muestra la
  Concentradora de `session.clientId`. Admin Cliente siempre tiene una
  empresa propia; Super Admin no (`session.clientId` es `null` — ver
  `core/models/session.dart`) y hoy no existe ninguna cuenta que le
  pertenezca directamente a él para mostrar ahí. Ver "Visión futura:
  cuenta raíz de Koons con comisión" en
  `docs/business/tesoreria-cliente.md` — cuando esa cuenta exista, ese es
  el momento de decidir qué ve Super Admin aquí, no antes.
- **No se refresca en vivo**: se obtiene una vez al iniciar sesión. Si se
  hace una Dispersión/Deducción/conciliación en otra pantalla durante la
  misma sesión, el número del encabezado no se actualiza solo — hay que
  volver a iniciar sesión para verlo al día. Aceptable para un indicador
  "solo informativo"; si más adelante se necesita en vivo, es un cambio
  aparte.
- Operador y Auditor no ven este indicador en absoluto, aunque sí pueden
  ver el detalle completo de Tesorería desde Clientes.

## Cliente inactivo (nuevo, 2026-09-17)
Ni `registerDeposit` ni `reconcileDeposit` se ejecutan si el Cliente (o
un ancestro suyo) está inactivo — mismo criterio y mismo motivo que en
`docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
"Cliente inactivo": cubre tanto al propio staff (bloqueado desde el
login) como a un ancestro que ya tenía sesión iniciada. Ver
`docs/business/desactivacion-de-clientes.md`.

## Reglas de negocio
Ver `docs/business/tesoreria-cliente.md` y
`docs/business/desactivacion-de-clientes.md` — no se repiten aquí.

## Casos borde / fuera de alcance
- Integración bancaria real (SPEI, webhooks): fuera de alcance, registrar
  un depósito es 100% manual en esta iteración.
- Rechazar/descartar un depósito `pending`: fuera de alcance.
- Retirar dinero de la Concentradora hacia fuera de KBM: fuera de
  alcance.
- Consolidación de Concentradoras entre empresa padre e hijas: fuera de
  alcance, cada Cliente tiene la suya de forma independiente.
- Notificaciones cuando se concilia un depósito: fuera de alcance.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
