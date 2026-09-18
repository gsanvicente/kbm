# admin

Flutter web-first app for KBM's administrative roles (Super Admin, Admin
Cliente, Operador, Auditor) — part of the `kbm` monorepo. Shares no code
with `../cardholder` — kept as a separate app so admin logic/data never
ships inside the cardholder mobile bundle.

Cross-cutting decisions and business rules live at the repo root under
`../docs/`. This folder only holds decisions local to this app
(`docs/tdr/`) — see the root README for the "no development without
documentation" rule.

## Layout

```
lib/
  app/            app bootstrap, routing, theming
  core/
    api/          generated OpenAPI client wrapper (see below)
    models/       shared data models
    utils/
  features/
    auth/
    clients/               empresa + jerarquía padre/hijas
    cardholders/
    cards/
    balance_operations/    carga/débito/transferencia, historial
    approvals/             cola de aprobación (Admin Cliente)
  shared_widgets/
```

## Setup

```
flutter pub get
flutter run -d web-server --web-port=8765 --web-hostname=127.0.0.1
```

Cards and Ledger need `../backend`'s shared in-memory process running on
`127.0.0.1:8080` first — see `../backend/README.md`. Without it, the app
still launches but any screen touching cards/balances will fail to load.
Every other domain (Clientes, Tarjetahabientes, Tesorería, Aprobaciones,
Reclamos) stays 100% in-memory Dart, no backend needed — see
`../docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`.

`flutter test` never needs the backend running: `KbmAdminApp()` (no
`backendClient` passed) builds Cards/Ledger against the same in-memory
Fakes as before — required because `TestWidgetsFlutterBinding`
intercepts all `HttpClient` traffic and always returns 400, so a real
backend is impossible to exercise from a widget test. `main.dart` is the
only place that passes a real `KbmBackendClient`.

## API contract

Consumes `../backend/api/openapi.yaml`. As of ADR-0010, `HttpCardRepository`
and `HttpLedgerRepository` (`lib/features/cards/http_card_repository.dart`,
`lib/features/ledger/http_ledger_repository.dart`) are hand-written against
`package:http` — a documented, temporary exception to the "generate from
OpenAPI" rule (`../docs/adr/0006-openapi-contract.md`), scoped to this
interim in-memory backend. Client generation resumes once the real
Postgres-backed backend replaces it.
