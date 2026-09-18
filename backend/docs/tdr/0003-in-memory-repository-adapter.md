# TDR-0003: Adaptador de persistencia en memoria (`internal/adapters/memory/`)

- Estado: Aceptada
- Fecha: 2026-09-19
- Alcance: decisión local al backend

## Contexto
`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` (raíz)
decide que `admin/` y `cardholder/` deben compartir un backend real para
Tarjetas y Ledger, pero sin Postgres disponible en este entorno todavía.
Este TDR es la implementación local de esa decisión: cómo se estructura
el adaptador en memoria para que no sea un callejón sin salida cuando
llegue Postgres.

## Decisión
`internal/adapters/memory/` implementa exactamente los mismos puertos de
`internal/application/ports/` (`CardRepository`, `LedgerRepository`,
`CardholderRepository` — el subconjunto que `docs/adr/0010-...` puso en
alcance) que implementará `internal/adapters/postgres/` el día que
exista. Nada en `internal/application` ni en `internal/adapters/http`
sabe cuál de los dos adaptadores está en uso — se decide una sola vez en
`cmd/api/main.go`.

Estructura interna del adaptador:
- Un `struct` por agregado (`cardStore`, `ledgerStore`,
  `cardholderStore`), cada uno con su propio `sync.RWMutex` — mismo
  criterio de aislamiento que tendrían transacciones separadas por tabla
  en Postgres, para no acostumbrar el código a un lock global que
  Postgres no necesitaría.
- Los datos sembrados al arrancar el proceso usan los mismos IDs que ya
  usan `admin/lib/features/.../fake_*_repository.dart` y
  `cardholder/lib/core/fake_backend.dart` — puramente por continuidad
  narrativa del demo (ver ADR-0010), no hay ninguna relación técnica real
  entre esos IDs y estos.
- El HMAC de PAN (ver ADR-0009) se calcula aquí, con
  `crypto/hmac` + `crypto/sha256` de la librería estándar de Go — la
  llave sigue siendo una constante marcada como solo-desarrollo, igual
  que ya lo era en el `FakeCardholderBackend` de Dart que este adaptador
  reemplaza. Cuando exista un almacén de secretos real, esto se mueve a
  `internal/platform/config`.

## Consecuencias
- El día que se implemente `internal/adapters/postgres/` para estos
  mismos puertos, el cambio en `cmd/api/main.go` es una línea (qué
  adaptador se inyecta), no un rediseño de `internal/application` ni de
  `internal/adapters/http`.
- Los datos no sobreviven un reinicio del proceso — aceptado
  explícitamente, ver ADR-0010.
- Los métodos de `LedgerRepository` fuera del alcance de ADR-0010
  (reclamos) no se implementan aquí — ese puerto se reduce a lo que
  `admin/`'s nuevo `HttpLedgerRepository` realmente necesita del backend;
  los reclamos se resuelven completamente del lado de Dart, como ya
  documentó esa ADR.

## Alternativas consideradas
- **Un mapa global sin separar por agregado**: descartado — dificulta el
  swap a Postgres después (donde cada tabla es su propio recurso) y
  esconde qué datos realmente dependen de cuáles.
- **Persistir a un archivo JSON local entre reinicios**: se evaluó como
  forma barata de no perder datos al reiniciar el proceso durante
  desarrollo, pero se descartó — añade una capa de serialización
  descartable (nunca sería el formato real de Postgres) solo para ahorrar
  volver a sembrar datos, que ya es instantáneo.
