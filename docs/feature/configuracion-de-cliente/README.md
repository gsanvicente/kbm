# Configuración de Cliente

- Estado: Implementado (2026-09-21), contra el backend Postgres
- ADR/TDR relacionados: `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`
- Amenazas relevantes: `docs/security/threat-model.md` punto 1 (control de acceso)
- Roles/actores involucrados: Super Admin, Admin Cliente (pueden ver y editar); Operador, Auditor (no ven la pestaña en absoluto)

## Objetivo
Darle a Super Admin/Admin Cliente una pantalla real para editar dos
configuraciones de un Cliente que hasta ahora solo existían como datos
sembrados en Postgres, sin ninguna forma de cambiarlas desde `admin/`:

1. **Límite de tarjetas activas por Tarjetahabiente** (`client_settings.max_active_cards_per_cardholder`)
   — ver `docs/business/tarjetas-y-asignacion.md`.
2. **Reglas de aprobación** por tipo de operación (`approval_rules`,
   Dispersión/Deducción/Transferencia) — ver
   `docs/business/approval-policy.md`.

## Contexto / motivación
Ambas tablas existían desde el schema original (`backend/migrations/0001_init.sql`)
y ya se leían (`GetClientMaxActiveCards`, `GetApprovalRule`), pero nunca
se escribían fuera del seed (`scripts/init-db/001_seed.sql`) — cambiar un
límite o una regla de aprobación requería editar SQL a mano y resembrar.
Se identificó como parte de una auditoría de integración completa
(ver ADR-0012, "Consecuencias") junto con otros tres puntos ya resueltos
en el mismo incremento (políticas RLS, N+1 de reclamos en el Panel
directivo, aviso de dato sintético condicionado al backend).

## Dónde vive
Una tercera pestaña "Configuración" en `ClientDetailView`
(`admin/lib/features/clients/client_detail_view.dart`, `_ConfigurationTab`),
junto a "Tesorería" y "Tarjetahabientes" — solo visible cuando
`session.role.canManageClients` es true; el `TabController` mismo tiene
longitud 2 o 3 según el rol, así que Operador/Auditor no solo no pueden
editar, no ven que la pestaña existe.

## Backend
- `client_settings`: `UpsertClientMaxActiveCards` (get-or-create,
  `ON CONFLICT (client_id) DO UPDATE`) — `max=null` borra el override
  (la fila queda con el campo en `NULL`, funcionalmente igual a no tener
  fila, ver `CardRepository.MaxActiveCardsPerCardholder`).
- `approval_rules`: ganó una restricción `UNIQUE (client_id, operation_type)`
  (`backend/migrations/0004_approval_rules_unique_constraint.sql`) —
  nunca existió antes porque solo el seed escribía esta tabla; sin ella,
  `ON CONFLICT` en `UpsertApprovalRule` no sería válido y, en teoría,
  dos filas para el mismo Cliente+tipo hubieran sido posibles (nunca
  pasó en la práctica, pero era una restricción de integridad real
  ausente).
- Endpoints nuevos: `PUT /v1/clients/{id}/settings`,
  `GET/PUT/DELETE /v1/clients/{id}/approval-rules[/{operationType}]` —
  ver `backend/internal/adapters/http/handler/handler_management.go`.
  `DELETE` quita el override por completo (el Cliente vuelve al default
  fail-safe — requiere aprobación — para ese tipo), distinto de "guardar
  con `requiresApproval: false`" (una regla explícita que dice "nunca
  requiere aprobación").
- El adaptador en memoria (modo demo) también implementa
  `SetMaxActiveCardsPerCardholder` (mutando el mapa sembrado que ya
  usaba `Assign`) porque `CardRepository` es un puerto que ese adaptador
  sí implementa. `ListApprovalRules`/`SetApprovalRule`/`DeleteApprovalRule`
  viven en `BalanceOperationRepository`, que el modo memoria nunca
  implementó (fuera de su alcance desde ADR-0010) — esta pantalla
  simplemente no aplica en modo demo.

## UI
- **Límite de tarjetas activas**: una fila con el valor actual ("N
  tarjeta(s) activa(s)" o "Sin límite configurado (usa el default: 1)")
  y un botón "Editar" que abre un diálogo con un campo numérico —
  vacío = quitar el override.
- **Reglas de aprobación**: una fila por `OperationType` (Dispersión,
  Deducción, Transferencia — mismo orden que
  `admin/lib/core/models/operation_type.dart`), cada una con su estado
  actual en texto llano ("Sin regla — requiere aprobación (default de
  seguridad)", "No requiere aprobación — se ejecuta de inmediato", o
  "Requiere aprobación para [cualquier monto | montos mayores a $X]") y
  un botón "Editar" que abre un diálogo con un switch
  ("Requiere aprobación") y, si está activado, un campo de monto mínimo
  (`$0.00` se interpreta como "cualquier monto" — ver nota abajo). El
  diálogo incluye "Quitar regla" solo cuando ya existe una.

### Por qué `$0.00` significa "cualquier monto"
`ApprovalRule.minAmount == null` y `ApprovalRule.minAmount == 0` son
funcionalmente idénticos en la práctica: la comparación real es
`amount > minAmount` (`backend/internal/adapters/postgres/repository/approval.go`,
`needsApproval`), y ninguna operación de saldo real tiene `amount <= 0`.
Evita construir una UI de "checkbox aparte para monto nulo" para una
distinción que no cambia ningún comportamiento observable.

## Fuera de alcance de esta iteración
- No hay historial/auditoría de quién cambió una regla o el límite —
  `updated_at` se actualiza en la fila, pero no hay una vista de
  bitácora (ver `audit_log`, tabla ya existente pero sin ningún consumidor,
  `internal/application/ports/doc.go`).
- Los tipos `block`/`unblock` de `operation_type` (el enum de Postgres
  los tiene, el `OperationType` de Dart no) no tienen fila de
  configuración aquí — bloquear/desbloquear una tarjeta sigue siendo una
  acción directa, nunca pasó por `approval_rules`, ver
  `docs/feature/bloqueo-de-tarjeta/README.md`.

## Pruebas
`admin/test/widget_test.dart`: "Configuración lets Super Admin edit the
max-active-cards limit and an approval rule" (cubre editar el límite,
crear una regla, y quitarla) y "Operador never sees the Configuración
tab" (control de acceso).
