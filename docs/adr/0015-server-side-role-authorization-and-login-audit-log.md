# ADR-0015: Autorización por rol del lado del servidor, y audit_log de intentos de login

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
Tras cerrar RLS (`docs/adr/0014-row-level-security-policies.md`), quedaban
dos huecos identificados en la misma auditoría de seguridad:

1. **El backend nunca verificaba el rol de staff, solo que fuera staff.**
   `middleware.RequireStaff` (ADR-0013) acepta cualquier `claims.Role` —
   `admin/`'s `Role` (`admin/lib/core/models/role.dart`) ya decide qué
   botones mostrar según el rol, pero esa era la **única** barrera: un
   token válido de Auditor podía golpear directamente, por HTTP, un
   endpoint como aprobar una operación de saldo o desactivar un Cliente,
   sin pasar por la UI. `internal/application/ports/doc.go` ya
   mencionaba un `AuthorizationPort` planeado para esto exacto, nunca
   construido.
2. **`audit_log` existe desde `migrations/0001_init.sql` pero nunca se
   escribía.** `docs/feature/login-administrativo/README.md` ya
   prometía "todo intento (éxito o fallo) queda registrado en
   audit_log" — una promesa documentada, incumplida en código.

## Decisión

### 1. Autorización por rol (`RequireRole`)
- `middleware.RequireRole(allowed ...staff.Role)` (nuevo, en
  `internal/adapters/http/middleware/auth.go`), montado después de
  `RequireStaff` — rechaza con 403 si `claims.Role` no está en la lista
  permitida.
- `internal/adapters/http/handler/authz.go` (nuevo) define los dos
  conjuntos exactos de `docs/business/roles-and-permissions.md`, espejo
  literal de los getters de `role.dart`:
  - `manageRoles` (Super Admin + Admin Cliente): crear/editar/desactivar
    Clientes y Tarjetahabientes, asignar tarjetas, aprobar/rechazar
    operaciones de saldo, resolver reclamos, conciliar depósitos,
    editar Configuración de Cliente.
  - `operateRoles` (todos salvo Auditor): bloquear/desbloquear tarjetas,
    solicitar operaciones de saldo, registrar depósitos, presentar
    reclamos.
  - Todo lo demás (lecturas) sigue sin requerir más que `RequireStaff` —
    "ver" nunca estuvo restringido por rol, ver
    `docs/business/roles-and-permissions.md`.
- `Routes()` se reorganizó en tres sub-grupos anidados bajo
  `RequireStaff`: lecturas sin restricción adicional, luego un grupo con
  `RequireRole(manageRoles...)`, luego otro con
  `RequireRole(operateRoles...)`.
- No se construyó un `AuthorizationPort` genérico invocado por una capa
  de casos de uso — este backend interino no tiene esa capa (ver
  `internal/adapters/http/handler/handler.go`, comentario de paquete:
  "Sin capa de usecase intermedia en esta iteración"). `RequireRole` en
  el router cumple el mismo propósito (una verificación de rol
  centralizada que ningún endpoint nuevo puede olvidar mencionar sin que
  sea obvio en el código de `Routes()`), sin inventar una capa que el
  resto de la arquitectura todavía no tiene.

### 2. `audit_log` de intentos de login
- Nueva query `InsertAuditLog` (`internal/adapters/postgres/sqlc/queries/audit.sql`)
  y helper `logAudit` (`internal/adapters/postgres/repository/audit.go`).
- `Store.Login` (Tarjetahabiente) y `StaffAuthStore.Login` (staff)
  registran `login_success` o `login_failed` — con el motivo exacto en
  `metadata` (`invalid_password`, `inactive`, `client_inactive`) para
  uso **interno** de auditoría/cumplimiento, nunca expuesto por ninguna
  respuesta HTTP (que sigue usando el mensaje genérico de siempre).
- **Un email que no existe no genera fila** — `entity_id` es
  `NOT NULL` y no hay ningún usuario real al que referenciar; el
  propósito de `audit_log` es trazabilidad sobre una entidad conocida,
  no un contador de intentos con email inexistente (eso ya lo cubre el
  throttle de intentos fallidos de transferencia, ver threat-model punto
  12, que es un mecanismo distinto).
- `audit_log` no tiene RLS — sus escrituras corren sin GUC, ya sea
  directo contra `s.q` (staff, sin transacción propia) o dentro de la
  misma transacción bypaseada de RLS que ya abría el login del
  Tarjetahabiente (`withRLSBypass`).
- **La escritura de auditoría nunca falla en silencio**: si
  `InsertAuditLog` falla, el login entero falla con ese error (nunca se
  reporta éxito, o incluso el 401 genérico normal, sin que la fila haya
  quedado escrita). En `Store.Login` esto exigió una reestructuración:
  el error de negocio (`ErrInvalidCredentials`) se captura en una
  variable externa y la función pasada a `withRLSBypass` siempre
  devuelve `nil` (para que el `COMMIT` incluya la fila de auditoría que
  se acaba de insertar) salvo que ocurra un error real de base de datos
  — devolver el error de negocio directamente desde ahí hacía rollback
  también de la auditoría recién escrita. Se encontró este bug en vivo
  (la fila de un login fallido de Tarjetahabiente no aparecía) y se
  corrigió antes de cerrar este incremento.
- Alcance deliberadamente acotado a **login únicamente** — la promesa ya
  documentada que se estaba incumpliendo. Auditar cada acción de negocio
  (crear Cliente, aprobar una operación, bloquear una tarjeta...) es una
  extensión natural pero mayor, no incluida aquí.

## Consecuencias
- Verificado en vivo contra Postgres real: Auditor recibe 403 al
  intentar aprobar una operación de saldo o solicitar una
  Dispersión/Deducción/Transferencia (antes: 200, cualquier rol podía);
  Operador recibe 403 al intentar conciliar un depósito o asignar una
  tarjeta, pero sí puede bloquear/desbloquear y solicitar operaciones.
  Nuevos tests en `handler_test.go`
  (`TestOperateRoles_BlockStatus`, `TestManageRoles_AssignCard`) cubren
  los mismos casos contra el adaptador en memoria.
- `audit_log` recibe una fila por cada login (éxito o fallo con
  identidad conocida) contra Postgres — verificado con las 4
  combinaciones (staff/Tarjetahabiente × éxito/fallo) más los dos casos
  de email desconocido (correctamente sin fila) y el caso de cascada de
  Cliente inactivo (`reason: "client_inactive"`).
- `go build/vet/test` en verde; el adaptador en memoria no se tocó (no
  tiene ni RLS ni `audit_log`, fuera de su alcance desde ADR-0010).
- Sigue pendiente (no parte de este incremento): auditoría de acciones
  de negocio más allá del login, y un `AuthorizationPort` genérico de
  verdad si este backend alguna vez gana una capa de casos de uso real.

## Alternativas consideradas
- **Verificar el rol a mano dentro de cada handler** (como ya se hacía
  para los ownership-checks de "alcance mixto" en ADR-0013): descartado
  — para permisos por-rol-de-staff (no por identidad del recurso), un
  middleware centralizado en `Routes()` hace visible de un vistazo qué
  grupo de rol exige cada endpoint, y ningún handler nuevo puede
  "olvidar" el chequeo silenciosamente si la ruta ya está bajo el grupo
  correcto.
- **Registrar el intento de auditoría de forma best-effort (ignorar el
  error de `InsertAuditLog`)**: descartado — para un sistema con
  obligaciones de cumplimiento (ver `docs/security/compliance-notes.md`),
  perder una entrada de auditoría en silencio es peor que bloquear un
  login por un problema transitorio de escritura.
- **Loguear también los intentos con email desconocido** (con
  `entity_id` nulo o un centinela): descartado — `entity_id` es
  `NOT NULL` por diseño (`migrations/0001_init.sql`) porque el propósito
  de esta tabla es trazabilidad sobre una entidad real, y cambiar ese
  contrato para acomodar "alguien probó un email que no existe" hubiera
  sido una desviación mayor sin necesidad real (ya hay throttling de
  intentos fallidos por otro mecanismo).

## Ver también
- `docs/adr/0013-jwt-session-authentication.md`
- `docs/adr/0014-row-level-security-policies.md`
- `docs/business/roles-and-permissions.md`
- `backend/internal/adapters/http/handler/authz.go`
- `backend/internal/adapters/postgres/repository/audit.go`
