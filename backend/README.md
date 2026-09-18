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
                          login — temporary, see
                          docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md
                          and docs/tdr/0003-in-memory-repository-adapter.md
  postgres/               repositories + sqlc + domain<->row mappers (not
                          wired up yet — `memory/` is what's actually used
                          today, see ADR-0010)
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

## Running locally (current: in-memory, no Postgres)

As of `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`,
`cmd/api` runs against `internal/adapters/memory/` — no Docker, no
Postgres, no `.env` setup needed. It's the shared source of truth for
Tarjetas/Ledger/Tarjetahabiente-login used by both `../admin` and
`../cardholder` while developing — **both Flutter apps expect this
process running on `127.0.0.1:8080`** before they can list cards, show
balances, or transfer.

```
go run ./cmd/api
```

Data resets every time this process restarts (seeded fresh from
`internal/adapters/memory` on boot, same IDs the two Flutter apps'
former fake repositories used) — see the ADR for why this is accepted for
now.

## Running locally (later: real Postgres)

Requires Go 1.22+ and Docker (for Postgres only — the app itself runs
natively, no containers needed for the backend process). Not wired up to
`cmd/api` yet — this is the target state once
`internal/adapters/postgres/` replaces `memory/`.

```
cp .env.example .env
make db-up      # starts Postgres, applies migrations/0001_init.sql and
                # scripts/init-db/001_seed.sql automatically on first boot
make run        # go run ./cmd/api
make run-worker # in a separate terminal, go run ./cmd/worker
```

`make db-reset` wipes the local Postgres volume so the init scripts re-run
from scratch (useful after editing the schema or seed data).

## Deploying (later)

`deploy/docker/Dockerfile` builds the same binary as a minimal container
image for ECS Fargate. Nothing in the app code depends on being
containerized — it's an additive step, not a rewrite.

See `SECURITY.md` for the security posture this project is held to.
