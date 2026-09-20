# TDR-0004: Adaptador de persistencia Postgres (`internal/adapters/postgres/`)

- Estado: Aceptada
- Fecha: 2026-09-20
- Alcance: decisión local al backend

## Contexto
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
(raíz) decide que Postgres pasa a ser el backend por defecto de
Cards/Ledger, con el modo en memoria (`docs/tdr/0003-in-memory-repository-adapter.md`)
como opción explícita. Este TDR es la implementación de esa decisión:
cómo se estructura el adaptador Postgres real, con el mismo alcance que
ya cubre el adaptador en memoria — Cards, Ledger, login del portal de
autoservicio y transferencias C2C. Clientes, Tarjetahabientes (KYC),
Aprobaciones, Tesorería y Reclamos seguían 100% en los fakes de Dart de
`admin/` en ese momento — migraron a Postgres poco después, ver
`docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`.
El adaptador en memoria (modo demo) nunca cubrió esos dominios ni los
cubrirá — quedan fuera de su alcance, ver ADR-0010.

## Decisión
`internal/adapters/postgres/repository.Store` implementa los mismos
cuatro puertos que `internal/adapters/memory/repository.Store`
(`CardRepository`, `LedgerRepository`, `CardholderAuthRepository`,
`TransferService`) — mismo criterio de "un solo Store" que ya justificó
TDR-0003. `cmd/api/main.go` elige cuál construir según
`STORAGE_BACKEND` (`internal/platform/config`), default `"postgres"`.

- **sqlc** (ver `docs/tdr/0001-sqlc-pgx-over-orm.md`) genera el código de
  acceso a datos desde `internal/adapters/postgres/sqlc/queries/*.sql`
  hacia `internal/adapters/postgres/sqlc/gen` (paquete `sqlcgen`,
  `sql_package: pgx/v5`). `sqlc.yaml` fuerza overrides explícitos
  (`uuid`→`string`, `numeric`→`float64`, `timestamptz`→`time.Time`) para
  que el código generado sea ergonómico y cercano a los tipos de dominio
  — sin esto, sqlc genera `pgtype.Numeric`/`pgtype.Timestamptz` por
  default, que habría hecho el mapper mucho más ruidoso sin ganar nada.
- **`internal/adapters/postgres/mapper`** traduce cada `*Row` generado a
  entidades de dominio — nunca al revés, el dominio nunca importa
  `sqlcgen`. Como cada query de `cards.sql` selecciona exactamente las
  mismas columnas en el mismo orden, sqlc genera un `*Row` distinto pero
  estructuralmente idéntico por query; el mapper define un solo
  `CardRow` canónico y cada llamador hace una conversión de struct
  (`mapper.CardRow(row)`), válida en Go porque el layout subyacente
  coincide — evita que el mapper dependa de N tipos generados casi
  iguales.
- **Concurrencia**: el adaptador en memoria usa un `sync.RWMutex` por
  agregado; aquí el equivalente es bloquear la fila de
  `ledger_accounts` (`SELECT ... FOR UPDATE`) antes de leer el saldo
  vigente en `PostEntry`, dentro de una transacción — dos operaciones
  concurrentes sobre la misma tarjeta se serializan a nivel de Postgres,
  no de proceso.
- **Disponibilidad de una tarjeta al asignar** (`Assign`) se revalida
  atómicamente en el propio `UPDATE ... WHERE status = 'unassigned'`, no
  con un `SELECT` previo separado — un check-then-act ahí sí sería una
  carrera real entre dos asignaciones concurrentes a la misma tarjeta,
  cosa que el mutex del adaptador en memoria prevenía gratis y que aquí
  hay que prevenir explícitamente.
- **Límite de intentos fallidos de transferencia C2C** (ver
  `docs/security/threat-model.md` punto 12) sigue siendo un mapa en
  memoria de proceso (`Store.failedAttempts`), igual que en el adaptador
  en memoria — es un throttle de sesión, no un dato de negocio; no hay
  razón para que sobreviva un reinicio del backend, y meterlo en Postgres
  solo para eso sería una tabla más sin beneficio real.
- **Login** verifica la contraseña con `bcrypt.CompareHashAndPassword`
  (`golang.org/x/crypto/bcrypt`) contra el hash sembrado con pgcrypto's
  `crypt(..., gen_salt('bf'))` — mismo formato bcrypt, ver
  `scripts/init-db/001_seed.sql`. `cardholder.Cardholder.Password` (que
  el dominio documenta como "texto plano, solo desarrollo") nunca se
  llena con el hash aquí — no hay ningún llamador después del login que
  lo necesite (confirmado: ninguna respuesta HTTP serializa ese campo).
- **Hash de PAN** (ver `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`)
  usa la misma llave de desarrollo hardcodeada que
  `internal/adapters/memory/repository/transfer.go` — no por relación
  técnica entre ambos adaptadores, sino para que el PAN sintético
  sembrado en `scripts/init-db/001_seed.sql` (calculado con el `hmac()`
  de pgcrypto) y el que este adaptador calcula en Go para resolver una
  transferencia produzcan el mismo hash.
- **`ResolveDestination`** no filtra por `status` de la tarjeta
  destino — mismo comportamiento heredado del adaptador en memoria (una
  tarjeta bloqueada/congelada que calce por PAN sigue siendo "encontrada"),
  no una decisión nueva de este TDR.

### Cambios de esquema que este adaptador necesitó
Ninguno de estos existía antes de este incremento — el schema original
(`migrations/0001_init.sql`) nunca se había ejercido contra un
repositorio real:
- `cards.pan_hash` (nullable) — no existía ninguna columna para esto.
  Ver `migrations/0002_card_pan_hash_and_blocked_reason.sql`.
- `cards.blocked_reason` (`card_blocked_reason` enum nuevo,
  `manual`/`cardholder_inactive`) — el adaptador en memoria lo llevaba
  solo en Go (`card.BlockedReason`); la tabla nunca tuvo dónde
  guardarlo. Restringido con un `CHECK` a que solo tenga valor cuando
  `status = 'blocked'`.

`scripts/init-db/001_seed.sql` se actualizó para poblar ambas columnas, y
para darle una tarjeta a Ana Torres (antes intencionalmente sin
tarjeta) — mantenerla sin tarjeta habría hecho que el demo divergiera
entre el modo Postgres (ahora default) y el modo memoria, justo lo
opuesto a lo que busca ADR-0011.

## Consecuencias
- `admin/` y `cardholder/` no se enteran del cambio — consumen la misma
  API HTTP, y las interfaces de los puertos no cambiaron.
- Row-Level Security sigue habilitada sin políticas (ver ADR-0011,
  "Consecuencias") — la app se conecta como dueño de las tablas, que por
  default no está sujeto a RLS. Es una limitación conocida y documentada,
  no un olvido; escribir las políticas es trabajo futuro explícito.
- El adaptador en memoria (`internal/adapters/memory/`) no cambia y
  sigue siendo el modo demo explícito (`STORAGE_BACKEND=memory`) — útil
  para probar UI sin depender de Postgres corriendo.
- `go.mod` sube a `go 1.23` (antes `1.22`) porque `github.com/jackc/pgx/v5`
  lo requiere a partir de cierta versión — `deploy/docker/Dockerfile` se
  actualizó en el mismo cambio (`golang:1.22-alpine` → `golang:1.23-alpine`)
  para no romper el build de despliegue.

## Alternativas consideradas
- **GORM u otro ORM**: descartado, ver `docs/tdr/0001-sqlc-pgx-over-orm.md`
  — sigue aplicando sin cambios.
- **Guardar el motivo de bloqueo como texto libre en vez de un enum
  nuevo**: descartado — el resto del schema usa enums de Postgres para
  todo lo demás (`card_status`, `card_network`...); un texto libre habría
  sido inconsistente y sin validación a nivel de base de datos.
- **Llamar al procesador de PAN-hash en Go en vez de con `hmac()` de
  pgcrypto al sembrar datos**: no aplica todavía — el seed es datos de
  prueba locales, no un flujo de la aplicación; cuando exista la
  integración real del procesador (ver ADR-0011), el hash de una tarjeta
  real se calculará en Go al momento de la asignación, no al sembrar SQL.

## Ver también
- `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
- `docs/tdr/0001-sqlc-pgx-over-orm.md`
- `docs/tdr/0003-in-memory-repository-adapter.md` — el adaptador que este
  TDR complementa como default, no reemplaza.
