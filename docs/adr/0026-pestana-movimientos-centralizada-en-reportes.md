# ADR-0026: Pestaña "Movimientos" centralizada en Reportes, y corrección de `clientId` faltante en Pagos SPEI

- Estado: Aceptada
- Fecha: 2026-09-25

## Contexto
Dos hallazgos de una revisión en vivo de "Reportes" > "Pagos SPEI":

1. **Bug real**: la pestaña tronaba con `TypeError: null: type 'Null' is
   not a subtype of type 'String'` al cargar cualquier pago histórico.
   Causa: `dto.SPEIPayment` (`backend/internal/adapters/http/dto/dto_spei.go`)
   nunca tuvo un campo `ClientID` — un descuido real de cuando se agregó
   el filtro de Cliente a esta pestaña (ver ADR-0024) — así que el JSON
   nunca traía `clientId`, y el parser de Flutter
   (`admin/lib/features/spei/http_spei_repository.dart`) hacía
   `json['clientId'] as String` (cast no-nullable) sobre una clave
   ausente. Nunca se detectó en `flutter test` porque las pruebas usan
   `FakeSpeiRepository` (Dart puro, nunca pasa por JSON real) — el mismo
   punto ciego que ya había dejado pasar el bug de refresco de
   ADR-0025. Corregido agregando `ClientID string \`json:"clientId"\`` a
   la struct y a `FromSPEIPayment`, con dos pruebas nuevas
   (`admin/test/http_spei_repository_test.dart`) que fijan la forma real
   del JSON contra un cliente HTTP mockeado (`http/testing.dart`), no
   contra el fake — para que esta clase de bug truene en CI, no en
   producción.
2. **Pedido de negocio**: los tres puntos de descarga de estado de
   cuenta que introdujeron ADR-0022/0023/0024 (Cliente/Concentradora,
   Tarjetahabiente/Cuenta Individual, Tarjeta/Movimientos) siguen viviendo
   *solo* dentro del detalle de cada entidad — hay que navegar hasta el
   Cliente, o hasta el Tarjetahabiente, o hasta la tarjeta puntual, para
   poder verlos o descargarlos. El negocio pidió que, sin quitar esos
   accesos, **también** se pueda buscar y descargar cualquiera de los
   tres directamente desde "Reportes", como un cuarto tipo de reporte
   más.

## Decisión

### 1. Corrección del bug — ver "Contexto" arriba, ya implementada.

### 2. Nueva pestaña "Movimientos" en Reportes
Cuarta pestaña, junto a Pagos SPEI / Depósitos SPEI / Beneficiarios.
**No reemplaza ningún acceso existente** — Tesorería de un Cliente,
Cuenta Individual de un Tarjetahabiente y Movimientos de una Tarjeta
siguen exactamente donde estaban, con su propio botón de descarga. Esta
pestaña es una **puerta de entrada adicional** al mismo dato, para no
tener que saber de antemano en qué Cliente/Tarjetahabiente vive lo que
se busca.

Un selector (`SegmentedButton`) de dos alcances:
- **Tarjetahabiente**: buscar por nombre (`CardholderSearchField`,
  mismo componente que ya usan los listados globales) dentro del
  alcance de la sesión. Al elegir uno, se ve su Cuenta Individual
  completa (saldo, movimientos, botón Descargar — mismo PDF que ya
  genera `CardholderDetailView`) y, debajo, una lista expandible **por
  tarjeta**: cada una de sus tarjetas se puede abrir para ver/descargar
  *esos* movimientos puntuales por separado (mismo PDF que ya genera la
  pestaña "Movimientos" de `CardDetailView`, ver ADR-0024) — así
  "tarjetahabientes" y "tarjetas" quedan cubiertos por la misma rama, sin
  un tercer selector de nivel superior que la mayoría de las veces
  estaría de más (casi siempre se busca primero a la persona).
- **Cliente (Concentradora)**: buscar por nombre de Cliente dentro del
  alcance de la sesión. Al elegir uno, se ve su Estado de cuenta
  (resumen, filtro de periodo, movimientos, botón Descargar — mismo PDF
  que ya genera `_ExecutiveStatementSection` en `client_detail_view.dart`,
  ver ADR-0022 punto 5).

**Por qué mostrar la lista en pantalla, no solo un botón de descarga a
ciegas**: las otras tres pestañas de Reportes ya establecen el patrón de
esta sección — buscar, filtrar, *ver*, y opcionalmente descargar. Un
botón de descarga sin nada que mostrar antes habría sido inconsistente
con el resto de la pantalla y de menor valor real: staff normalmente
quiere confirmar visualmente que encontró a la persona/Cliente correcto
antes de bajar un PDF, no descargar a ciegas por nombre.

**Por qué reutilizar `buildStatementPdf` y no crear un tercer builder de
PDF**: el documento que se genera aquí es exactamente el mismo (mismas
columnas, mismo branding, mismos datos de identificación) que ya genera
cada pantalla de detalle — daría el mismo PDF sin importar por dónde se
llegó a él, que es justamente el punto de "centralizar".

## Consecuencias
- `ReportesSection` gana cuatro dependencias nuevas
  (`CardholderRepository`, `CardRepository`, `LedgerRepository`,
  `TreasuryRepository`) que ya existían en `AdminShell` — solo se
  enchufan, no se crea infraestructura nueva.
- No hay cambios de backend para el punto 2 — reutiliza endpoints que ya
  existían (`getAccountLedger`, `getStatement`, `getByCard`+`listEntries`).
- El bug corregido en el punto 1 solo afectaba a "Pagos SPEI"; se
  aprovechó la revisión para auditar el resto de `http_spei_repository.dart`
  contra las DTOs reales del backend (`SPEIDeposit`,
  `BeneficiaryDirectoryEntry`) — no se encontró ningún otro campo
  faltante.

## Alternativas consideradas
- **Un tercer nivel de selector para "Tarjeta" directamente** (buscar
  por PAN sin pasar por un Tarjetahabiente): descartado — nadie busca
  "por número de tarjeta" de memoria; siempre se parte de la persona.
  Queda cubierto igual, un nivel más abajo, dentro de la rama
  Tarjetahabiente.
- **Quitar los botones de descarga de las pantallas de detalle ahora que
  existen aquí centralizados**: descartado explícitamente por el
  negocio — "que se tenga la opción desde el detalle... pero que TODO
  quede TAMBIÉN centralizado". Ambos caminos coexisten a propósito.
- **Agregar pruebas de integración contra un backend real en CI** para
  cerrar el punto ciego que dejó pasar este bug y el de ADR-0025:
  pospuesto — las pruebas de parseo contra un `MockClient` (punto 1)
  cierran el hueco específico encontrado sin el costo de mantener un
  entorno de integración completo en CI; se reconsidera si aparece un
  tercer caso de la misma familia.

## Ver también
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — el
  Estado de cuenta de Tesorería que esta pestaña también expone.
- `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` — el builder
  de PDF que se reutiliza aquí sin cambios.
- `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md` — la descarga
  por tarjeta que esta pestaña también expone.
- `docs/feature/reportes-admin/README.md`
