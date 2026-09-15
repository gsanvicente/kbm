# Security posture — kbm-backend

This platform manages card/cardholder balances and will undergo a security
audit. Treat every design/code decision here through that lens, not as an
afterthought.

## Reporting
Internal project for now — report suspected vulnerabilities directly to the
project owner rather than a public issue.

## Threat model notes (living list, expand as features land)
- **Broken access control**: authorization must be enforced in
  `internal/application/ports` (AuthorizationPort), invoked by every use
  case — never only at the HTTP handler layer. See ADR note in
  `internal/application/ports/doc.go`.
- **Tenant isolation**: defense-in-depth — application-layer checks against
  `client_hierarchy` AND Postgres Row-Level Security on every tenant-scoped
  table (see `migrations/0001_init.sql`). A bug in one layer should not be
  enough to leak cross-tenant data.
- **Ledger integrity**: `ledger_entries` is append-only at the DB level
  (trigger forbids UPDATE/DELETE) — balance history must not be editable
  even with direct DB access via a compromised app credential.
- **Secrets**: never commit real credentials. `.env` is gitignored;
  `.env.example` only holds placeholders. Local seed passwords
  (`scripts/init-db/001_seed.sql`) are for local Postgres only and must
  never work against staging/prod.
- **External processor integration**: `internal/adapters/processor` and any
  inbound webhook handler must validate signatures/authenticity of
  processor callbacks before trusting them — TODO once that adapter is
  implemented.
- **Dependency hygiene**: run `go vet`/`govulncheck` before adding new
  dependencies once the module has real dependencies beyond the standard
  library.

## Out of scope for now
Formal pentest, dependency scanning in CI, and secrets-manager integration
are deferred to the AWS deployment phase but the adapters (auth/cognito,
queue/sqs) are structured so adding them doesn't require touching domain
code.
