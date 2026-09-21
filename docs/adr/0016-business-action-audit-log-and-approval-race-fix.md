# ADR-0016: Audit_log de acciones de negocio, y corrección de la condición de carrera en Approve/Reject

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
Tras ADR-0015 (autorización por rol + `audit_log` de login), quedaban dos
últimos hilos sueltos bajo "pendientes de seguridad":

1. `audit_log` solo registraba intentos de login — ninguna acción de
   negocio (crear un Cliente, aprobar una operación, bloquear una
   tarjeta...) dejaba rastro, a pesar de que
   `docs/security/threat-model.md` punto 4 ("Repudio de operaciones de
   aprobación") ya identificaba esto como un riesgo real.
2. ADR-0014 documentó, sin corregir, una condición de carrera
   preexistente en `Approve`/`Reject` (`approval.go`): el
   `SELECT ... FOR UPDATE` de `getOperationForUpdate` libera su lock al
   hacer `commit` de esa transacción corta, **antes** de `tryExecute` —
   dos llamadas concurrentes a `Approve` sobre la misma operación
   pendiente podían ambas pasar el chequeo de estado antes de que
   cualquiera actualizara el estado final, ejecutando el movimiento de
   saldo dos veces.

Se pidió cerrar ambos para no dejar ningún pendiente de seguridad
abierto.

## Decisión

### 1. Identidad del llamador extendida (`ports.CallerIdentity`)
`ports.WithCallerClientID`/`CallerClientIDFromContext` (ADR-0014, solo
para RLS) se reemplazaron por `ports.CallerIdentity` — un struct con
`ClientID`, `UserID` y `Type`, fijado una sola vez por el middleware de
`Routes()` justo después de `RequireAuth`. El adaptador Postgres ya lo
usaba para RLS; ahora también lo usa para atribuir cada escritura a un
actor real.

### 2. `logCallerAudit` y su uso en cada escritura de negocio
`logCallerAudit(ctx, q, action, entityType, entityID, metadata)` —
espejo de `logAudit` (ADR-0015) pero toma el actor de
`ports.CallerFromContext` en vez de recibirlo explícito (solo login
recibe el actor a mano, porque corre antes de que exista una identidad
que resolver). Se agregó justo antes de retornar éxito, dentro de la
misma transacción de cada escritura, en:

- `client.go`: `client_created`, `client_updated`,
  `client_deactivated`/`client_reactivated`.
- `cardholder_management.go`: `cardholder_created`,
  `cardholder_updated`, `cardholder_deactivated`/`cardholder_reactivated`.
- `cards.go`: `card_assigned`, `card_blocked`/`card_unblocked`,
  `card_self_frozen`/`card_self_unfrozen` (actor Tarjetahabiente),
  `client_settings_updated`.
- `approval.go`: `balance_operation_requested`,
  `balance_operation_executed`/`balance_operation_failed` (auto-ejecución
  sin aprobación), `balance_operation_executed`/`balance_operation_failed`
  (vía `Approve`), `balance_operation_rejected`, `approval_rule_updated`,
  `approval_rule_deleted`.
- `claims.go`: `claim_filed`, `claim_resolved`.
- `treasury.go`: `deposit_registered`, `deposit_reconciled`.
- `transfer.go`: `transfer_executed` (actor Tarjetahabiente) — **caso
  especial, ver "Consecuencias"**.

### 3. Corrección de la condición de carrera (`withAdvisoryLock`)
`Approve` y `Reject` ahora corren envueltos en
`withAdvisoryLock(ctx, "balance_operation:"+operationID, fn)` —
serializa cualquier llamada concurrente sobre la misma operación
(`Approve` contra `Approve`, y también `Approve` contra `Reject`, misma
llave) usando un advisory lock de Postgres, visible entre todas las
conexiones, no solo dentro de una transacción. Se prefirió esto sobre
convertir todo el flujo (lectura, `tryExecute`, actualización de estado)
en una sola transacción gigante — `tryExecute` ya delega en métodos
(`PostEntry`, `PostConcentratorEntry`) que abren sus propias
transacciones cortas por diseño (ver comentario "nunca a medias" en
`approval.go`), y unificarlas hubiera sido un rediseño mucho más grande
y riesgoso del código financiero ya en producción.

**Bug real encontrado y corregido antes de cerrar este incremento**: la
primera versión de `withAdvisoryLock` sacaba la conexión del **mismo**
pool que usan `withRLS`/`beginRLS` (`s.pool.Acquire`), sosteniéndola
durante toda la duración de `fn`. Bajo concurrencia real, esto se
autobloquea: `tryExecute` necesita conexiones *adicionales* del mismo
pool para sus propias transacciones, pero un pool con capacidad limitada
se agota con llamadas concurrentes esperando el advisory lock mientras
sostienen su propia conexión — un deadlock genuino, reproducido en vivo
disparando 10 `Approve()` concurrentes sobre la misma operación (la
prueba se colgó indefinidamente). Corregido usando una conexión
completamente separada del pool (`pgx.ConnectConfig`, no
`s.pool.Acquire`) solo para el advisory lock — nunca compite por
conexiones con el trabajo real que corre dentro de `fn`.

## Consecuencias
- Verificado en vivo contra Postgres real, con las 10 llamadas
  concurrentes ya corregidas: exactamente una recibe 200 (executed), las
  otras nueve 409 (invalid state), y el saldo de la tarjeta se movió
  **una sola vez** (verificado con el balance antes/después). Todas las
  demás acciones de negocio (crear/desactivar Cliente, crear/desactivar
  Tarjetahabiente, asignar/bloquear tarjeta, congelarse a sí mismo,
  transferencia C2C, solicitar/aprobar/rechazar operación, reglas de
  aprobación, archivar/resolver reclamo, registrar/conciliar depósito)
  quedaron verificadas end-to-end contra `audit_log` con el actor
  correcto (`staff` o `cardholder`).
- **`transfer.go`'s `Execute` es best-effort a propósito, distinto de
  todas las demás escrituras.** Para el resto, si `logCallerAudit`
  falla, la transacción entera (incluida la escritura de negocio) hace
  rollback — mismo criterio "nunca en silencio" de ADR-0015. Pero
  `Execute` ya completó el movimiento de saldo en dos transacciones
  independientes y ya comprometidas (`PostEntry` × 2) antes de intentar
  auditar; fallar la llamada completa ahí le reportaría al
  Tarjetahabiente que su transferencia falló cuando en realidad sí se
  aplicó — peor que perder una entrada de auditoría. Se decidió loguear
  el error del lado del servidor (`log.Printf`) en vez de propagarlo.
- `go build/vet/test` en verde; sin cambios al adaptador en memoria (no
  tiene RLS ni `audit_log`, fuera de su alcance desde ADR-0010).
- Con esto se cierran los dos hilos sueltos que quedaban bajo
  "pendientes de seguridad" tras ADR-0014/0015. Lo que sigue pendiente
  ya no es seguridad activa, es producto (filtro de fechas/reclamos en
  `cardholder/`) o decisiones de negocio (elegir un procesador de
  tarjetas).

## Alternativas consideradas
- **Patrón Outbox real** (`outbox_events` → worker → `audit_log`, como
  originalmente insinuaba el comentario de `threat-model.md` punto 4):
  descartado por alcance — hubiera significado construir la primera
  pieza real de `cmd/worker`/`internal/adapters/outbox`/`queue`, una
  pieza de infraestructura async mucho más grande que "cerrar un
  pendiente de seguridad". El patrón síncrono directo (mismo criterio
  que login) cierra la promesa de auditoría sin esa complejidad
  adicional; se reconsidera si el proyecto construye esa infraestructura
  por otra razón (p. ej. integración real con un procesador).
- **Convertir todo el flujo de Approve/Reject en una sola transacción**
  (en vez de un advisory lock): descartado por riesgo — hubiera
  requerido rediseñar `PostEntry`/`PostConcentratorEntry` para aceptar
  una transacción externa en vez de abrir la suya, tocando código
  financiero ya en producción y probado, para cerrar una condición de
  carrera que un advisory lock cierra igual de bien con un cambio mucho
  más acotado.
- **`pg_try_advisory_lock` con reintentos** (en vez del `pg_advisory_lock`
  bloqueante): descartado — con el bug de pool corregido, no hay
  necesidad de evitar el bloqueo; un `Approve` que espera brevemente a
  que otro termine es correcto y esperado, no un problema a evitar con
  polling.

## Ver también
- `docs/adr/0014-row-level-security-policies.md`
- `docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`
- `docs/security/threat-model.md`, punto 4
- `backend/internal/adapters/postgres/repository/locks.go`
- `backend/internal/application/ports/caller.go`
