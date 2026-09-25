# ADR-0025: Vista previa del banco (y corrección de refresco) al agregar un Beneficiario

- Estado: Aceptada
- Fecha: 2026-09-25

## Contexto
Dos hallazgos de una prueba en vivo del flujo "Agregar beneficiario"
(`cardholder/`, `AddBeneficiaryDialog` + `SpeiSection`):

1. **Bug de refresco**: tras guardar un Beneficiario nuevo, la pantalla
   "Cuenta" no lo mostraba hasta refrescar la página a mano. Se
   confirmó con `curl` en vivo contra el backend real (login, `POST
   .../beneficiaries`, `GET .../beneficiaries` inmediato) que el
   servidor sí guarda y sirve el registro nuevo sin ningún retraso — el
   problema es 100% del lado del cliente, no una condición de carrera
   del backend ni de RLS.
2. **Pregunta de negocio**: ¿qué implica dejar ver el banco detectado
   *antes* de guardar, para que el usuario confirme que capturó bien la
   CLABE?

## Decisión

### 1. La pantalla ya no depende de un refetch para mostrar lo que acaba de guardar
`_addBeneficiary` (`spei_section.dart`) ya no llama a `_reload()`
(recargar las 5 listas desde el servidor) después de un alta exitosa —
inserta directamente el `Beneficiary` que devolvió el propio `POST` en
el estado ya cargado en memoria. Ese objeto es la respuesta autoritativa
del servidor (no un dato optimista adivinado por el cliente), así que no
hay pérdida de exactitud, solo se elimina la dependencia de que un
segundo viaje de red vea el dato a tiempo. No se pudo aislar con
certeza *por qué* el refetch a veces no lo veía (candidatos: caché HTTP
del navegador sobre una respuesta sin `Cache-Control` explícito, o
simplemente que la pestaña de prueba tenía cargado un build de
`flutter run` anterior al último reinicio) — la corrección elegida
hace la pregunta irrelevante en vez de perseguir la causa exacta.

### 2. Vista previa del banco antes de guardar — sí, con límites claros
Se agrega una vista previa **client-side, instantánea, sin red**: en
cuanto la CLABE tiene 18 dígitos, se calcula el dígito verificador y se
busca el banco en un catálogo — mismo algoritmo y mismo catálogo que ya
usa el backend (`internal/domain/clabe`), portado a Dart en
`cardholder/lib/core/utils/clabe.dart`. Tres estados:
- **CLABE inválida** (dígito verificador no cuadra): aviso rojo, "revisa
  que los 18 dígitos estén bien capturados".
- **Banco no reconocido** (checksum válido, código de banco fuera del
  catálogo): aviso naranja — mismo criterio de "código inventado" que ya
  aplica el backend.
- **Banco detectado**: aviso verde, "Banco detectado: {nombre}. Confirma
  que sea el banco correcto antes de guardar." — deliberadamente
  redactado como una invitación a **confirmar**, nunca como una
  aseveración de que la cuenta es válida o pertenece a quien el usuario
  cree.

**Por qué client-side y no un endpoint de "preview"**:
- El algoritmo del dígito verificador y el catálogo de bancos son
  **información pública** (Banxico), no un secreto de negocio — no hay
  nada que proteger duplicándolos.
- Evita ida y vuelta de red por cada tecla (y su correspondiente
  debounce), da feedback instantáneo, y funciona incluso con
  conectividad inestable.
- Mismo criterio que ya usa el proyecto para
  `shared_widgets/csv_download.dart`/`pdf_statement.dart` entre `admin/`
  y `cardholder/` (ver ADR-0002, "sin código de runtime compartido"): la
  plataforma ya acepta duplicar piezas pequeñas y estables de lógica en
  vez de forzar una dependencia compartida entre componentes que ni
  siquiera comparten lenguaje aquí (Go vs. Dart).
- Un endpoint de "preview" habría sido una superficie nueva sin
  beneficio real: no puede decir más que el cálculo local (no existe
  "consulta de titular" contra un proveedor SPEI real, ver ADR-0021,
  "Fuera de alcance"), así que agregar red no compra ninguna garantía
  adicional, solo latencia y una ruta más que mantener.

**Por qué no debilita la vaguedad deliberada del error al guardar**: el
mensaje genérico que ya usa `AddBeneficiaryDialog` al fallar el submit
(nunca dice si falló por CLABE mal formada, banco desconocido, o ser la
CLABE propia del Tarjetahabiente) sigue exactamente igual. La vista
previa nueva solo puede confirmar o negar dos cosas matemáticas/de
catálogo (dígito verificador, código de banco) — nunca toca la pregunta
de "¿es esta tu propia CLABE?", que es la única razón real de mantener
esa vagueza (evitar que alguien use el mensaje de error para inferir si
una CLABE específica es la suya propia). No hay conflicto.

## Consecuencias
- **Reduce un vector de error real, no solo cosmético**: una
  transferencia SPEI mal dirigida por un dígito mal capturado es difícil
  o imposible de revertir. La vista previa no verifica que la cuenta
  exista o sea de quien el usuario cree, pero sí atrapa el error más
  común y barato de corregir: un typo que rompe el checksum o apunta a
  un banco que el usuario no reconoce como el correcto.
- **Duplicación deliberada de dominio** (Go ↔ Dart): si el catálogo de
  bancos cambia en el backend, hay que actualizar
  `cardholder/lib/core/utils/clabe.dart` a mano — documentado
  explícitamente en el propio archivo. El costo se acepta porque el
  catálogo es pequeño (~20 filas) y cambia con muy poca frecuencia
  (instituciones bancarias mexicanas, no un catálogo dinámico).
  `clabe_test.dart` fija los mismos vectores de prueba que
  `clabe_test.go` para detectar cualquier divergencia futura.
- El bug de refresco corregido en el punto 1 es específico de
  `_addBeneficiary` — `_sendMoney`/`_activateClabe` en el mismo archivo
  siguen usando el patrón de refetch completo (`_reload()`), porque un
  pago o una activación de CLABE sí cambian datos que no se pueden
  reconstruir localmente sin riesgo (saldo del ledger, movimientos
  nuevos) — no se tocaron, ver "Alternativas consideradas".

## Alternativas consideradas
- **Endpoint de preview en el backend**: descartado, ver "Por qué
  client-side" arriba.
- **Aplicar el mismo parche de "actualizar estado local en vez de
  refetch" a `_sendMoney`/`_activateClabe`**: descartado por ahora — un
  pago mueve saldo y genera un movimiento nuevo con datos que sí
  requieren la respuesta completa del servidor (saldo actualizado,
  posible comprobante); no es un simple "append a una lista" como un
  Beneficiario nuevo. Si aparece el mismo síntoma ahí, amerita su propio
  análisis, no una generalización apresurada de este parche.
- **Mostrar "CLABE verificada" en vez de "Banco detectado"**: descartado
  — sería una afirmación falsa (no hay verificación real de que la
  cuenta exista), un riesgo de negocio real si un usuario baja la
  guardia pensando que el sistema ya confirmó al destinatario.

## Ver también
- `docs/adr/0021-conector-spei.md` — el catálogo de bancos y el
  algoritmo de CLABE originales (Go), y la vaguedad deliberada del error
  de alta.
- `docs/adr/0002-flutter-web-mobile-two-apps.md` — "sin código de
  runtime compartido", el precedente que justifica duplicar la
  validación en Dart.
