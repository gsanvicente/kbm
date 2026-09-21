# ADR-0012: Migración completa a Postgres — Clientes, Tesorería, login administrativo, Aprobaciones, Cardholders (KYC) y Reclamos

- Estado: Aceptada
- Fecha: 2026-09-20

## Contexto
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
movió Cards/Ledger/login de Tarjetahabiente/transferencias C2C a
Postgres, dejando explícitamente fuera de alcance "Clientes,
Tarjetahabientes (KYC), Aprobaciones, Tesorería y Reclamos... siguen
100% en los fakes de Dart de `admin/`". Al usar ese incremento, se
encontró un problema real: crear una empresa nueva vivía solo en la
memoria del proceso de `admin/` — un reinicio del `flutter run` (algo
que pasa constantemente en desarrollo) la borraba, dando la impresión de
que "la base de datos no era persistente" cuando en realidad Clientes
nunca había tocado Postgres. Se pidió cerrar esa brecha por completo:
**nada queda fuera de Postgres**.

Al diseñar esto se encontró una dependencia real no anticipada:
Tesorería/Aprobaciones/Reclamos tienen llaves foráneas
(`registered_by`, `requested_by`, etc.) hacia `users` — el login
administrativo también tenía que migrar, aunque no se había pedido
explícitamente, porque si no esas tablas no podían poblarse con datos
reales.

## Decisión
1. **Login administrativo (`admin/`) pasa a Postgres.** La tabla `users`
   ya existía y ya estaba sembrada con bcrypt (mismo formato que
   `cardholder_users`) — nunca se había conectado. Mismo criterio de
   mensaje genérico que el login de Tarjetahabiente (nunca se distingue
   credenciales incorrectas de usuario inactivo).
2. **Clientes (KYB) pasa a Postgres.** El schema original de `clients`
   solo tenía id/nombre/padre/activo — se añadieron las columnas del
   expediente KYB (razón social, RFC, acta constitutiva...) y dos tablas
   nuevas, `client_apoderados` y `client_beneficiarios` (uno a muchos,
   reemplazando las listas `apoderados`/`beneficiariosControladores` de
   `admin/lib/core/models/client.dart`). `client_hierarchy` (cierre
   transitivo) se mantiene en Go al crear un Cliente, dentro de la misma
   transacción — ver `migrations/0003_client_kyb.sql`.
3. **Tesorería (Concentradora/Colectora) pasa a Postgres** usando las
   tablas que ya existían sin uso (`concentrator_accounts`,
   `concentrator_entries`, `collector_deposits`). Crear un Cliente crea
   su Cuenta Concentradora en cero automáticamente, en la misma
   transacción — nunca puede existir un Cliente sin la suya. El
   endpoint que la crea es get-or-create (`ON CONFLICT`), así que
   llamarlo de más nunca falla ni duplica.
4. **Cardholders (KYC completo que `admin/` gestiona) pasa a Postgres.**
   Distinto del login del portal de autoservicio (`cardholder_users`,
   ya migrado en ADR-0010) — la tabla `cardholders` ya tenía todos los
   campos necesarios, no hizo falta ninguna migración de schema aquí.
5. **Aprobaciones (`balance_operations`/`approval_rules`) pasa a
   Postgres**, reutilizando `internal/adapters/postgres/repository`'s
   `LedgerRepository`/`TreasuryRepository` ya existentes para ejecutar
   Dispersión/Deducción/Transferencia — mismo criterio "nunca a medias"
   que ya regía en memoria. El volumen semanal del Panel directivo
   (`GetWeeklyTrend`) deja de ser un dato sintético (ver
   `docs/feature/panel-directivo/README.md`, "Visión futura") y pasa a
   ser un agregado real de `balance_operations` ejecutadas.
6. **Reclamos (`movement_claims`) pasa a Postgres.**
7. **Sigue sin existir un `AuthorizationPort` real** (ver
   `internal/application/ports/doc.go`, todavía "planned"). `GET
   /v1/clients` devuelve todas las empresas sin filtrar; `admin/`'s
   `HttpClientRepository.listAccessibleClients` sigue filtrando
   client-side por rol/Cliente exactamente igual que ya hacía
   `FakeClientRepository` — no se inventó infraestructura de
   autorización nueva para este incremento.

## Consecuencias
- Todo lo que `admin/` gestiona ahora persiste de verdad en Postgres —
  el volumen sembrado (`kbm_postgres_data`) sobrevive un `podman compose
  down`/reinicio del backend/reinicio de `flutter run`, verificado en
  vivo para cada dominio (Clientes con expediente KYB completo,
  Tesorería, Aprobaciones, Cardholders, Reclamos).
- `admin/`'s fakes (`Fake*Repository`) no se eliminaron — siguen siendo
  lo que corre en `flutter test` (que no puede hablar con un backend
  real, ver `KbmAdminApp.backendClient`) y documentan el comportamiento
  esperado igual que antes.
- El schema ganó dos tablas nuevas (`client_apoderados`,
  `client_beneficiarios`) y columnas KYB en `clients` — RLS habilitada
  en las nuevas tablas, sin políticas todavía (mismo gap ya documentado
  en ADR-0011, no resuelto aquí).
- `cardholder.Cardholder` (Go) creció de un struct mínimo (login/C2C) al
  expediente KYC completo — un solo tipo real en vez de dos conceptos
  separados, mismo criterio que ya se usó para Client/ApoderadoLegal.
- El límite de tarjetas activas por Tarjetahabiente
  (`maxActiveCardsPerCardholder`) deja de ser un mapa hardcodeado en
  Dart y Go — ahora lee `client_settings` de Postgres en ambos lados,
  cerrando el pedido original de que fuera "configuración dinámica por
  Cliente" de verdad.
- `internal/adapters/memory/` (modo demo) no implementa ninguno de estos
  ports nuevos (`ClientRepository`, `TreasuryRepository`,
  `StaffAuthRepository`, `BalanceOperationRepository`,
  `CardholderManagementRepository`) — quedan fuera de su alcance
  original (ver ADR-0010) y así se mantiene; `cmd/api/main.go` solo los
  inyecta en la rama Postgres, `handler.Routes()` solo registra esas
  rutas cuando el campo correspondiente no es nil.

## Alternativas consideradas
- **Mantener Clientes/Tesorería/etc. en Dart y solo advertir sobre la
  no-persistencia**: descartado — el pedido explícito fue "nada debe
  quedar fuera de Postgres".
- **Relajar el schema de Tesorería/Aprobaciones/Reclamos (columna de
  texto en vez de FK a `users`) para evitar migrar el login
  administrativo**: descartado — hubiera sido una desviación real del
  diseño original solo para ahorrarse un incremento pequeño (la tabla
  `users` ya existía sembrada).
- **Construir un `AuthorizationPort` real en este mismo incremento**:
  descartado por alcance — no fue parte de lo pedido, y el filtrado
  client-side ya existente sigue siendo funcionalmente equivalente a lo
  que había antes.

## Actualización 2026-09-21: auditoría de integración completa y cuatro huecos cerrados
Después de este incremento se hizo una auditoría explícita de "¿falta
algo para que todo transaccione de verdad contra Postgres?" — resultado:
la integración estaba completa (todo `Fake*Repository` con su
`Http*Repository` gemelo, ambos `main.dart` conectan un backend real por
default), pero se identificaron cuatro huecos, los cuatro resueltos en
esta misma fecha:

1. **El aviso de "dato ilustrativo"** en el volumen semanal del Panel
   directivo se mostraba siempre, aunque contra Postgres ya fuera un
   agregado real. Resuelto con `BalanceOperationRepository.producesSyntheticWeeklyTrend`
   (cada implementación lo declara: `true` en la fake, `false` en la
   HTTP) — ver `docs/feature/panel-directivo/README.md`.
2. **N+1 en reclamos** del Panel directivo (una llamada HTTP por
   movimiento). Resuelto con `GET /v1/claims?ledger_entry_ids=...` — ver
   `docs/feature/reclamos-de-movimientos/README.md`.
3. **`approval_rules` y `client_settings` de solo lectura** — nunca
   tuvieron pantalla para editarlos, solo el seed los escribía. Resuelto
   con una pestaña nueva "Configuración" en el detalle de un Cliente —
   ver `docs/feature/configuracion-de-cliente/README.md`. Requirió una
   restricción `UNIQUE (client_id, operation_type)` nueva en
   `approval_rules` (`migrations/0004_approval_rules_unique_constraint.sql`)
   para que el upsert fuera válido.
4. **RLS sin políticas** — analizado en profundidad: escribir políticas
   atadas a `current_setting('app.accessible_client_ids')` alimentado
   por parámetros que el propio llamador manda en cada request (sin
   ninguna sesión/token verificable, en ese momento
   `internal/adapters/auth/{local,cognito}` seguían siendo solo
   `doc.go`) no sería una política real — cualquiera podría declarar el
   `client_id` que quisiera. Se preguntó explícitamente cómo proceder y
   se eligió construir primero la sesión real — ver
   `docs/adr/0013-jwt-session-authentication.md` (Fase 1, ya resuelta:
   JWT emitido en login, verificado en cada request). Las políticas de
   RLS en sí (Fase 2) siguen pendientes — ver "Consecuencias" de
   ADR-0013.

## Ver también
- `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`
- `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
- `backend/docs/tdr/0004-postgres-repository-adapter.md`
- `backend/migrations/0003_client_kyb.sql`
- `docs/feature/configuracion-de-cliente/README.md`
