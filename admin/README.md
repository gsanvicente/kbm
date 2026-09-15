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

## Setup (Flutter SDK not yet installed on this machine)

This scaffolding was created by hand (no `flutter` binary available at
scaffold time). Once the Flutter SDK is installed, generate the platform
folders (android/ios/web) without touching the existing `lib/` structure:

```
flutter create --platforms=web,android,ios .
flutter pub get
flutter run -d chrome
```

## API contract

Consumes `../backend/api/openapi.yaml`. Generate the Dart client (e.g. via
`openapi-generator`) into `lib/core/api/` rather than hand-writing HTTP
calls.
