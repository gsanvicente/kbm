# ADR-0018: El Tarjetahabiente puede presentar reclamos sobre su propio movimiento

- Estado: Aceptada — corregida por ADR-0028 (`GetEntryCardholderID` quedó
  apuntando a una columna eliminada tras ADR-0020, sin que nadie lo
  notara hasta entonces)
- Fecha: 2026-09-21

## Contexto
`docs/feature/portal-autoservicio-tarjetahabiente/README.md` dejaba
"presentar un reclamo" como el último punto pendiente del portal de
autoservicio (junto con el filtro de fechas/resumen de periodo en
Movimientos, resuelto en el mismo incremento pero sin decisiones de
arquitectura que ameriten su propio ADR). `docs/business/autoservicio-tarjetahabiente.md`
ya asumía, de forma especulativa y sin haberlo verificado contra el
schema real, que esto podría reusar `LedgerRepository.FileClaim` tal
cual — bastaría con mandar el email del Tarjetahabiente como
`requestedByEmail`.

Al implementarlo se encontró que esa suposición era incorrecta:
`movement_claims.requested_by` es una **FK obligatoria hacia `users`**
(la tabla de staff) — un Tarjetahabiente no tiene fila ahí (vive en
`cardholders`/`cardholder_users`, un plano de identidad completamente
separado, ver ADR-0010). No había ningún valor válido que un
Tarjetahabiente pudiera poner en esa columna sin mentir sobre quién hizo
el reclamo.

## Decisión
1. **`movement_claims.requested_by` pasa a ser opcional**, con una
   columna paralela `requested_by_cardholder_id` (FK a `cardholders`) y
   un `CHECK ((requested_by IS NOT NULL) <> (requested_by_cardholder_id IS NOT NULL))`
   — exactamente una de las dos, nunca ambas ni ninguna. Mismo criterio
   de "un plano de identidad u otro, nunca mezclados" que ya separa
   `users` de `cardholder_users` en todo el proyecto; se descartó un
   `actor_type`/`actor_id` genérico (como el que sí tiene `audit_log`,
   ver ADR-0015) porque aquí sí importa la integridad referencial real
   (una FK de verdad hacia una tabla u otra), no solo un registro de
   auditoría de solo-lectura.
2. **Las tres consultas de lectura** (`GetClaimByLedgerEntry`,
   `ListClaimsByLedgerEntries`, `GetClaimByID`) cambian su `JOIN users`
   por `LEFT JOIN` (staff) más un `LEFT JOIN cardholders` nuevo, y
   calculan `requested_by_email` como
   `COALESCE(rq.email::text, ch.full_name)` — el nombre de la columna
   Go/JSON se mantuvo (`RequestedByEmail`/`requestedByEmail`) para no
   tocar el resto del código ya existente: "Solicitado por" en `admin/`
   ya era una etiqueta genérica, nunca decía literalmente "email", así
   que mostrar el nombre completo de un Tarjetahabiente ahí no rompe
   nada ni confunde.
3. **Nuevo método `FileClaimAsCardholder`** (paralelo a `FileClaim`, no
   lo reemplaza) — el flujo de staff sigue exactamente igual que antes.
   Igual patrón para `GetEntryCardholderID` (nuevo), que resuelve a qué
   Tarjetahabiente pertenece la tarjeta detrás de un `ledger_entry_id`,
   para el chequeo de pertenencia.
4. **`getClaim`/`fileClaim` se movieron de las rutas solo-staff al grupo
   de alcance mixto** (junto a `listCards`/`getLedger`/`self-freeze`/
   transferencias) — un Tarjetahabiente pasa el chequeo de pertenencia
   (`entryOwnedByCaller`, mismo criterio "nunca revelar" que ya usa
   `getLedger`: 404 genérico si el movimiento no es suyo). El lado staff
   de `fileClaim` **perdió la restricción de rol** al salir del grupo
   `RequireRole(operateRoles)` (Auditor no puede presentar reclamos) —
   se restauró a mano dentro del handler (`staffRoleAllowed`, nuevo
   helper en `authz.go`) para no relajar esa regla de negocio existente.
5. **El Tarjetahabiente nunca resuelve su propio reclamo** — `resolveClaim`
   se quedó exactamente donde estaba (`manageRoles`, solo staff).

## Consecuencias
- Verificado en vivo contra Postgres real: Juan Perez presenta un
  reclamo sobre su propio movimiento (queda atribuido a "Juan Perez",
  no a un email); no puede presentar ni leer el de Ana Torres (404
  genérico en ambos casos, con datos reales de otro Tarjetahabiente de
  por medio, no una coincidencia de "no hay nada que ver"); Auditor
  sigue sin poder presentar un reclamo en nombre de alguien (403,
  restricción de rol preservada tras el movimiento de rutas).
- `cardholder/` gana su propio diálogo de detalle de movimiento +
  reclamo (sin código compartido con `admin/`, ADR-0002) — consulta el
  reclamo de un movimiento perezosamente, solo al abrir su detalle,
  nunca de una sola vez para toda la lista, evitando desde el diseño el
  mismo patrón N+1 que se tuvo que corregir del lado de `admin/` (ver
  `docs/feature/reclamos-de-movimientos/README.md`, "N+1 en reclamos").
- `go build/vet/test` (4 tests nuevos) y `flutter analyze`/`flutter test`
  de `cardholder/` (20 tests, 3 nuevos entre esto y el filtro de
  periodo) en verde.
- `docs/business/autoservicio-tarjetahabiente.md` tenía una suposición
  de diseño incorrecta sobre este mecanismo (reusar `FileClaim` tal
  cual) — corregida para reflejar lo que realmente se construyó.

## Alternativas consideradas
- **`actor_type`/`actor_id` genérico** (como `audit_log`): descartado —
  `movement_claims` necesita integridad referencial real (una FK
  verificable hacia la tabla correcta), no solo un registro de quién
  hizo qué; el patrón de `audit_log` es apropiado para un log de
  solo-lectura, no para una entidad de negocio con su propio ciclo de
  vida.
- **Crear una fila sintética en `users` para representar "el propio
  Tarjetahabiente"**: descartado de inmediato — mezclaría los dos planos
  de identidad que el proyecto mantiene deliberadamente separados desde
  el principio (ADR-0010), y rompería cualquier query futura que asuma
  que toda fila de `users` es staff real.

## Ver también
- `docs/business/reclamos-de-movimientos.md`
- `docs/business/autoservicio-tarjetahabiente.md`
- `docs/feature/reclamos-de-movimientos/README.md`
- `docs/feature/portal-autoservicio-tarjetahabiente/README.md`
- `backend/migrations/0007_cardholder_filed_claims.sql`
- `docs/adr/0028-reorganizacion-ux-cardholder.md` — corrige
  `GetEntryCardholderID` para ir por `individual_accounts`, no por
  `cards` (columna eliminada en `migrations/0009_cuenta_individual.sql`,
  ADR-0020).
