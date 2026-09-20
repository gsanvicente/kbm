# cardholder

Flutter app for the tarjetahabiente self-service experience — web portal
and mobile app from a single codebase, part of the `kbm` monorepo.
Separate from `../admin`: this app only ever talks about the signed-in
cardholder's own data, never other tenants or other cardholders. By
ADR-0002, it shares **no runtime code** with `../admin` — this app's
models, repositories and widgets are all its own, even where they look
structurally similar to `admin`'s.

Cross-cutting decisions and business rules live at the repo root under
`../docs/`. This folder only holds decisions local to this app
(`docs/tdr/`) — see the root README for the "no development without
documentation" rule.

## Layout

```
lib/
  app/
    home_shell.dart       post-login: selector si hay >1 tarjeta, si no entra directo
    cardholder_shell.dart marco de navegación persistente (Inicio/Movimientos) por tarjeta
  core/
    fake_backend.dart  in-memory backend used only by widget tests, see below
    http_backend.dart  real backend, used by main.dart
    http/              hand-written HTTP client (ADR-0010 point 7)
    models/
    utils/
  features/
    auth/             login
    cards/            home_tab (saldo + Transferir), movements_tab (Movimientos)
    transfer/         transferencia C2C — ver docs/feature/transferencia-c2c-tarjetahabiente/
  shared_widgets/
    payment_card_visual.dart  tarjeta visual — mismo activo/diseño que admin/, nunca el saldo
```

`features/balance/` and `features/reload_request/` are still empty
placeholders for work not started yet — "recarga" (topping up a card
from an external source) is explicitly out of scope of the whole product
in this iteration, see `docs/business/autoservicio-tarjetahabiente.md`,
"Fuera de alcance"; that folder name predates that decision and should
not be read as a planned feature.

## Estado actual (2026-09-19)

Implementado: login (con la misma regla de Cliente/Tarjetahabiente
inactivo que `admin/`), selector de tarjeta cuando hay más de una,
navegación persistente por tarjeta (Inicio/Movimientos, `CardholderShell`)
con tarjeta visual (`PaymentCardVisual`) en vez de solo texto, Movimientos
(lista de la cuenta, sin filtro de fechas), la transferencia C2C completa
— ver `docs/feature/transferencia-c2c-tarjetahabiente/README.md` — y el
bloqueo temporal de la propia tarjeta ("Congelar vs. bloquear", ver
`docs/business/autoservicio-tarjetahabiente.md`).

Pendiente: filtro de fechas/resumen de periodo en Movimientos, presentar
reclamos — ver "Pantallas" en
`docs/feature/portal-autoservicio-tarjetahabiente/README.md` para el
detalle.

## Backend: compartido en memoria con `admin/` (ver ADR-0010)

`HttpCardholderBackend` (`lib/core/http_backend.dart`) es la
implementación real: habla por HTTP contra el mismo proceso Go que
`admin/`, `../backend` en `127.0.0.1:8080` — una transferencia hecha
aquí sí se refleja en `admin/`, ya no es la limitación conocida que
`docs/feature/transferencia-c2c-tarjetahabiente/README.md` documentaba.
El cálculo del HMAC del PAN vive enteramente en ese backend, ya no en
esta app. Cliente HTTP escrito a mano (`package:http`, no generado desde
OpenAPI — ver el punto 7 de la ADR para el porqué); `../backend/api/openapi.yaml`
documenta igual el contrato.

`lib/core/fake_backend.dart` (`FakeCardholderBackend`) sigue existiendo,
pero solo para los widget tests: `KbmCardholderApp()` sin argumentos (lo
que usa `test/widget_test.dart`) la usa por defecto, porque
`TestWidgetsFlutterBinding` intercepta todo `HttpClient` y siempre
responde 400 — un backend real es imposible de ejercer ahí. Su universo
de datos es independiente del de `admin/`, solo coincide en IDs por
continuidad narrativa (ADR-0010, punto 8). `main.dart` es el único lugar
que pasa un `KbmBackendClient` real.

## Setup

```
flutter pub get
flutter run -d web-server --web-port=8766 --web-hostname=127.0.0.1
```

Necesita `../backend` corriendo primero en `127.0.0.1:8080` — ver
`../backend/README.md`. `flutter test` no lo necesita: usa el fake, ver
arriba.

Puerto `8766` a propósito (junto al `8765` de `admin/`) para poder correr
ambas apps al mismo tiempo durante desarrollo, contra el mismo backend.

## Probar en mobile/desktop nativo (2026-09-19)

`android/` y `macos/` ya se generaron (`flutter create --platforms=android,macos .`,
sin tocar `lib/`) — `ios/` todavía no, se agrega igual cuando haga falta.
El código Dart no cambia entre plataformas (nada de `dart:html`/`kIsWeb`);
lo que sí cambia es cómo cada una llega al backend en `127.0.0.1:8080` y
qué permisos de red nativos hace falta declarar:

- **macOS** (`flutter run -d macos`): comparte el loopback de esta
  máquina, así que el default (`127.0.0.1:8080`) funciona tal cual — pero
  macOS sandboxea la app por default y **no** da salida de red a menos
  que se declare. Se agregó `com.apple.security.network.client` a
  `macos/Runner/{Debug,Release}.entitlements` — sin esto, toda petición
  de `HttpCardholderBackend` falla en silencio.
- **Emulador de Android** (`flutter run -d <emulator-id>`): tiene su
  propia red virtual — `127.0.0.1` ahí apunta al emulador, no al host.
  Se resuelve con `10.0.2.2` en vez de `127.0.0.1`, nunca tocando dónde
  escucha el backend (sigue en loopback, ver threat-model punto 15).
  `lib/main.dart` acepta esto vía `--dart-define=KBM_BACKEND_URL=http://10.0.2.2:8080`,
  sin hardcodear nada específico de Android en el código. Android 9+
  también bloquea HTTP sin cifrar por default (el backend interino no
  tiene TLS todavía) — se agregó
  `android/app/src/debug/res/xml/network_security_config.xml`
  (solo debug, nunca se mergea en release) permitiendo cleartext hacia
  `10.0.2.2`/`127.0.0.1`/`localhost`.
- **Dispositivo físico** (Android o iOS): no comparte el loopback de esta
  máquina — necesitaría la IP de LAN, lo cual implica decidir si el
  backend escucha temporalmente fuera de `127.0.0.1`. Deliberadamente no
  resuelto todavía — es una excepción a una decisión de seguridad ya
  documentada (threat-model punto 15), se pregunta antes de tocarla.

Verificado en vivo (emulador Android, API 34, arm64) contra el backend
real: login, saldo, Movimientos y el ciclo completo de bloqueo
temporal/quitarlo — los tres corriendo con datos reales del mismo
backend que usa `admin/`.

Este entorno de desarrollo no tenía Android SDK ni Xcode completo
instalados — si vuelve a hacer falta desde cero: `brew install openjdk@17`
(Gradle actual no soporta el JDK más nuevo, ver más abajo) y
`brew install --cask android-commandlinetools`, luego
`flutter config --jdk-dir="$(brew --prefix openjdk@17)"` y
`flutter config --android-sdk "$(brew --prefix)/share/android-commandlinetools"`.

**Nota de esta máquina**: `brew install openjdk` (sin versión) instala el
JDK más reciente, que Gradle todavía no soporta del todo ("Unsupported
class file major version") — por eso el JDK que realmente usa Flutter
para Android es la versión 17 fijada explícitamente vía
`flutter config --jdk-dir`, no la que quede primero en el `PATH`.

## Credenciales de prueba

Mismo password de desarrollo para todas: `LocalDevOnly123!`.

| Email | Escenario |
|---|---|
| `juan.perez@cardholder.test` | Una tarjeta, Koons Subsidiaria A, saldo $1,250.00 |
| `ana.torres@cardholder.test` | Una tarjeta, Koons Subsidiaria A — destino válido para transferencias de Juan |
| `maria.gomez@cardholder.test` | Una tarjeta, Koons Subsidiaria B — destino inválido para Juan (otro Cliente) |
| `carlos.ruiz@cardholder.test` | Tarjeta bloqueada por el staff — sin botón Transferir |
| `sofia.ramirez@cardholder.test` | Dos tarjetas — ejercita el selector de "Mis tarjetas" |
| `inactivo@cardholder.test` | Tarjetahabiente inactivo — login rechazado (Capa 1) |

## Security note

This app's auth flow (session/token handling, biometric unlock) is a
separate identity plane from `../admin` — see `../docs/security/` before
implementing local token storage. The PAN-hash HMAC key lives in
`../backend` now (`internal/adapters/memory/repository`) — a hardcoded
dev-only constant, per `backend/docs/tdr/0003-in-memory-repository-adapter.md`.
`FakeCardholderBackend`'s own copy (used only by widget tests) is the
same kind of dev-only constant, never reused near a real backend.
