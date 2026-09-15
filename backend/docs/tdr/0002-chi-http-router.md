# TDR-0002: chi como router HTTP

- Estado: Aceptada
- Fecha: 2026-09-15
- Alcance: decisión local al backend

## Contexto
El adaptador HTTP debe ser una capa delgada sobre los casos de uso de
`internal/application` (ver ADR-0001) — un framework "todo incluido" tienta
a meter lógica de negocio en los handlers.

## Decisión
Usar `chi` (router liviano de la librería estándar de Go) en vez de un
framework más pesado.

## Consecuencias
- Menos "baterías incluidas" (validación, serialización) — hay que
  añadirlas deliberadamente en `internal/adapters/http/middleware` y
  `internal/adapters/http/dto`.
- Mantiene honesta la frontera hexagonal: el router no sabe nada del
  dominio.

## Alternativas consideradas
- **Gin/Echo/Fiber**: descartados — mayor riesgo de que la lógica de
  negocio se acople a patrones específicos del framework.
