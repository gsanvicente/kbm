# Tesorería del Cliente (Cuenta Concentradora / Cuenta Colectora)

- Estado: Implementado contra Postgres (`HttpTreasuryRepository` por default — ver `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`; `FakeTreasuryRepository` solo para `flutter test`). La sección "Estado de cuenta para directivos" y la descarga de movimientos (ver más abajo) también están implementadas — ver `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` y `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` (formato PDF).
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`, `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`, `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` (estado de cuenta para directivos), `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` (formato PDF de la descarga)
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1, 2, 4 y 10
- Roles/actores involucrados: Operador de Saldos (registra depósitos), Admin Cliente/Super Admin (concilian, y son los únicos que ven el "Estado de cuenta" para directivos), Auditor (solo ve el detalle operativo, no el estado de cuenta)

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

## Estado de cuenta para directivos (ADR-0022)
Nueva sección dentro de esta misma pestaña "Tesorería"
(`_ExecutiveStatementSection` en `client_detail_view.dart`), **solo
visible para Admin Cliente y Super Admin** (`canViewExecutiveDashboard`,
mismo gate que el Panel directivo) — Operador y Auditor siguen viendo el
detalle operativo de arriba (historial de Concentradora, depósitos de
Colectora) sin cambio, pero no esta sección.

- **Resumen** (una fila por Cliente/filial dentro del alcance de quien
  consulta): total dispersado en el periodo, total conciliado desde
  Colectora en el periodo, saldo actual de Concentradora. Si quien
  consulta no tiene filiales, es una sola fila (su propia empresa). El
  Cliente actual y sus descendientes se calculan del lado del Flutter,
  recorriendo `parentClientId` sobre `listAccessibleClients(session)` —
  no existe un endpoint de "descendientes de un Cliente puntual", y
  agregar uno solo para esto no se justificó frente a filtrar en
  cliente sobre un listado que la sesión ya puede pedir.
- **Filtro de periodo**: preselecciones "Este mes" (default), "Últimos
  30 días", "Últimos 90 días" y "Todo el historial" — recalcula los
  totales del resumen y lo que se ve en el detalle/descarga, nunca el
  saldo puntual de la Concentradora (ese es de "ahora", no de flujo).
- **Detalle expandible**: tocar la fila de un Cliente revela su estado
  de cuenta completo del periodo — lista cronológica de movimientos de
  Concentradora, un solo listado ordenado por fecha. `ConcentratorEntry`
  ya incluye el crédito de cada depósito de Colectora conciliado (lo
  inserta `ReconcileDeposit` al conciliar, ver `treasury.Statement` en
  `backend/internal/domain/treasury/treasury.go`), así que no hace falta
  combinar dos fuentes por separado — combinarlas de nuevo contaría el
  mismo movimiento dos veces. Respaldado por `GET
  /v1/clients/{clientId}/treasury/statement`.
- **Descargar** (PDF con branding de KBM/Koons): construido enteramente
  en Flutter (`shared_widgets/pdf_statement.dart`) a partir del detalle
  ya cargado en pantalla para el periodo activo, sin endpoint de
  exportación dedicado. Lleva encabezado con logo, bloque de
  identificación (Cliente, quién lo generó), saldo actual y periodo
  cubierto, además de la tabla de movimientos — ver
  `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` para el
  diseño exacto del documento.
- Este resumen es de **flujo** (cuánto se movió en el periodo), no
  reemplaza al saldo puntual que ya muestra el resto de esta pestaña —
  mismo distingo que ya hace la gráfica de volumen del Panel directivo
  (`docs/feature/panel-directivo/README.md`, "Volumen de movimientos").

## Descarga de movimientos de una Cuenta Individual (ADR-0022, formato PDF por ADR-0023)
Aparte del estado de cuenta de Tesorería de arriba, staff con alcance
sobre un Tarjetahabiente puede descargar (PDF) los movimientos de su
Cuenta Individual desde la ficha de ese Tarjetahabiente (sección "Cuenta
Individual" en `cardholder_detail_view.dart`) — mismo botón y mismo
criterio "exporta lo que ya está en pantalla" que existe del lado del
propio Tarjetahabiente en `cardholder/`
(`docs/business/autoservicio-tarjetahabiente.md`). Disponible porque
ADR-0022 relaja el acceso de lectura a la Cuenta Individual de
`requireSelfCardholder` a `requireSelfOrStaff` — staff nunca podía ver
esto antes si el Tarjetahabiente no tenía ninguna tarjeta asignada. El
PDF identifica quién lo generó (el email de staff), no solo el titular
de la cuenta — ver `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md`.

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
  alcance, cada Cliente tiene la suya de forma independiente. El "Estado
  de cuenta para directivos" (ver arriba) muestra una fila por
  Cliente/filial, nunca una sola cifra sumada entre todos.
- Notificaciones cuando se concilia un depósito: fuera de alcance.
- Endpoint de exportación server-side para el estado de cuenta: fuera de
  alcance a propósito, ver ADR-0022 punto 6 y ADR-0023 — el PDF se arma
  client-side sobre el mismo dato que ya se cargó para la pantalla.
- Selector de rango de fechas del lado servidor para el estado de
  cuenta: el filtro (si existe en la UI) es client-side sobre la lista
  ya obtenida, mismo criterio que `MovementsTab` en `cardholder/`.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
