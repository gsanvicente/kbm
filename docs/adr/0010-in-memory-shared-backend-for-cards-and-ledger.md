# ADR-0010: Backend Go en memoria, compartido entre `admin` y `cardholder`, para Tarjetas y Ledger

- Estado: Aceptada
- Fecha: 2026-09-19

## Contexto
`admin/` y `cardholder/` son dos apps Flutter separadas (ADR-0002) que,
hasta ahora, corrían cada una contra su propio repositorio fake en
memoria — dos universos de datos completamente independientes, sin
relación entre sí. Esto dejó de ser aceptable en cuanto
`docs/feature/transferencia-c2c-tarjetahabiente/README.md` se implementó:
una transferencia hecha desde `cardholder/` necesita reflejarse en el
saldo que `admin/` muestra de esa misma tarjeta — es el mismo dinero, no
dos copias narrativamente parecidas.

La arquitectura de destino (backend Go real contra Postgres, ADR-0001 y
TDR-0001 de `backend/`) resuelve esto de raíz, pero implica un salto de
alcance grande: migraciones aplicadas, handlers reales para todo el
dominio, clientes generados desde OpenAPI para ambas apps. Y hoy ni
Docker ni Homebrew/Postgres están disponibles en el entorno de
desarrollo — construir esa versión completa está bloqueado, no solo
pendiente.

## Decisión
Un proceso Go compartido (`backend/cmd/api`), con **persistencia en
memoria** (sin Postgres todavía), sirve como fuente única de verdad para
lo mínimo que necesita reflejarse entre ambas apps:

1. **Alcance de datos migrados**: Tarjetas (`cards`) y Ledger
   (`ledger_accounts` + `ledger_entries`, es decir saldo y movimientos) y
   la identidad mínima de Tarjetahabiente necesaria para el login del
   portal y para resolver el destino de una transferencia C2C
   (`cardholders`, sin sus campos KYC — esos siguen sin ser necesarios
   fuera de `admin/`).
2. **Explícitamente fuera de este alcance** (siguen 100% en los
   repositorios fake de `admin/`, sin cambio): jerarquía de Clientes,
   expediente KYB, Tesorería (Concentradora/Colectora), `approval_rules`
   y el estado `pending_approval` de una operación, reclamos
   (`movement_claims`). Ninguno de estos necesita ser visible desde
   `cardholder/` todavía.
3. **El hash de PAN se calcula en el servidor**, no en el cliente Dart —
   corrige la implementación interina de
   `docs/feature/transferencia-c2c-tarjetahabiente/README.md` (que,
   a falta de backend, lo calculaba dentro de `FakeCardholderBackend`)
   para que coincida exactamente con lo que
   `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` siempre
   describió: el PAN completo viaja al backend, el backend calcula el
   HMAC y compara. Ver esa ADR, sección "Consecuencias", actualizada.
4. **Estructura de puertos y adaptadores ya decidida (ADR-0001), no una
   excepción a ella**: el nuevo adaptador vive en
   `internal/adapters/memory/`, junto a (nunca dentro de)
   `internal/adapters/postgres/` — implementa los mismos puertos
   (`internal/application/ports/`) que implementará el adaptador de
   Postgres el día que se construya. Cambiar de uno a otro es una
   decisión de wiring en `cmd/api/main.go`, no un rediseño. Ver
   `backend/docs/tdr/0003-in-memory-repository-adapter.md` para el
   detalle de implementación.
5. **Alcance de red**: el servidor escucha en `127.0.0.1` únicamente
   (nunca `0.0.0.0`) — no está pensado para exponerse fuera de la
   máquina de desarrollo. CORS restringido explícitamente a los dos
   orígenes de desarrollo de Flutter web (`http://127.0.0.1:8765` para
   `admin`, `http://127.0.0.1:8766` para `cardholder`) — nunca `*`,
   dado que el cuerpo de la petición de transferencia lleva el PAN
   completo (ver threat-model punto 15).
6. **Sin persistencia real**: los datos viven en mapas en memoria
   protegidos por mutex, sembrados al arrancar el proceso — se pierden al
   reiniciarlo. Mismo criterio y misma limitación ya aceptada para los
   repositorios fake de Dart, solo que ahora compartida entre procesos en
   vez de vivir dentro de cada app.
7. **Excepción documentada y temporal a ADR-0006**: esa ADR exige que los
   clientes Dart se generen desde `backend/api/openapi.yaml`, nunca a
   mano. Aquí se escriben a mano (`package:http`) en ambas apps —
   `HttpCardRepository`/`HttpLedgerRepository` en `admin/`,
   `HttpCardholderBackend` en `cardholder/` — por dos razones concretas,
   no por conveniencia:
   - El contrato de este backend interino va a cambiar de nuevo cuando
     se construya el backend real con Postgres — generar clientes ahora
     es trabajo que se descarta pronto.
   - El toolchain típico de `openapi-generator` (Java o el paquete de
     Node) no está disponible en este entorno de desarrollo hoy (sin
     Java funcional, sin Node/npx).
   `backend/api/openapi.yaml` sí se actualiza como documentación del
   contrato (la disciplina de "el spec es la fuente de verdad" se
   mantiene) — lo que se pospone es únicamente el paso de generación de
   código. Se retoma la generación de clientes cuando este backend
   interino se reemplace por el real.
8. **`KbmAdminApp`/`KbmCardholderApp` reciben un `KbmBackendClient?`
   opcional en vez de construir su implementación HTTP internamente**:
   cuando es `null` (los widget tests de ambas apps, que siguen llamando
   `KbmAdminApp()`/`KbmCardholderApp()` sin argumentos), las dos apps
   arman sus repositorios de Cards/Ledger/auth con las clases Fake de
   siempre. `main.dart` es el único lugar de cada app que pasa un
   `KbmBackendClient` real. Esto no es una preferencia de diseño — es
   obligatorio: `flutter test` corre sobre `TestWidgetsFlutterBinding`,
   que intercepta *todo* `HttpClient` y siempre responde 400 sin tocar la
   red (documentado por el propio framework). Un backend real es
   estructuralmente imposible de ejercer en ese entorno, así que los ~110
   widget tests existentes de ambas apps (que construyen la app completa
   con `pumpWidget`) habrían quedado rotos sin este seam.

## Consecuencias
- `admin/lib/features/cards/fake_card_repository.dart` y
  `fake_ledger_repository.dart` se reemplazan por implementaciones HTTP
  del mismo `CardRepository`/`LedgerRepository` — ningún otro archivo de
  `admin/` (`BalanceOperationRepository`, `CardDetailView`,
  `CardholderDetailView`, etc.) se entera del cambio, gracias a que ya
  dependían de la interfaz, no de la clase fake.
- Los métodos de `LedgerRepository` relacionados a reclamos
  (`fileClaim`/`resolveClaim`) se quedan respaldados por estado local en
  Dart dentro de la nueva implementación HTTP — es una mezcla deliberada
  (mismo criterio que `FakeCardholderBackend` ya usó: una sola clase
  puede cumplir una interfaz mezclando fuentes, mientras el contrato
  público no cambie), porque los reclamos no son parte del alcance de
  datos compartido (punto 2 arriba).
- `cardholder/lib/core/fake_backend.dart` se reemplaza por
  `HttpCardholderBackend` — el cálculo del HMAC sale de esa clase por
  completo, ahora vive solo en el backend.
- Reiniciar el proceso del backend (`go run ./cmd/api`) borra todo el
  estado sembrado — hay que tenerlo corriendo para que ambas apps
  funcionen, a diferencia de antes donde cada app era autosuficiente.
- `admin/` y `cardholder/` ahora tienen una dependencia de arranque nueva
  (el backend debe estar corriendo primero) — documentado en los
  `README.md` de ambas apps y del backend.
- `Store.Login` reinicia `failedAttempts` del Tarjetahabiente autenticado
  en cada login exitoso — el límite de 5 intentos de
  threat-model punto 12 es por sesión, no permanente; sin este reinicio,
  un Tarjetahabiente que agotara sus intentos quedaría bloqueado hasta
  reiniciar el proceso del backend, no solo hasta su siguiente login.

## Alternativas consideradas
- **Backend real con Postgres ahora**: la arquitectura correcta a largo
  plazo, pero bloqueada hoy (sin Docker ni Homebrew/Postgres en este
  entorno) y de un alcance considerablemente mayor — migraciones
  aplicadas, handlers para todo el dominio, clientes generados. Se
  revisita cuando exista esa infraestructura.
- **SQLite en vez de Postgres**: descartado — el esquema real
  (`backend/migrations/0001_init.sql`) ya usa tipos específicos de
  Postgres (`citext`, `gen_random_uuid()`), y la elección de sqlc+pgx
  (TDR-0001 de `backend/`) asume Postgres. Adaptar el esquema a SQLite
  sería trabajo descartable, no un atajo real.
- **Generar los clientes Dart desde OpenAPI ahora, cumpliendo ADR-0006
  desde el día uno**: se evaluó y se descartó para esta iteración — el
  toolchain no está disponible en este entorno, y el contrato de este
  backend interino no es el contrato final. Ver punto 7 arriba.
- **Mantener cada app con su propio universo fake** (el estado antes de
  esta ADR): es exactamente el problema que se está resolviendo —
  descartado.

## Ver también
- `docs/adr/0001-go-hexagonal-modular-monolith.md` — el adaptador nuevo
  vive dentro de esa misma estructura de puertos y adaptadores.
- `docs/adr/0002-flutter-web-mobile-two-apps.md` — por qué las dos apps
  no comparten código Dart (sí pueden, y ahora deben, compartir backend).
- `docs/adr/0006-openapi-contract.md` — la excepción temporal documentada
  en el punto 7.
- `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` — el cálculo del
  HMAC ahora vive donde esa ADR siempre dijo que debía vivir.
- `backend/docs/tdr/0003-in-memory-repository-adapter.md` — detalle de
  implementación del adaptador en memoria.
