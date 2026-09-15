# ADR-0003: Multi-tenancy lógico (Postgres RLS) + jerarquía de clientes de N niveles

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
Un Cliente (empresa) puede formar grupos corporativos padre/hijas de
profundidad arbitraria (holding → subsidiaria → sub-subsidiaria). Los
roles de la empresa padre deben heredar visibilidad/operación sobre todas
las empresas descendientes. El sistema debe evitar migraciones costosas si
el negocio crece a estructuras corporativas más complejas.

## Decisión
Una sola base de datos Postgres compartida, con Row-Level Security (RLS)
por tenant en vez de aislamiento físico (DB/schema por cliente). La
jerarquía se modela con `parent_client_id` + una tabla de cierre
transitivo `client_hierarchy` (ancestro, descendiente, profundidad),
mantenida por la aplicación, para resolver "todos los descendientes de X"
en O(1) sin importar la profundidad. La sesión de cada request setea el
GUC `app.accessible_client_ids` a partir de esa jerarquía + rol del
usuario; las políticas RLS filtran contra ese valor.

## Consecuencias
- Sin el costo operativo de una base de datos por cliente.
- Defensa en profundidad obligatoria: la capa de aplicación TAMBIÉN debe
  validar la jerarquía/rol antes de cada operación — RLS es una segunda
  barrera, no la única.
- Cada tabla con datos de un tenant necesita una columna `client_id`
  denormalizada (evita joins costosos para las políticas RLS).

## Alternativas consideradas
- **Aislamiento físico (DB o esquema por cliente)**: descartado — demasiado
  costoso operativamente para el tamaño de equipo/MVP actual.
- **Jerarquía de solo 2 niveles (adjacency simple)**: descartada — los
  grupos corporativos reales suelen superar 2 niveles, y retrofit de una
  tabla de cierre transitivo sobre datos de ledger ya en producción sería
  una migración costosa. Se paga el mismo esfuerzo de modelado ahora por
  soportar N niveles desde el inicio.
