# ADR-0014: Políticas de Row-Level Security (Fase 2 de aislamiento por tenant)

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
habilitó RLS en las tablas por Cliente pero dejó explícitamente las
políticas para después, porque escribirlas sin una identidad de llamador
verificada hubiera sido seguridad de fachada — cualquiera podría declarar
el `client_id` que quisiera. `docs/adr/0013-jwt-session-authentication.md`
(Fase 1) cerró esa precondición: cada request ya llega con un JWT
verificado. Este ADR es la Fase 2: las políticas en sí.

Al implementar esto se encontraron dos problemas de diseño que no eran
obvios de antemano:

1. **El backend se conectaba como `kbm`**, el rol `POSTGRES_USER` que
   Docker usa para correr los scripts de inicialización — ese mismo rol
   es superusuario y dueño de todas las tablas. RLS **nunca** se aplica a
   un superusuario ni al dueño de una tabla, sin excepción — escribir
   políticas sin cambiar esto hubiera sido código muerto: compilan,
   corren, y no filtran nada.
2. **`IsClientOperable` necesita ver los ANCESTROS de un Cliente**, no
   sus descendientes — pero el alcance normal de un miembro de staff
   (`app.accessible_client_ids`) es exactamente lo opuesto: su propio
   Cliente más sus descendientes (ver
   `docs/business/roles-and-permissions.md`, "Herencia sobre la jerarquía
   padre/hija"). Si esa verificación corriera con el alcance normal del
   llamador, un padre inactivo por *encima* de su alcance se volvería
   invisible bajo RLS, y la función devolvería "operable" por defecto —
   un falso negativo que hubiera roto en silencio la cascada de
   inactividad documentada en `docs/business/desactivacion-de-clientes.md`.
   Se encontró y verificó en vivo antes de cerrar este incremento (ver
   "Consecuencias").

## Decisión
1. **Nuevo rol `kbm_app`** (migración `migrations/0005_row_level_security_policies.sql`),
   sin privilegios de superusuario y sin ser dueño de ninguna tabla —
   solo `GRANT SELECT, INSERT, UPDATE, DELETE` explícito sobre el schema
   `public` (más `ALTER DEFAULT PRIVILEGES` para que migraciones futuras,
   corridas como `kbm`, no requieran un GRANT manual adicional). Las
   migraciones siguen corriendo como `kbm` (el mecanismo de
   inicialización de Docker siempre usa `POSTGRES_USER`); solo el
   proceso de la API/worker en ejecución cambia a `kbm_app`
   (`DATABASE_URL` en `.env`/`.env.example`).
2. **Una función SQL `app_client_accessible(target_client_id)`**
   reutilizada por las 14 políticas, en vez de repetir la expresión:
   ```sql
   current_setting('app.accessible_client_ids', true) = '*'
       OR target_client_id::text = ANY(string_to_array(current_setting('app.accessible_client_ids', true), ','))
   ```
   `'*'` es el centinela para alcance global (Super Admin, y los dos
   endpoints de login — ver punto 4). Sin GUC fijado, `current_setting`
   devuelve `''`, que no calza con ningún id real — **falla cerrado**,
   nunca abierto.
3. **Una política `tenant_isolation` por tabla**, las 13 con columna
   `client_id` directa comparando esa columna; `concentrator_entries`
   (la única sin columna `client_id` propia — ver
   `migrations/0001_init.sql`) usa una subquery contra
   `concentrator_accounts`. `client_settings` usa su propia PK
   (`client_id`), `clients` usa su propio `id` (representa al tenant, no
   tiene una columna `client_id` separada).
4. **`internal/adapters/postgres/repository/rls.go`** (nuevo) computa el
   GUC por transacción: lee el `client_id` del llamador desde
   `ports.CallerClientIDFromContext` (fijado por un middleware nuevo en
   `handler.Routes()`, justo después de `RequireAuth`, que traduce las
   claims JWT ya verificadas), y si no es global, expande a su subárbol
   completo vía `client_hierarchy` (una sola query, sin RLS —
   `client_hierarchy` nunca la tuvo habilitada). El valor se fija con
   `SET LOCAL` dentro de una transacción por operación (`beginRLS`/
   `withRLS`) — nunca `SET` a nivel de sesión, porque las conexiones se
   comparten desde un pool: un valor de sesión se filtraría al siguiente
   request no relacionado que tome esa misma conexión.
5. **`IsOperable` (client.go) corre siempre con RLS bypaseado**
   (`withRLSBypass`, GUC = `'*'`), no solo en los dos logins — es un
   derivado de estado de un `client_id` ya conocido por quien pregunta
   (nunca una lista que pueda filtrar datos de otro tenant), y necesita
   ver toda la cadena de ancestros para detectar una cascada de
   inactividad, sin importar el alcance normal del llamador. Ver
   "Contexto", punto 2.
6. **Los dos logins (`Store.Login`, `StaffAuthStore.Login`) también
   bypasean RLS** para su búsqueda por email — a esa altura todavía no
   existe ninguna identidad de llamador que resolver (es justo lo que
   ese método determina). Es seguro: ambas queries están indexadas por
   una columna única y devuelven cuando mucho una fila, nunca una lista
   que pueda cruzar tenants.
7. **Cada método de `Store`/`ManagementStore`/`StaffAuthStore` que toca
   una tabla protegida por RLS ahora corre su(s) query(s) dentro de
   `withRLS`** en vez de llamar `s.q` directamente — un refactor mecánico
   de los ~69 sitios de llamada across `client.go`, `cards.go`,
   `ledger.go`, `treasury.go`, `approval.go`, `claims.go`,
   `cardholder_management.go`, `transfer.go`. Los métodos que ya abrían
   su propia transacción (`Create`, `Update` de Cliente; `Assign` de
   Cards) solo cambiaron `s.pool.Begin` por `s.beginRLS`; los que hacían
   una sola query directa se envolvieron en `s.withRLS(ctx, func(q) {...})`.
   La orquestación de más alto nivel (`approval.go`'s `tryExecute`,
   `Request`, `Approve`, `Reject`) sigue componiendo llamadas a métodos
   ya envueltos, cada uno con su propia transacción corta — mismo
   criterio "nunca a medias pero no necesariamente una sola transacción
   gigante" que el código ya tenía antes de este cambio.

## Consecuencias
- Verificado en vivo, con el backend corriendo de verdad como `kbm_app`
  contra Postgres (no solo con tests): un Operador de Subsidiaria A ve
  su propia empresa y las filiales debajo de ella, nunca Subsidiaria B
  ni sus datos (Concentradora, Cardholders, movimientos) — confirmado
  tanto por la API (404/lista vacía) como directamente en `psql` como
  `kbm_app` (conteos de filas reales antes/después de fijar el GUC).
  También se verificó la política basada en subquery de
  `concentrator_entries`: una cuenta con movimientos reales en la base
  de datos devuelve lista vacía para un llamador sin acceso a ella.
- Se verificó explícitamente el caso de riesgo del punto 2 de
  "Contexto": desactivar Grupo Koons Holding (el padre) sigue
  bloqueando el login de `operador.subA` (una subsidiaria, fuera del
  alcance de RLS de ese propio usuario) — sin el bypass de `IsOperable`
  esto se hubiera roto en silencio.
- `go build/vet/test` sobre todo el módulo, y los tests existentes de
  `internal/adapters/http/handler` (que corren contra el adaptador en
  memoria, sin RLS) siguen en verde sin cambios — el adaptador en
  memoria no participa de este incremento en absoluto.
- El rol `kbm_app` y su contraseña de desarrollo
  (`kbm_app_dev_only`, ver `.env.example`) son locales — igual criterio
  que `LocalDevOnly123!` para los usuarios de la aplicación: nunca
  usarlos así en un ambiente real.
- Un método nuevo en `internal/adapters/postgres/repository` que olvide
  usar `withRLS`/`beginRLS` y llame `s.q` directamente sigue compilando
  y corriendo — Postgres no avisa, simplemente empieza a devolver cero
  filas para cualquier llamador con alcance no-global. No hay ningún
  linter ni test que detecte este olvido automáticamente; queda como
  disciplina de code review, documentada aquí para quien toque este
  paquete después.
- Un hallazgo lateral, no corregido en este incremento (fuera de
  alcance, comportamiento preexistente sin cambios): `Approve`/`Reject`
  en `approval.go` leen la operación con `SELECT ... FOR UPDATE` en una
  transacción que se cierra (commit) *antes* de llamar `tryExecute`, y
  el `UPDATE` de estado final ocurre en una tercera transacción
  separada — dos llamadas concurrentes a `Approve` sobre la misma
  operación pendiente podrían, en teoría, ejecutarla dos veces antes de
  que cualquiera marque el estado como resuelto. Esto ya existía antes
  de este cambio (no lo introduce ni lo empeora la migración a
  `withRLS`); se deja anotado para una revisión futura, no se atacó aquí
  porque no formaba parte del alcance pedido (RLS).

## Alternativas consideradas
- **`FORCE ROW LEVEL SECURITY` en vez de un rol nuevo**: descartado —
  `FORCE` solo cambia el comportamiento para el *dueño* de la tabla; un
  superusuario como `kbm` la sigue bypaseando siempre, sin excepción.
  Sin un rol no-superusuario, ninguna combinación de `FORCE`/políticas
  tiene efecto alguno.
- **Política por rol de negocio (`super_admin`, `client_admin`...) en
  vez de por GUC de client_id**: descartado — el modelo de acceso real
  es "este client_id y su subárbol", no el rol en sí (un Operador y un
  Admin Cliente del mismo Cliente ven exactamente los mismos datos,
  solo difieren en qué *acciones* pueden tomar sobre ellos — eso ya lo
  decide `admin/` del lado del cliente, no es responsabilidad de RLS).
- **Calcular `accessible_client_ids` una sola vez en el middleware HTTP
  y pasarlo ya resuelto por el contexto** (en vez de que el adaptador
  Postgres lo recalcule con una query a `client_hierarchy` en cada
  transacción): descartado por capas — el middleware HTTP no debería
  saber nada de Postgres ni de cómo se resuelve una jerarquía; el
  adaptador Postgres es quien conoce ese detalle. El costo real es una
  query adicional, barata, por transacción, no por request (Login no la
  paga en absoluto gracias al bypass).
- **Dejar `client_settings`/`clients` fuera de RLS por ser "de
  configuración, no de datos operativos"**: descartado — ambas tablas sí
  contienen información específica de un Cliente que un tenant sin
  acceso no debería poder leer (límite de tarjetas, expediente KYB
  completo).

## Ver también
- `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
- `docs/adr/0013-jwt-session-authentication.md`
- `docs/security/threat-model.md`
- `backend/migrations/0005_row_level_security_policies.sql`
- `backend/internal/adapters/postgres/repository/rls.go`
