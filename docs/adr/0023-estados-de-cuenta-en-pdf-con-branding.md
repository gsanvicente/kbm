# ADR-0023: Los estados de cuenta se descargan en PDF con branding de la plataforma, no CSV

- Estado: Aceptada — **extendida por
  `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md`**: agrega
  descarga a las pestañas de Reportes (con un builder de tabla genérica
  nuevo, `buildReportPdf`) y a nivel de una tarjeta individual; también
  corrige ahí un bug real encontrado en el camino (el bullet "•" del
  enmascarado de CLABE no lo dibuja la fuente base del PDF).
- Fecha: 2026-09-25

## Contexto
`docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`, punto 6,
decidió que la descarga de un estado de cuenta (Cuenta Individual de un
Tarjetahabiente, y Cuenta Concentradora de un Cliente para directivos)
fuera un CSV plano, armado 100% client-side, sin encabezado ni ningún
dato de identificación más allá de las 5 columnas de movimientos
(`Fecha,Tipo,Descripción,Monto,Saldo`).

El negocio corrigió ese alcance: un estado de cuenta que sale de la
plataforma tiene que verse como un documento oficial — con el logo y la
identidad de KBM/Koons, un encabezado claro, los datos de la cuenta que
identifican de qué se trata (titular o Cliente, quién lo generó, cuándo,
qué periodo cubre), no solo una tabla de números sin contexto. Un CSV no
puede llevar ese diseño; un PDF sí.

## Decisión
Los tres botones "Descargar estado de cuenta" que introdujo ADR-0022
(Tarjetahabiente descargando el suyo propio en `cardholder/`, staff
descargando el de un Tarjetahabiente en `admin/`, y el Estado de cuenta
de Tesorería por Cliente/filial en `admin/`) generan un **PDF**, no un
CSV. Todo lo demás del punto 6 de ADR-0022 sigue vigente sin cambio:
sigue siendo enteramente client-side (el paquete `pdf`, puro Dart, corre
igual en el navegador que en cualquier otra plataforma — no hace falta
`printing` ni ningún plugin nativo), sigue sin haber un endpoint de
exportación dedicado, y sigue exportando exactamente el rango/periodo
que el filtro activo esté mostrando en ese momento.

### Branding: de la plataforma (Koons/KBM), nunca del Cliente
El PDF lleva el logo y los colores de KBM/Koons
(`admin/lib/app/theme.dart`/`KoonsColors`, mismo logo que ya usan ambas
apps: `assets/images/kbm_logo.png`) — igual que un estado de cuenta
bancario real lo emite y firma el banco, no la empresa dueña de la
cuenta. Se evaluó branding por Cliente (cada empresa vería su propio
logo) y se descartó: no existe ningún campo de logo/color en el modelo
`Client` hoy, y agregarlo (más la UI de alta/edición correspondiente)
era una pieza de trabajo separada y no trivial que el negocio no pidió
para esta iteración.

### Contenido del documento
- **Encabezado** (se repite en cada página si el estado de cuenta ocupa
  más de una): logo, "KBM · Koons Balance Management", título "Estado de
  Cuenta", el tipo de cuenta ("Cuenta Individual" / "Cuenta
  Concentradora"), y la fecha/hora exacta de generación.
- **Bloque de identificación de la cuenta** — la parte que el CSV no
  tenía: según quién descarga qué,
  - Tarjetahabiente descargando el suyo (`cardholder/`): Titular, CLABE
    (completa — es su propia cuenta, mismo criterio que ya aplica en
    ADR-0022 punto 2 a la ficha individual).
  - Staff descargando el de un Tarjetahabiente (`admin/`): Titular,
    Cliente, Identificación oficial, y **Generado por** (el email de
    quien lo descargó) — para dejar registrado en el documento mismo que
    fue staff, no el propio Tarjetahabiente, quien lo generó.
  - Estado de cuenta de Tesorería por Cliente/filial (`admin/`):
    Cliente, y **Generado por** (el email del directivo que lo
    descargó).
- **Saldo actual** y **periodo cubierto**, en una franja prominente
  separada de la tabla — nunca se confunden: el saldo es de *ahora*, el
  periodo es de *flujo* (mismo distingo que ya documenta ADR-0022 punto
  5 para el Estado de cuenta de Tesorería).
- **Tabla de movimientos**: mismas 5 columnas que el CSV que reemplaza
  (`Fecha, Tipo, Descripción, Monto, Saldo`), con el encabezado de tabla
  en navy/blanco, filas alternadas para legibilidad, y el monto en verde
  (Abono) o navy (Cargo) — mismo código de color que ya usan las listas
  de movimientos en ambas apps.
- **Pie de página**: número de página / total de páginas, y un aviso de
  confidencialidad ("uso exclusivo del destinatario") en cada página.
- Formato de moneda: reutiliza `formatCurrency`/`formatAmount`
  (`core/utils/currency_format.dart`, ya existente en ambas apps) — con
  separador de miles, igual que el resto de la UI. El CSV plano evitaba
  a propósito el separador de miles y el símbolo de moneda "para que
  abriera limpio en Excel"; ese argumento ya no aplica a un PDF, que
  nunca se re-importa a una hoja de cálculo.
- Nombre de archivo: mismo patrón que el CSV
  (`estado-de-cuenta-{id}-{fecha}.pdf`), solo cambia la extensión.

### Implementación
- Dependencia nueva en ambas apps: `pdf` (paquete Dart puro, sin
  dependencias de plataforma nativa — corre igual en `flutter test`, web
  y mobile). No se agregó `printing` (su compañero habitual): no hace
  falta vista previa/impresión nativa, solo generar bytes y descargarlos,
  que el mecanismo de descarga ya existente (`dart:html` `Blob` +
  `<a download>`, ver `pdf_download_web.dart`) cubre igual que ya cubría
  el CSV.
- `shared_widgets/pdf_statement.dart` (duplicado en `admin/` y
  `cardholder/`, mismo criterio de ADR-0002 que ya aplicaba a
  `csv_download.dart`) centraliza el diseño del documento — un solo
  lugar donde ajustar el layout si cambia el branding.
- `csv_download.dart`/`csv_download_stub.dart`/`csv_download_web.dart`
  se eliminaron de ambas apps (sin más consumidores tras este cambio) y
  se reemplazaron por el análogo `pdf_download*.dart` (mismo patrón,
  bytes en vez de texto, `application/pdf` en vez de `text/csv`).

### Limitación conocida, aceptada a propósito
El PDF usa la fuente base Helvetica que trae el paquete `pdf` — cubre
correctamente todo el español (incluye acentos, ñ, ¿¡) vía
WinAnsiEncoding, pero **no tiene soporte Unicode completo** (por
ejemplo, un guión largo "—" o un emoji en un campo de texto libre como
la referencia de un depósito o el motivo de una Dispersión no se
dibujaría). No se embebió una fuente Unicode completa (p.ej. Inter, ya
usada en el resto de la UI vía `google_fonts`) porque requiere empaquetar
un archivo de fuente estático nuevo como asset en ambas apps — trabajo
real, no una línea de config — y el riesgo (un carácter puntual sin
dibujar en un campo de texto libre, nunca un error o un documento
corrupto) no justificó bloquear esta entrega. Se reconsidera si aparece
un caso real.

## Consecuencias
- El estado de cuenta ahora es un documento presentable para compartir
  fuera de la plataforma (banco, contador, auditor externo) — el CSV
  nunca lo fue.
- Dos dependencias nuevas (`pdf` y sus transitivas: `image`, `xml`,
  `petitparser`, `qr`, `path_parsing`, `posix`) en ambas apps. Ninguna
  agrega superficie nativa (todas son Dart puro), así que no cambia el
  perfil de plataformas soportadas.
- El bloque de identificación ("Generado por") deja un registro dentro
  del documento mismo de qué staff generó el estado de cuenta de un
  Tarjetahabiente o Cliente que no es el propio dueño de la cuenta — un
  refuerzo de trazabilidad que el CSV no tenía (aunque no reemplaza
  `audit_log`; no se agregó una entrada de auditoría nueva por descargar
  un PDF, mismo criterio que ya regía para el CSV — es una lectura, no
  una acción sensible como revelar una CLABE).

## Alternativas consideradas
- **Branding por Cliente** (cada empresa con su propio logo/colores):
  descartado para esta iteración — no existe el campo en el modelo de
  datos, y agregarlo es una pieza de trabajo separada, ver "Branding"
  arriba.
- **Ofrecer ambos formatos (CSV y PDF)**: descartado — el negocio pidió
  el cambio de formato, no un formato adicional; mantener el CSV vivo
  solo agregaría una segunda ruta de código a probar sin que nadie lo
  pidiera.
- **Generar el PDF en el backend (Go)**: descartado por la misma razón
  que ADR-0022 descartó un endpoint de exportación para el CSV — el dato
  ya viaja completo al cliente para pintar la pantalla, regenerarlo en
  el backend solo para cambiar el formato de salida es trabajo
  redundante y reabre la pregunta de por qué un endpoint de solo lectura
  necesitaría lógica de PDF-rendering del lado servidor.
- **Embeber una fuente Unicode completa (Inter) en el PDF**: evaluado y
  pospuesto, ver "Limitación conocida" arriba.

## Ver también
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — punto
  6, el diseño original (CSV) que este ADR corrige.
- `docs/feature/tesoreria-cliente/README.md` — Estado de cuenta de
  Tesorería, uno de los tres puntos de descarga.
- `docs/business/autoservicio-tarjetahabiente.md` — descarga del propio
  Tarjetahabiente.
- `docs/adr/0024-descarga-en-reportes-y-por-tarjeta.md` — extiende esta
  decisión a Reportes y a nivel de tarjeta individual.
- `docs/business/roles-and-permissions.md` — descarga de staff sobre un
  Tarjetahabiente sin tarjetas.
