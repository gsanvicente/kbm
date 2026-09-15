# cardholder

Flutter app for the tarjetahabiente self-service experience — web portal
and mobile app from a single codebase, part of the `kbm` monorepo.
Separate from `../admin`: this app only ever talks about the signed-in
cardholder's own data, never other tenants or other cardholders.

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
    models/
    utils/
  features/
    auth/
    balance/          consulta de saldo y movimientos
    cards/            ver estado de tarjeta, congelar/bloquear la propia
    reload_request/   solicitar recarga (sujeta a reglas de aprobación)
  shared_widgets/
```

## Setup (Flutter SDK not yet installed on this machine)

This scaffolding was created by hand (no `flutter` binary available at
scaffold time). Once the Flutter SDK is installed, generate the platform
folders (android/ios/web) without touching the existing `lib/` structure:

```
flutter create --platforms=web,android,ios .
flutter pub get
flutter run -d chrome   # or -d <device> for mobile
```

## API contract

Consumes `../backend/api/openapi.yaml`. Generate the Dart client (e.g. via
`openapi-generator`) into `lib/core/api/` rather than hand-writing HTTP
calls.

## Security note

This app's auth flow (session/token handling, biometric unlock) is a
separate identity plane from `../admin` — see `../docs/security/` before
implementing local token storage.
