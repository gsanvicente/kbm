# ADR-0022: Reportes para staff, estado de cuenta descargable, y corrección de visibilidad de Beneficiarios de Pago

- Estado: Aceptada — **corregida parcialmente por
  `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md`**: el punto 6
  ("Descarga de movimientos") ya no genera CSV, genera PDF con branding
  de la plataforma (ver ese ADR); y por
  **`docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md`**: el punto 4
  ya no dice que las tres pestañas de Reportes son "solo consulta, sin
  descarga" — ahora sí tienen botón de exportación. Todo lo demás de
  esta decisión sigue vigente sin cambio.
- Fecha: 2026-09-24

## Contexto
Al validar `docs/adr/0021-conector-spei.md` contra el documento de
referencia original ("Referencia App Móvil Plataforma Bancaria") se
encontraron dos huecos, ya corregidos ahí (ver su sección "Notas de
implementación"): el comprobante propio y el saldo de Cuenta sin
tarjeta. El mismo ejercicio de validación dejó pendientes dos temas que
el documento de referencia también pide ("Reportes y consultas") y que
el negocio confirmó explícitamente que quiere:

1. **Reportes para staff** — hoy `admin/` no tiene ninguna vista de
   historial completo de pagos SPEI, depósitos SPEI, ni de los
   Beneficiarios de Pago que los Tarjetahabientes registran. Tampoco
   existe un reporte a nivel Cuenta Concentradora/Colectora pensado para
   un directivo (hoy solo existe la pestaña "Tesorería" dentro de la
   ficha de **un** Cliente a la vez, sin vista agregada).
2. **Visibilidad de Beneficiarios de Pago** — ADR-0021 decidió que un
   Beneficiario de Pago es 100% privado del Tarjetahabiente (staff recibe
   404 al intentar verlo). El negocio pidió reconsiderar esto
   explícitamente por razones de **PLD/AML**: SPEI mueve dinero real
   fuera del ecosistema KBM, y un programa de cumplimiento real necesita
   que la institución (no solo el usuario) pueda revisar a quién se le
   está pagando — en particular, detectar la misma CLABE externa
   registrada por Tarjetahabientes distintos (señal clásica de cuenta
   mula).
3. **Descarga de movimientos** — el negocio pidió poder descargar el
   estado de cuenta de una Cuenta Individual, tanto desde el propio
   portal del Tarjetahabiente como desde `admin/`.

Este ADR depende de `docs/adr/0020-cuenta-individual-tarjetahabiente.md`
y `docs/adr/0021-conector-spei.md` — reutiliza sus tablas y conceptos sin
cambiarlos, salvo el punto de visibilidad que corrige explícitamente.

## Decisión

### 1. Corrección a ADR-0021: los Beneficiarios de Pago dejan de ser 100% privados
**Regla de visibilidad: exactamente la misma que ya rige a un
Tarjetahabiente** (`docs/business/roles-and-permissions.md`, "Herencia
sobre la jerarquía padre/hija") — no una regla nueva. Concretamente:

- **Lectura**: cualquier rol de staff (incluido Auditor) puede ver los
  Beneficiarios de Pago de cualquier Tarjetahabiente dentro de su
  alcance (su Cliente + descendientes para Admin Cliente/Operador/
  Auditor con Cliente propio; todo el sistema para Super Admin) —
  mismo criterio exacto que ya aplica para ver las tarjetas o el saldo
  de ese Tarjetahabiente.
- **Escritura sigue siendo 100% del Tarjetahabiente**: registrar un
  Beneficiario, editarlo (todavía no existe editar, ver "Fuera de
  alcance") o iniciar un pago SPEI **nunca** lo hace staff en nombre de
  alguien — eso no cambia. Ver ADR-0021, punto 5 ("quién origina un
  pago"), que sigue vigente sin modificación.
- En términos de código: los endpoints de **lectura** ya existentes
  bajo `/v1/cardholders/{id}/...` (CLABE, beneficiarios, pagos,
  depósitos, saldo de Cuenta) pasan de `requireSelfCardholder` (solo el
  propio Tarjetahabiente) a **`requireSelfOrStaff`**: el propio
  Tarjetahabiente sigue viéndolos igual que hoy, y ahora también
  cualquier staff con alcance sobre ese Tarjetahabiente — mismo patrón
  que ya usa `getCard`/`getLedger` (`internal/adapters/http/handler/handler.go`)
  para tarjetas. Los endpoints de **escritura**
  (`EnsureCLABE`/`RegisterBeneficiary`/`CreatePayment`) permanecen
  `requireSelfCardholder`, sin cambio.

### 2. Dos formas de ver Beneficiarios, con distinto criterio de exposición de CLABE
No es la misma pantalla ni el mismo riesgo ver **un** registro que ver
**todos**:

- **Ficha individual** (`CardholderDetailView`, un Tarjetahabiente a la
  vez — reusa `GET /v1/cardholders/{id}/beneficiaries` ya relajado
  arriba): muestra la **CLABE completa**, mismo criterio que esa misma
  pantalla ya usa para RFC/CURP/domicilio del Tarjetahabiente — no tiene
  sentido enmascarar un dato mientras el resto de su expediente KYC se
  ve completo al lado.
- **Reporte agregado / directorio** (`GET /v1/spei-beneficiaries`, todos
  los Beneficiarios dentro de alcance, potencialmente cientos de filas,
  pensado para poder filtrar/exportar): la CLABE se muestra
  **enmascarada por default** (mismo formato `••••1234` que ya usa
  `Beneficiary.maskedClabe` en `cardholder/`). Una acción explícita
  "Revelar CLABE completa" por fila hace `POST
  /v1/spei-beneficiaries/{id}/reveal`, devuelve la CLABE completa, y
  **queda auditada** (`audit_log`, acción
  `spei_beneficiary_clabe_revealed`, actor + beneficiario). Un listado
  masivo es un vector de fuga categóricamente distinto a una ficha
  individual (se puede raspar/exportar de un jalón), de ahí el
  candado adicional solo aquí.
- **Quién puede usar "Revelar"**: `canManageCardholders` (Admin
  Cliente + Super Admin) — el mismo umbral que ya gobierna otras
  acciones sensibles sobre el expediente de un Tarjetahabiente. Operador
  y Auditor ven la fila enmascarada, sin el botón de revelar.

### 3. Reporte agregado de Beneficiarios: datos + actividad + señal de patrón
Cada fila de `GET /v1/spei-beneficiaries?client_ids=...` trae:
- Alias, CLABE (enmascarada, ver arriba), banco, Tarjetahabiente dueño,
  Cliente, fecha de alta.
- **Actividad real**: cuántos pagos `executed` se le han hecho y la suma
  de esos montos — nunca cuenta intentos `pending_approval`/`rejected`/
  `failed`, solo dinero que de verdad salió. Calculado con un `JOIN`/
  agregado contra `spei_payments` agrupado por `beneficiary_id`.
- **Bandera `sharedByMultipleCardholders`**: `true` si la misma CLABE
  (`payment_beneficiaries.clabe`) aparece registrada por **más de un**
  `cardholder_id` distinto — **calculada globalmente, sin respetar el
  alcance de RLS del que consulta**. Es la única parte de este ADR que
  cruza el aislamiento normal entre tenants a propósito: un Admin
  Cliente debe poder saber que "esta CLABE también la registró alguien
  más" aunque ese alguien más pertenezca a un Cliente que no puede ver.
  Nunca se expone **qué** Cliente/Tarjetahabiente es el otro registro,
  solo el hecho booleano — el resto de la fila (alias, banco, montos)
  sigue estrictamente acotado al alcance normal. Ver
  `docs/security/threat-model.md` punto 18 para el análisis de riesgo
  de esta única excepción deliberada.

### 4. Nueva sección "Reportes" en `admin/`
Separada del hub "Aprobaciones" (que sigue siendo "cosas que requieren
tu acción"): "Reportes" es "consultas históricas", mismo lenguaje que
usa el documento de referencia ("Reportes y consultas"). Visible para
cualquier rol de staff (alcance normal por jerarquía), con 3 pestañas de
solo lectura:
1. **Pagos SPEI** — historial completo (`GET /v1/spei-payments?client_ids=...`,
   nuevo endpoint; el existente `/v1/spei-payments/pending` no cambia,
   sigue siendo el que alimenta la cola de aprobación en "Aprobaciones").
   Cualquier estatus, filtros por Cliente/estatus/rango de fecha/monto/
   beneficiario.
2. **Depósitos SPEI** — `GET /v1/spei-deposits?client_ids=...` (nuevo;
   distinto del endpoint self-only `/v1/cardholders/{id}/spei-deposits`
   que ya existe para el propio Tarjetahabiente). Mismos filtros.
3. **Beneficiarios** — el directorio descrito en los puntos 2 y 3
   arriba.

### 5. Estado de cuenta de Tesorería (Concentradora + Colectora), para directivos
Vive dentro de la pestaña "Tesorería" ya existente de cada Cliente
(`docs/feature/tesoreria-cliente/`), no en la sección "Reportes" nueva —
es una extensión natural de una pantalla que ya existe, no un concepto
nuevo. Gate de rol: `canViewExecutiveDashboard` (Admin Cliente + Super
Admin), igual que el Panel directivo — Operador y Auditor no la ven,
consistente con que esto es explícitamente "para directivos".

Formato: **resumen arriba, detalle expandible abajo**, por cada Cliente
dentro de alcance (una fila de resumen por Cliente/filial: total
dispersado, total conciliado desde Colectora, saldo actual de
Concentradora; expandir revela el detalle línea por línea, cronológico,
mezclando `ConcentratorEntry` y `CollectorDeposit` conciliados — un solo
estado de cuenta, no dos listas separadas). Nuevo endpoint `GET
/v1/clients/{clientId}/treasury/statement` para el detalle de un
Cliente; el resumen por fila reutiliza datos que `TreasuryRepository` ya
expone hoy (saldo de Concentradora, depósitos), sin endpoint nuevo para
eso.

### 6. Descarga de movimientos — enteramente client-side, sin endpoint nuevo
La exportación (CSV) de movimientos de una Cuenta Individual, y del
estado de cuenta de Tesorería, se construye **en Flutter, a partir de
los datos que la pantalla ya cargó** — no hace falta ningún endpoint de
exportación dedicado, es el mismo dato que ya se muestra en pantalla,
solo en otro formato de salida. Mismo criterio que ya usa
`MovementsTab` (`cardholder/`) para su filtro de periodo: todo
client-side sobre la lista ya obtenida, "Descargar" exporta exactamente
lo que el filtro activo está mostrando en ese momento (si hay un rango
de fechas seleccionado, se descarga ese rango, no todo el historial).

Disponible en ambos lados:
- **`cardholder/`**: botón "Descargar estado de cuenta" en la pestaña
  "Cuenta" (`SpeiSection`), sobre los movimientos que devuelve
  `GetAccountLedger`.
- **`admin/`**: mismo botón en la ficha del Tarjetahabiente (o de la
  tarjeta, para su `Movimientos`), sobre los mismos datos que esa
  pantalla ya muestra — disponible ahora que el punto 1 de este ADR le
  da a staff acceso de lectura a `GetAccountLedger` de cualquier
  Tarjetahabiente en su alcance.

Formato del archivo: CSV UTF-8, delimitado por comas, encabezado en
español (`Fecha,Tipo,Descripción,Monto,Saldo`), fecha en
`YYYY-MM-DD HH:mm`, monto como número decimal plano (sin símbolo de
moneda ni separador de miles) para que abra limpio en Excel/Sheets sin
reformatear. Nombre de archivo sugerido:
`estado-de-cuenta-{cardholderId}-{fecha}.csv`.

## Consecuencias
- **Excepción deliberada al aislamiento entre tenants** (punto 3, la
  bandera `sharedByMultipleCardholders`): es la única parte de todo el
  proyecto donde una consulta de un Cliente se ve afectada por datos de
  otro Cliente que no puede ver. Se documenta explícitamente aquí y en
  `docs/security/threat-model.md` punto 18 para que nunca se trate como
  un bug de RLS a "corregir" después.
- **`docs/adr/0021-conector-spei.md` queda parcialmente corregido**: su
  diseño original (Beneficiario 100% privado) ya no aplica; ese
  documento se actualiza con una nota apuntando aquí, sin reescribir su
  contexto original (la decisión fue correcta con la información que
  había entonces).
- **Nuevo trabajo de backend**: `GET /v1/spei-payments` (historial
  completo), `GET /v1/spei-deposits` (cross-cliente), `GET
  /v1/spei-beneficiaries` (directorio agregado, con el `JOIN` de
  actividad y la bandera global), `POST
  /v1/spei-beneficiaries/{id}/reveal`, `GET
  /v1/clients/{clientId}/treasury/statement`, y relajar
  `requireSelfCardholder` → `requireSelfOrStaff` en los endpoints de
  lectura de SPEI ya existentes.
- **Cero endpoints nuevos para exportar** — ver punto 6, es una
  simplificación real de alcance, no una promesa optimista.
- **Riesgo regulatorio**: esto ayuda al programa de PLD/AML pero no lo
  resuelve — sigue sin existir verificación real contra listas
  PLD/OFAC/SAT (ver ADR-0021, "Consecuencias", sin cambio). Este ADR da
  a un humano de cumplimiento las herramientas para revisar
  manualmente, no una verificación automática.

## Alternativas consideradas
- **Restringir el directorio de Beneficiarios solo a Super Admin**:
  descartado — el negocio pidió explícitamente el mismo criterio
  jerárquico que ya rige Tarjetahabientes, no uno más estricto. Un
  Admin Cliente necesita poder revisar a sus propios Tarjetahabientes
  sin escalar cada caso a Super Admin.
- **Mostrar la CLABE completa siempre, sin enmascarar en el directorio
  agregado**: descartado — un listado masivo exportable es un vector de
  fuga distinto a una ficha individual; enmascarar por default con una
  acción auditada de "revelar" da la misma utilidad con menor
  exposición pasiva.
- **Calcular la bandera de CLABE compartida solo dentro del alcance de
  quien consulta** (nunca cruzar tenants): descartado — anularía el
  propósito de la señal (un atacante organizado reparte sus cuentas
  mula entre Clientes distintos a propósito). Se acepta la fuga mínima
  de un booleano como costo deliberado, nunca los datos del otro
  registro.
- **Endpoint de exportación server-side (genera el CSV en Go)**:
  descartado por innecesario — el dato ya viaja completo al cliente
  para pintar la pantalla; regenerarlo en el backend solo para cambiar
  el formato de salida es trabajo redundante. Se reconsideraría si algún
  reporte llegara a ser demasiado grande para cargarse completo en el
  navegador, lo cual no aplica al volumen actual de ningún Cliente.
- **Reporte de Tesorería como sección nueva, separada de la ficha del
  Cliente**: descartado — la pestaña "Tesorería" ya existe justo para
  esto; crear una pantalla paralela hubiera duplicado navegación sobre
  el mismo dato, mismo error que ya se corrigió una vez fusionando
  "Operaciones de saldo" dentro de "Aprobaciones".

## Ver también
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md`
- `docs/adr/0021-conector-spei.md` — corregido parcialmente por este ADR.
- `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` — corrige el
  punto 6 (CSV → PDF con branding de la plataforma).
- `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md` — corrige el
  punto 4 (Reportes sí tienen descarga) y agrega descarga a nivel de una
  tarjeta individual.
- `docs/business/roles-and-permissions.md`
- `docs/business/tesoreria-cliente.md`
- `docs/business/autoservicio-tarjetahabiente.md`
- `docs/security/threat-model.md` punto 18.
- `docs/feature/reportes-admin/README.md`
- `docs/feature/tesoreria-cliente/README.md`
