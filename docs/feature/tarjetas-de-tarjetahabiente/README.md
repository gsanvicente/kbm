# Tarjetas del Tarjetahabiente

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake)
- ADR/TDR relacionados: ninguno nuevo
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 y 2
- Roles/actores involucrados: todos los roles de staff (ver)

## Objetivo
Mostrar, dentro del detalle de un Tarjetahabiente, las Tarjetas que tiene
asignadas — tercer nivel de la jerarquía Cliente → Tarjetahabiente →
Tarjeta — y permitir ver el detalle de cada una.

## Contexto / motivación
Continuación de `docs/feature/alta-y-gestion-de-tarjetahabientes/`. La
relación Tarjetahabiente-Tarjeta ya existe en el modelo de datos
(`cards.cardholder_id`); esta feature solo la hace visible.

## Nota de alcance de esta iteración
Repositorio fake (`CardRepository`), mismo dataset que
`backend/scripts/init-db/001_seed.sql`.

## Flujo principal
1. En el detalle de un Tarjetahabiente, se agrega una sección "Tarjetas"
   listando sus tarjetas como tarjetas visuales pequeñas (`PaymentCardVisual`,
   componente reutilizable), con los datos reales (terminaciones, nombre
   del Tarjetahabiente, vigencia) dibujados directamente sobre el arte de
   la tarjeta (`assets/images/card_black_template.png`), en el mismo lugar
   donde una tarjeta física real los tendría impresos. Una tarjeta
   Disponible (sin asignar) muestra "SIN ASIGNAR" en ese mismo lugar, ya
   que aún no tiene Tarjetahabiente.
2. Al hacer clic en una, se abre su detalle propio (`CardDetailView`), con
   la misma tarjeta visual en **tamaño grande** como elemento principal
   (no listas de datos planos) — Tarjetahabiente, terminaciones, vigencia
   y estado ya están ahí impresos, sin repetirlos aparte como filas de
   texto plano (el nombre en mayúsculas y sin acentos de la tarjeta es
   suficiente; no hace falta una fila "Tarjetahabiente" adicional). La
   fecha de asignación tampoco se repite aquí — no tiene un lugar natural
   impreso en la tarjeta y ya se puede consultar desde el listado de
   Tarjetas (ver `docs/feature/pool-y-asignacion-de-tarjetas/`). Breadcrumb
   completo
   (ej. "Clientes / Koons Subsidiaria A / Juan Perez / •••• 1234").
3. Si el Tarjetahabiente no tiene tarjetas asignadas, se muestra un estado
   vacío en vez de una sección en blanco.

## Nota sobre el asset visual y el overlay
`card_black_template.png` es una plantilla en blanco (a diferencia de la
primera versión de este asset, que traía un número y nombre de empresa de
ejemplo impresos) — no hace falta tapar nada, solo dibujar el dato real
en el lugar correcto:
- Se midieron con precisión (no a ojo, con un script sobre los píxeles de
  la imagen) las coordenadas exactas de dónde va cada campo, como
  fracciones del tamaño de la imagen — así el overlay escala
  correctamente sin importar el tamaño final del widget (thumbnail
  pequeño o tarjeta grande en el detalle, mismo componente).
- La vigencia no tiene un espacio dedicado en el diseño — se ubicó en un
  espacio vacío confirmado (misma fila que el nombre, a la derecha).
- El nombre que se muestra donde la plantilla deja espacio para el
  nombre es el del **Tarjetahabiente**, no el Cliente (empresa) — refleja
  a quién se le entregó físicamente la tarjeta, que es lo que un lector
  de la tarjeta esperaría ver ahí. El nombre del Cliente sigue
  disponible en otras pantallas (listados, breadcrumb).
- No se pudo verificar la alineación con una captura de pantalla real
  (limitación del entorno) — confirmar visualmente y ajustar si hace
  falta.

Además, la imagen trae impreso "VISA Business": hoy se usa para todas las
tarjetas sin importar su red real — **pendiente de definir** qué pasa
cuando exista una tarjeta Mastercard real (¿mismo
asset, o se necesita un diseño equivalente?).

## Reglas de negocio
Ver `docs/business/tarjetas-y-asignacion.md` — no se repite aquí.

## Casos borde / fuera de alcance
- Asignar una tarjeta nueva desde aquí: se hace desde
  `docs/feature/pool-y-asignacion-de-tarjetas/`, no desde esta pantalla.
- Congelar/cancelar una tarjeta: fuera de alcance, es una operación de
  saldo futura. Bloquear/desbloquear sí está implementado — ver
  `docs/feature/bloqueo-de-tarjeta/`.

## Criterios de aceptación
Ver `acceptance.feature`.
