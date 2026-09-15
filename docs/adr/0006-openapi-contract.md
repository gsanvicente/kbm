# ADR-0006: OpenAPI como contrato entre el backend Go y los clientes Flutter

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
Backend (Go) y frontends (Dart) no comparten lenguaje, a diferencia de la
propuesta inicial (descartada) de un stack full-TypeScript donde los tipos
se podrían compartir directamente.

## Decisión
`backend/api/openapi.yaml` es la fuente única de verdad del contrato HTTP.
Los clientes Dart para `admin` y `cardholder` se generan a partir de ese
spec (ej. `openapi-generator`), nunca se escriben a mano contra endpoints
ad hoc.

## Consecuencias
- Los cambios de contrato son visibles en el diff del spec y versionables.
- Agrega un paso de generación de código al build de los apps Flutter.
- Exige disciplina: el spec debe actualizarse junto con
  `internal/adapters/http/handler` en el mismo cambio (ver plantilla de PR
  raíz).

## Alternativas consideradas
- **gRPC/Protobuf**: descartado para el MVP — la complejidad adicional de
  gRPC-Web/Envoy para soporte de navegador no se justifica todavía;
  revisitar si aparecen llamadas servicio-a-servicio internas más adelante.
