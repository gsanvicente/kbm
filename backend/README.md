# backend

Go backend for Koons Balance Management (KBM) — part of the `kbm` monorepo.
Hexagonal architecture (ports & adapters), organized as a modular monolith
so bounded contexts (clients/hierarchy, cardholders/cards, ledger,
approvals, reconciliation) can later be split into services without
redesigning the domain.

Cross-cutting decisions (ADRs), business rules, and security docs live at
the repo root under `../docs/`. This folder only holds decisions local to
the backend implementation (`docs/tdr/`) — see the root README for the
"no development without documentation" rule.

## Layout

```
cmd/api          entrypoint: HTTP server (driving adapter)
cmd/worker        entrypoint: outbox relay / async jobs

internal/domain          business entities + rules, no external deps
internal/application
  ports/                 interfaces the domain needs from the outside world
  usecase/command/       state-mutating use cases (CQRS-lite write side)
  usecase/query/         read-only use cases (CQRS-lite read side)
internal/adapters
  http/                  REST handlers, middleware, DTOs (driving adapter)
  memory/                 in-memory repositories for cards/ledger/cardholder
                          login — modo demo explícito
                          (STORAGE_BACKEND=memory), see
                          docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md
                          and docs/tdr/0003-in-memory-repository-adapter.md
  postgres/               repositories + sqlc + domain<->row mappers — el
                          backend por defecto (STORAGE_BACKEND=postgres),
                          see docs/tdr/0004-postgres-repository-adapter.md
  processor/              external card processor gateway
  queue/{local,sqs}       async messaging, swappable per environment
  auth/{local,cognito}    identity provider, swappable per environment
  outbox/                 relays outbox_events to the queue adapter
internal/platform/config  env-based configuration loading

migrations/          SQL schema (source of truth; also mounted into the
                     local Postgres container for automatic init)
scripts/init-db/     local-only seed data (test clients/users/cards)
api/openapi.yaml     API contract consumed by ../admin and ../cardholder
deploy/docker/       Dockerfile for AWS deployment (not used locally)
docs/tdr/            technical decisions local to this component
```

## Running locally — Postgres real (persistente, vía Podman) — default

`cmd/api` corre contra `internal/adapters/postgres/` por default
(`STORAGE_BACKEND=postgres`, ver
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
y `docs/tdr/0004-postgres-repository-adapter.md`). Requiere Go 1.23+ y
[Podman](https://podman.io) (no Docker Desktop, ver
`docs/adr/0004-aws-fargate-terraform-local-no-containers.md`) — la app
en sí sigue corriendo nativa, nunca en contenedor, en desarrollo local.

```
brew install podman podman-compose   # una sola vez
podman machine init && podman machine start   # una sola vez
cp .env.example .env
make db-up      # levanta Postgres, aplica migrations/*.sql y
                # scripts/init-db/001_seed.sql automáticamente la primera vez
make run        # go run ./cmd/api
make run-worker # en otra terminal, go run ./cmd/worker
```

Es el que hoy usan `../admin` y `../cardholder` — **ambas apps esperan
este proceso en `127.0.0.1:8080`** para listar tarjetas, ver saldos o
transferir. Los datos ahora **persisten** entre reinicios del backend y
del propio contenedor — el volumen (`kbm_postgres_data`) es nombrado y
sobrevive a `podman compose down` (o `make db-down`) sin bandera `-v`.
Verificado en vivo, incluyendo tras el cambio a este adaptador: se bajó
el contenedor por completo y se volvió a levantar sin perder los datos
sembrados ni el resultado de operaciones hechas contra la API mientras
tanto (asignaciones, transferencias). `make db-reset` sí lo borra a
propósito (`down -v`), para cuando se edite el schema o el seed y haga
falta reaplicar desde cero — necesario también si tu Postgres local
todavía tiene el volumen de antes de `migrations/0002_card_pan_hash_and_blocked_reason.sql`,
ya que `/docker-entrypoint-initdb.d` solo corre en un volumen nuevo.

Si `DATABASE_URL` no está configurada, `cmd/api` falla al arrancar con
un mensaje explícito — no cae en silencio al modo memoria.

## Running locally — modo demo (en memoria, sin Postgres)

`STORAGE_BACKEND=memory go run ./cmd/api` corre contra
`internal/adapters/memory/` en su lugar — sin Podman, sin `.env`, datos
sembrados en memoria en cada arranque y **nunca persistidos**. Se
conserva a propósito para pruebas rápidas de UI que no necesitan que el
dato sobreviva un reinicio. Ver
`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` y
`docs/tdr/0003-in-memory-repository-adapter.md`.

```
STORAGE_BACKEND=memory go run ./cmd/api
```

## Deploying (later)

`deploy/docker/Dockerfile` builds the same binary as a minimal container
image for ECS Fargate. Nothing in the app code depends on being
containerized — it's an additive step, not a rewrite.

See `SECURITY.md` for the security posture this project is held to.
