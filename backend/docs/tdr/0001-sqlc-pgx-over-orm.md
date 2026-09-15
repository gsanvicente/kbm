# TDR-0001: sqlc + pgx en vez de un ORM

- Estado: Aceptada
- Fecha: 2026-09-15
- Alcance: decisión local al backend

## Contexto
El backend necesita control preciso sobre transacciones y sobre las
variables de sesión de Postgres usadas por Row-Level Security
(`SET LOCAL app.accessible_client_ids`, ver ADR-0003). Un ORM genérico
tiende a ocultar ese nivel de control.

## Decisión
Usar `sqlc` (SQL tipado, genera código Go) sobre `pgx` como driver, en vez
de un ORM como GORM.

## Consecuencias
- El dominio nunca debe depender de los structs generados por sqlc — se
  requiere una capa de mapeo explícita (`internal/adapters/postgres/mapper`).
- Cambios de esquema exigen regenerar código (`sqlc generate`), lo cual es
  visible en el diff — más trazable que un ORM con mapeo implícito.

## Alternativas consideradas
- **GORM**: descartado — menor control sobre SQL crudo y sobre el manejo
  de sesión que RLS requiere.
