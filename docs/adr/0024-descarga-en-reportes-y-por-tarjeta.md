# ADR-0024: Descarga PDF en las pestañas de Reportes, y a nivel de una tarjeta individual

- Estado: Aceptada — **extendida por
  `docs/adr/0026-pestana-movimientos-centralizada-en-reportes.md`**:
  agrega una cuarta pestaña "Movimientos" en Reportes para buscar y
  descargar el Estado de cuenta de un Cliente o la Cuenta Individual/
  tarjetas de un Tarjetahabiente sin tener que navegar a su detalle
  primero; también corrige ahí un bug real (`clientId` faltante en el
  DTO de Pagos SPEI que tronaba la pestaña).
- Fecha: 2026-09-25

## Contexto
Dos correcciones de alcance encontradas durante una revisión visual del
negocio sobre lo ya construido (ADR-0022/ADR-0023):

1. `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`, punto
   6, decía explícitamente que las tres pestañas de "Reportes" (Pagos
   SPEI, Depósitos SPEI, Beneficiarios) eran de **solo consulta**, sin
   exportación — la descarga era exclusiva del estado de cuenta de
   Cuenta Individual y de Tesorería. El negocio corrigió esto: esas tres
   pestañas también necesitan un botón "Descargar".
2. La descarga de estado de cuenta nunca cubrió el nivel de una
   **tarjeta individual** (pestaña "Movimientos" del detalle de una
   tarjeta en `admin/`) — solo existía a nivel Tarjetahabiente (Cuenta
   Individual completa) y a nivel Cliente (Tesorería). El negocio pidió
   agregarlo también ahí.

## Decisión

### 1. Descarga en las tres pestañas de Reportes
Cada pestaña (Pagos SPEI, Depósitos SPEI, Beneficiarios) obtiene un
botón "Descargar" que exporta a PDF **exactamente la lista ya filtrada
en pantalla** — mismo principio de todo ADR-0022/0023, nunca el
historial completo sin filtrar si hay un filtro activo. A diferencia de
un estado de cuenta (una cuenta, un saldo, un periodo), un reporte es
una **lista de columnas libres** sin saldo único, así que se introduce
un segundo builder, `buildReportPdf` (junto a `buildStatementPdf` en
`shared_widgets/pdf_statement.dart`), que reutiliza el mismo encabezado,
pie de página y branding, pero pinta una tabla de columnas arbitrarias
en vez de la franja de saldo/periodo.

El bloque de identificación de cada reporte incluye **Generado por**
(email de quien lo descargó) y **Filtros activos** (un resumen legible
de qué filtros estaban aplicados — "Cliente: X · Estatus: Ejecutado", o
"Ninguno") — así el PDF deja claro qué universo de datos representa sin
tener que volver a la pantalla.

Columnas por pestaña:
- **Pagos SPEI**: Fecha, Tarjetahabiente, Cliente, Beneficiario, CLABE,
  Monto, Estatus. La CLABE viaja **enmascarada** — mismo criterio de
  `dto.FromSPEIPaymentForReport` (ver ADR-0022, threat-model punto 18):
  un PDF exportable es un listado masivo, el mismo vector de fuga que ya
  motivó enmascarar este endpoint.
- **Depósitos SPEI**: Fecha, Tarjetahabiente, Cliente, Monto,
  Referencia.
- **Beneficiarios**: Alias, Tarjetahabiente, Cliente, Banco, CLABE,
  Pagos, Total, Alerta. La CLABE exportada respeta **exactamente lo que
  la fila muestra en pantalla en ese momento** — enmascarada por
  default, completa solo si esa fila específica ya se reveló con
  "Revelar CLABE completa" antes de descargar. El PDF nunca revela algo
  que la pantalla no estaba mostrando ya.

### 2. Descarga a nivel de una tarjeta individual
Nueva sección en la pestaña "Movimientos" del detalle de una tarjeta
(`admin/lib/features/cards/card_detail_view.dart`, `_MovementsTab`): un
botón "Descargar" que genera el mismo tipo de documento que
`buildStatementPdf` (ADR-0023), identificando la **tarjeta** (PAN
enmascarado) y su titular, no toda la Cuenta Individual del
Tarjetahabiente — relevante para un Tarjetahabiente con más de una
tarjeta, donde el estado de cuenta a nivel Cuenta Individual mezcla los
movimientos de todas.

## Consecuencias
- `shared_widgets/pdf_statement.dart` gana un segundo builder público
  (`buildReportPdf`) además de `buildStatementPdf` — ambos comparten
  encabezado/pie/branding vía tres funciones privadas nuevas
  (`_pdfHeader`, `_pdfFooter`, `_pdfInfoBlock`), evitando duplicar el
  diseño del documento en dos lugares.
- **Corrección de seguridad encontrada en el camino**: el enmascarado de
  CLABE en toda la plataforma usa el carácter "•" (bullet), que la
  fuente base del PDF (Helvetica) no puede dibujar — una CLABE
  enmascarada se habría visto con el bullet en blanco/ausente en
  cualquier PDF, no solo en los reportes nuevos de este ADR. Se agregó
  `sanitizeForPdf` (antes privada, ahora pública y con prueba unitaria
  dedicada) que sustituye "•" → "*" y otros caracteres tipográficos
  (rayas largas, comillas curvas) por equivalentes seguros, aplicado a
  todo texto libre que entra a cualquiera de los dos builders. El dato
  real que muestra la UI nunca cambia, solo su representación dentro
  del PDF.
- ADR-0022 punto 4 ("tres pestañas de solo lectura, sin descarga") y
  ADR-0023 (solo enumeraba tres botones de descarga) quedan corregidos
  por este ADR.

## Alternativas consideradas
- **Reutilizar `buildStatementPdf` para los reportes, forzando un
  "saldo" ficticio**: descartado — un reporte no tiene un saldo real que
  mostrar, forzar el molde de estado de cuenta habría sido más confuso
  que construir un segundo builder genérico.
- **Exportar la CLABE completa en el reporte de Beneficiarios cuando el
  usuario ya la reveló en pantalla, pero completa para TODAS las filas
  del PDF**: descartado — el PDF debe reflejar exactamente lo que la
  pantalla muestra en ese momento, fila por fila, nunca más de lo que ya
  se reveló explícitamente.

## Ver también
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — punto
  4 (secciones de Reportes), corregido aquí.
- `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` — el diseño
  base de branding/formato que este ADR extiende.
- `docs/feature/reportes-admin/README.md`
- `docs/security/threat-model.md` punto 18 (CLABE enmascarada en
  listados masivos).
- `docs/adr/0026-pestana-movimientos-centralizada-en-reportes.md` —
  pestaña "Movimientos" centralizada, extiende esta decisión.
