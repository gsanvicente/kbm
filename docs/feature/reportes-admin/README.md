# Reportes (staff) — Pagos SPEI, Depósitos, Beneficiarios de Pago y Movimientos

- Estado: Implementado (`ReportesSection`, `admin/lib/features/reportes/reportes_section.dart`), incluidos los filtros de Cliente/periodo/monto/banco/alerta, la descarga PDF por pestaña, y la pestaña "Movimientos" centralizada descritos abajo — ver `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`, `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md` y `docs/adr/0026-pestana-movimientos-centralizada-en-reportes.md`.
- ADR/TDR relacionados: `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`,
  `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md` (descarga PDF por pestaña),
  `docs/adr/0026-pestana-movimientos-centralizada-en-reportes.md` (pestaña "Movimientos"),
  `docs/adr/0021-conector-spei.md`, `docs/adr/0020-cuenta-individual-tarjetahabiente.md`,
  `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1, 2, 17 y 18
  (control de acceso, fuga de datos entre tenants, fraude/PLD en SPEI, la
  bandera de CLABE compartida que sí cruza tenants a propósito)
- Roles/actores involucrados: cualquier rol de staff dentro de su
  alcance, incluido Auditor (solo lectura) — "Revelar CLABE completa" en
  la pestaña Beneficiarios queda restringido a `canManageCardholders`
  (Admin Cliente + Super Admin), ver "Quién ve esto"

## Objetivo
Darle a staff (no solo al Tarjetahabiente) visibilidad histórica sobre
los pagos SPEI, los depósitos SPEI, y los Beneficiarios de Pago que sus
Tarjetahabientes registran — necesario tanto para soporte/operación del
día a día como para revisión de cumplimiento (PLD/AML), ver ADR-0022.

## Contexto / motivación
Hasta ahora, todo lo de SPEI (CLABE, Beneficiarios, pagos, depósitos)
vivía exclusivamente del lado del Tarjetahabiente (`cardholder/`); staff
solo veía la cola de pagos `pending_approval` (pestaña "Pagos SPEI" del
hub "Aprobaciones", para poder aprobar/rechazar). No existía ningún
historial completo, ningún reporte de depósitos, y los Beneficiarios de
Pago eran 100% invisibles para staff (404 explícito). El negocio pidió
corregir esto explícitamente por dos motivos: soporte (poder ver qué
pasó con un pago sin pedirle capturas de pantalla al Tarjetahabiente) y
cumplimiento (poder revisar a quién se le paga, y detectar patrones de
posible cuenta mula — la misma CLABE externa registrada por
Tarjetahabientes distintos).

## Nota de alcance de esta iteración
- Esta sección sigue sin botones de acción **sobre un pago o
  beneficiario** (aprobar/rechazar sigue viviendo solo en
  "Aprobaciones"; registrar un Beneficiario sigue siendo 100% del
  Tarjetahabiente) — la única acción sobre un registro es "Revelar
  CLABE completa" en Beneficiarios. "Descargar" (ver ADR-0024) es una
  exportación de la lista ya filtrada, no una acción sobre un registro.
- Sin paginación de servidor en esta primera pasada — se trae la lista
  completa dentro del alcance de quien consulta y se filtra
  client-side, mismo criterio que ya usan las listas globales de
  Tarjetahabientes/Tarjetas (`docs/feature/listado-global-tarjetahabientes/`).
  Se reconsidera si el volumen de datos lo amerita.
- El filtro de periodo es por presets ("Este mes" / "Últimos 30 días" /
  "Últimos 90 días" / "Todo el historial", `PeriodFilter` en
  `admin/lib/shared_widgets/period_filter.dart`, compartido con el
  Estado de cuenta para directivos), no un selector de rango de fechas
  del lado servidor — todo el filtrado es client-side sobre la lista ya
  cargada, mismo criterio que `MovementsTab` en `cardholder/`.
- **Descargar** (PDF con branding de KBM/Koons, ver
  `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md`): cada pestaña
  exporta exactamente la lista ya filtrada en pantalla, usando el
  builder genérico `buildReportPdf` (`shared_widgets/pdf_statement.dart`)
  — distinto del `buildStatementPdf` de un estado de cuenta, porque un
  reporte es una tabla de columnas libres sin saldo único. El bloque de
  identificación incluye "Generado por" y un resumen de "Filtros
  activos". Corrige el alcance original de ADR-0022 punto 6, que decía
  que estas tres pestañas no tendrían exportación.

## Quién ve esto
Cualquier rol de staff dentro de su alcance jerárquico normal
(`docs/business/roles-and-permissions.md`, "Herencia sobre la jerarquía
padre/hija") ve las cuatro pestañas, **incluido Auditor** — mismo
criterio que ya rige ver Tarjetahabientes/Tarjetas/Tesorería. La única
excepción es el botón "Revelar CLABE completa" dentro de la pestaña
Beneficiarios, restringido a `canManageCardholders` (Admin Cliente +
Super Admin); Operador y Auditor ven la fila con la CLABE enmascarada,
sin ese botón. (La pestaña "Movimientos" no agrega ninguna excepción
nueva: solo expone lectura que esos roles ya tenían desde el detalle de
cada entidad — ver ADR-0026.)

## Alcance de datos por rol
Mismo mecanismo que el resto de la plataforma:
`ClientRepository.listAccessibleClients(session)` resuelve el Cliente
propio + descendientes (Super Admin: todo el sistema). Las tres listas
de este documento, y los candidatos de búsqueda de la pestaña
"Movimientos" (Clientes y Tarjetahabientes), se piden con esos
`client_ids`, y RLS en Postgres garantiza que ninguna fila fuera de ese
conjunto pueda llegar —
**excepto** la bandera booleana `sharedByMultipleCardholders` de la
pestaña Beneficiarios, que se calcula sin ese filtro a propósito (ver
`docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`, punto 3,
y `docs/security/threat-model.md` punto 18).

## Contenido de la pantalla

### Pestaña "Pagos SPEI" (historial completo)
Tabla con: fecha, Tarjetahabiente, Cliente, Beneficiario (alias +
CLABE enmascarada — ver nota de seguridad abajo), monto, estatus
(`pending_approval` / `executed` / `rejected` / `failed`), resuelto por
(si aplica). Filtros: Cliente (oculto si solo hay uno en alcance, mismo
criterio que el resto de la plataforma), estatus, periodo (presets, ver
nota de alcance), monto mínimo, búsqueda de beneficiario por alias
(texto libre). A diferencia de la cola de "Aprobaciones" (solo
`pending_approval`, con botones de acción), esto es de solo lectura y
cualquier estatus. Botón "Descargar" (ver ADR-0024) — la CLABE en el PDF
va enmascarada, igual que en pantalla.

**Nota de seguridad:** este endpoint (`GET /v1/spei-payments`) reutiliza
el mismo campo `beneficiaryClabe` que la cola de aprobaciones, pero el
handler del reporte lo enmascara (`dto.FromSPEIPaymentForReport`) antes
de responder — nunca envía la CLABE real en este listado agregado, igual
que el directorio de Beneficiarios. Ver
`docs/security/threat-model.md` punto 18.

### Pestaña "Depósitos SPEI"
Tabla con: fecha, Tarjetahabiente, Cliente, monto, referencia del
proveedor. Mismos filtros de Cliente/periodo/monto que Pagos SPEI, y el
mismo botón "Descargar". Sin concepto de "estatus" — un depósito siempre
llega ya conciliado (ADR-0021, punto 8), no hay nada pendiente que
mostrar aquí.

### Pestaña "Beneficiarios"
Tabla con: alias, CLABE (enmascarada), banco, Tarjetahabiente dueño,
Cliente, fecha de alta, si sigue en periodo de enfriamiento, # de pagos
`executed` hechos a esa CLABE, monto total `executed` acumulado, y un
ícono de alerta cuando `sharedByMultipleCardholders` es `true` (con un
tooltip: "Esta CLABE también está registrada por otro Tarjetahabiente —
revisar posible duplicidad", sin nombrar a quién, ver la nota de alcance
del ADR sobre no filtrar el otro registro). Filtros: Cliente, búsqueda
de Tarjetahabiente por nombre (texto libre, sin autocompletar), banco
(oculto si solo hay uno entre los resultados), y un chip "Solo con
alerta activa". Botón "Revelar CLABE completa" por fila (gate de rol,
ver "Quién ve esto") — cada uso escribe `audit_log`
(`spei_beneficiary_clabe_revealed`). Botón "Descargar": exporta la
CLABE tal cual la muestra cada fila en ese momento — enmascarada por
default, completa solo en las filas que ya se revelaron antes de
descargar (ver ADR-0024).

### Pestaña "Movimientos" (búsqueda centralizada de estados de cuenta)
No es un reporte tabular como las tres anteriores — es una puerta de
entrada centralizada a los estados de cuenta que **ya existían**
dispersos en el detalle de cada entidad (Tesorería de un Cliente, Cuenta
Individual de un Tarjetahabiente, Movimientos de una Tarjeta). Ver
`docs/adr/0026-pestana-movimientos-centralizada-en-reportes.md` para el
diseño completo.

- Selector de alcance: **Tarjetahabiente** (default) o **Cliente
  (Concentradora)**.
- **Tarjetahabiente**: buscar por nombre dentro del alcance de la
  sesión. Muestra su Cuenta Individual completa (saldo, movimientos,
  "Descargar") y, debajo, una fila expandible por cada una de sus
  tarjetas — abrirla muestra/descarga los movimientos de *esa* tarjeta
  puntual, por separado de la Cuenta Individual completa.
- **Cliente (Concentradora)**: buscar por nombre de Cliente dentro del
  alcance de la sesión. Muestra su Estado de cuenta (resumen, filtro de
  periodo, movimientos, "Descargar") — mismo dato que la pestaña
  "Tesorería" de ese Cliente.
- Todos los PDF que se generan aquí son idénticos, byte por byte en su
  diseño, a los que genera la pantalla de detalle correspondiente —
  reutilizan el mismo `buildStatementPdf` (ADR-0023), nunca un tercer
  formato.
- Esta pestaña **no reemplaza** los botones de descarga en el detalle de
  Cliente/Tarjetahabiente/Tarjeta — ambos caminos coexisten a propósito,
  ver ADR-0026.

## Reglas de negocio
No se introduce ninguna regla de negocio nueva sobre cómo se registra un
Beneficiario o se procesa un pago/depósito — todo eso sigue gobernado
por `docs/adr/0021-conector-spei.md` sin cambios. Las únicas reglas
propias de este documento son de **visibilidad**:
ver `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` y
`docs/business/roles-and-permissions.md`.

## Casos borde / fuera de alcance
- Editar o eliminar un Beneficiario desde `admin/`: fuera de alcance —
  staff nunca actúa sobre el registro de un Beneficiario, solo lo
  consulta. Si el negocio pide esto después, es una decisión nueva, no
  una extensión trivial de este documento.
- Aprobar/rechazar un pago desde esta sección: no aplica aquí, sigue
  siendo exclusivo del hub "Aprobaciones".
- Notificar automáticamente a alguien cuando aparece una alerta de CLABE
  compartida (correo, ticket, etc.): fuera de alcance — es un ícono
  pasivo que staff debe encontrar revisando la pestaña, no un sistema de
  alertas activo. No hay infraestructura de mensajería en el proyecto
  (mismo motivo que otras notificaciones pendientes, ver
  `docs/adr/0019-cardholder-self-activation.md`).
- Umbral configurable para qué cuenta como "monto alto" o "muchos
  pagos" en la pestaña Beneficiarios: no existe ningún umbral así en
  esta iteración — la única señal automática es la CLABE compartida
  (booleana, sin configuración). Un scoring o umbral de PLD real
  requiere un proveedor SPEI elegido (ADR-0021, "Fuera de alcance").
- Ver el historial de "quién reveló qué CLABE": la fila queda en
  `audit_log`, pero no hay una pantalla dedicada para consultarlo en
  esta iteración — se consulta directo en la base de datos si hace
  falta.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
