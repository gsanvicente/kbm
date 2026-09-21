# ADR-0013: Sesión autenticada (JWT) para admin/ y cardholder/

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
`docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`
cerró con un hueco explícito: RLS (Row-Level Security) en Postgres no
tenía ninguna política escrita, porque escribir políticas atadas a un
GUC (`current_setting('app.accessible_client_ids')`) que el propio
llamador manda sin verificación no sería una protección real —
cualquiera podría declarar el `client_id` que quisiera. El backend
nunca había tenido ningún concepto de sesión: `internal/adapters/auth/
{local,cognito}` eran paquetes vacíos (solo `doc.go`), y toda
autenticación previa (login administrativo y de Tarjetahabiente) se
limitaba a verificar credenciales una vez, sin emitir nada que un
request posterior pudiera usar para probar quién lo hacía.

Se preguntó explícitamente cómo proceder, con dos opciones: dejar RLS
como hueco documentado, o construir sesión real primero. Se eligió
construir la sesión real — este ADR cubre esa pieza (Fase 1). RLS
(Fase 2) queda para un incremento posterior, ver "Consecuencias".

## Decisión
1. **JWT firmado con HMAC-SHA256** (`github.com/golang-jwt/jwt/v5`),
   usando el `JWT_SECRET` que ya existía en `config.go`/`.env.example`
   pero nunca se usaba. TTL fijo de 12 horas, sin refresh token — el
   mismo criterio de simplicidad que ya rige el resto del backend
   interino (ver `docs/tdr/0003-in-memory-repository-adapter.md`); se
   reconsidera si en producción real 12h resulta muy corto o muy largo.
2. **Un solo tipo de claims para dos audiencias.** `local.Claims` lleva
   un campo `Type` (`"staff"` o `"cardholder"`) que discrimina cuál de
   las dos identidades del backend representa el token — admin/ emite y
   consume tokens `staff`, cardholder/ emite y consume tokens
   `cardholder`. Se decidió un solo tipo de claims (no dos structs
   separados) porque ambos viajan por el mismo middleware
   (`RequireAuth`) y la mayoría de los endpoints "de alcance mixto"
   (ver punto 4) necesitan poder leer cualquiera de los dos sin dos
   rutas de código duplicadas.
3. **Dos middlewares, no un sistema de roles genérico.**
   `RequireAuth(issuer)` verifica la firma/expiración y guarda las
   claims en el `context.Context` de la petición; `RequireStaff` (se
   monta después, anidado) rechaza con 403 cualquier claim que no sea
   `staff`. No se construyó un sistema de permisos por rol en el
   backend — la UI de admin/ ya decide qué botones mostrar según
   `Role` (ver `docs/business/*`), y el backend solo necesitaba una
   frontera binaria "esto es de staff o no", no una por cada
   combinación de rol/operación.
4. **Ownership checks explícitos en los endpoints de alcance mixto.**
   Varios endpoints los usan tanto admin/ (staff, sin restricción) como
   cardholder/ (el propio Tarjetahabiente, nunca otro):
   - `GET /v1/cards?cardholder_id=X` y `GET /v1/cards/{id}` — un token
     `cardholder` solo puede leer sus propias tarjetas.
   - `GET /v1/cards/{id}/ledger` — mismo criterio, resuelto vía
     `Cards.GetByID` antes de devolver el ledger.
   - `POST /v1/cards/{id}/self-freeze`, `POST /v1/transfers/resolve`,
     `POST /v1/transfers/execute` — exclusivos de `cardholder`; un
     token `staff` los recibe como 404 genérico (nunca 403 — ver punto
     5). `execute` no lleva `cardholderId` en el cuerpo, así que se
     verifica dueño de `originCardId` vía `Cards.GetByID`.
   Los que ya eran exclusivamente de staff (`assignCard`,
   `setBlockStatus`, `postLedgerEntry`, `freezeCards`, y todo
   `handler_management.go`) se movieron bajo el grupo `RequireStaff` en
   vez de llevar el check a mano en cada uno.
5. **Un ownership check fallido devuelve `shared.ErrNotFound` (404), no
   403.** Mismo criterio que `Cards.SetFrozen` ya usaba para "Cliente
   inactivo" (nunca revelar si el recurso existe pero pertenece a
   alguien más) — un Tarjetahabiente pidiendo el `cardholder_id` de
   otro nunca debe poder distinguir "no existe" de "existe pero no es
   tuyo".
6. **`StaffAuthStore` nuevo para el adaptador en memoria
   (`STORAGE_BACKEND=memory`).** El login administrativo nunca había
   sido parte de su alcance (era 100% de `admin/`'s
   `FakeAuthRepository`, ver ADR-0010) — pero en cuanto
   `RequireStaff` empezó a exigirse en Cards/Ledger, el modo demo se
   hubiera vuelto inutilizable sin él. Se agregó con los mismos 5
   usuarios/contraseña que ya usaban `FakeAuthRepository` y el seed de
   Postgres, solo por continuidad de demo (sin relación técnica real
   entre las tres listas).
7. **CORS gana `Authorization` en `Access-Control-Allow-Headers`** —
   sin esto el navegador bloquea el header en la petición real tras el
   preflight, ya que admin/cardholder corren en un origen distinto al
   backend. De paso se corrigió `Access-Control-Allow-Methods`, que
   solo permitía `GET, POST` y ya le faltaban `PUT, DELETE` desde que
   Configuración de cliente (ADR-0012, punto 3 de su actualización)
   agregó esas rutas — un hueco real, no relacionado con JWT, que
   hubiera bloqueado esa pantalla en el navegador aunque los tests con
   fakes nunca lo detectaran.
8. **Los clientes HTTP de ambas apps Flutter guardan el token solo en
   memoria** (`KbmBackendClient.accessToken`, campo mutable, nunca
   persistido a `localStorage`/disco) y lo adjuntan automáticamente a
   cada request. `AuthRepository`/`CardholderAuthRepository` ganaron un
   método `logout()` (sin cuerpo por defecto — `implements` no hereda
   uno, ver nota de estilo en ambos `Fake*` con implementación vacía)
   que cada `AuthController` invoca antes de limpiar la sesión en la
   UI. Recargar la página exige volver a iniciar sesión — mismo
   comportamiento que ya existía (`Session`/`CardholderSession` tampoco
   sobrevivían un reload).

## Consecuencias
- Todo endpoint de `/v1/*` (salvo los dos logins y `/healthz`) ahora
  exige un JWT válido; los de `handler_management.go` además exigen que
  sea de tipo `staff`. Verificado en vivo contra Postgres: sin token
  (401), token inválido (401), token de Tarjetahabiente en endpoint de
  staff (403), ownership check cruzado (404 genérico) — ver
  `internal/adapters/http/handler/handler_test.go` para los mismos
  casos como tests automatizados.
- **RLS (Fase 2) sigue sin políticas** — este ADR resuelve la
  precondición que faltaba (identidad verificada por request) pero no
  escribe las políticas todavía. Wirear correctamente el GUC
  (`SET LOCAL app.accessible_client_ids` por transacción) requiere
  convertir del orden de 60-80 sitios de llamada directa
  `s.q.XXX(ctx, ...)` en `internal/adapters/postgres/repository/*.go` a
  un patrón transaccional que primero fije el GUC — un refactor grande
  de código ya en producción y probado, no incluido en este incremento;
  queda como decisión explícita pendiente para un futuro incremento.
- El `Handler` struct ganó un campo `Tokens *local.TokenIssuer`,
  requerido por `New(...)` — cualquier otro lugar que construya un
  `Handler` a mano (tests, herramientas) necesita pasarlo.
- `internal/adapters/memory/repository` ganó `StaffAuthStore`,
  ampliando ligeramente su alcance original (ver ADR-0010) solo para no
  romper el modo demo bajo el nuevo requisito universal de sesión.
- Ningún cambio de UI visible — ambas apps siguen mostrando las mismas
  pantallas; el token es un detalle de transporte invisible al usuario
  salvo que ahora, si el backend lo rechaza (p. ej. tras 12h), cualquier
  llamada falla con un error genérico de red hasta que se vuelva a
  iniciar sesión (no se construyó manejo especial de "token expirado"
  distinto de un error de red cualquiera — mismo nivel de granularidad
  que ya tenían ambos `AuthController` antes de este cambio).

## Alternativas consideradas
- **Dejar RLS como hueco documentado y no construir sesión real**:
  la opción presentada junto a la elegida; se descartó porque el pedido
  explícito era cerrar los huecos de integración de verdad, y unas
  políticas de RLS sin identidad verificada hubieran sido seguridad de
  fachada — peor que no tener RLS, porque hubiera dado una falsa
  sensación de protección.
- **Cognito real en vez de JWT local**: descartado por alcance —
  `internal/adapters/auth/cognito` sigue siendo un `doc.go` vacío,
  reservado para cuando el proyecto se despliegue a AWS de verdad (ver
  `docs/architecture.md`, postura "AWS-ready" pero desarrollo 100%
  local). Introducir Cognito ahora hubiera añadido una dependencia de
  red externa a un flujo de desarrollo que hoy corre sin contenedores
  ni servicios externos.
- **Refresh tokens**: descartado por ahora — con TTL de 12h y un
  entorno de desarrollo/demo, forzar un nuevo login cada 12h es
  aceptable; se reconsidera si esto llega a un ambiente con sesiones de
  usuario más largas.
- **Un rol/permiso por endpoint en el backend**: descartado — hubiera
  duplicado lógica que la UI de `admin/` ya implementa por rol (ver
  `docs/business/*`), sin que el backend tuviera hoy ningún caso real
  de "un `client_admin` puede pero un `operator` no" que ya no
  estuviera resuelto por RLS-pendiente o por la UI.
- **Construir RLS (Fase 2) en el mismo incremento**: descartado por
  riesgo — convertir todos los repositorios Postgres a un patrón
  transaccional nuevo es un refactor grande de código ya probado,
  mejor hecho como un incremento propio con su propia verificación,
  no apilado sobre este cambio ya extenso.

## Ver también
- `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`
- `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`
- `docs/security/threat-model.md`
- `backend/internal/adapters/auth/local/tokens.go`
- `backend/internal/adapters/http/middleware/auth.go`
