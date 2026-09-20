# ADR-0011: Postgres pasa a ser el default; arquitectura para la integración con el procesador de tarjetas

- Estado: Aceptada
- Fecha: 2026-09-20

## Contexto
`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` resolvió
un problema táctico (que `admin/` y `cardholder/` vieran el mismo dato)
con un backend interino en memoria, explícitamente temporal. KBM ya
existía desde antes como monolito hexagonal (`docs/adr/0001-go-hexagonal-modular-monolith.md`)
con Postgres como backend real (`docs/tdr/0001-sqlc-pgx-over-orm.md`,
`backend/migrations/0001_init.sql`) y con carpetas ya reservadas para un
`CardProcessorGateway` (`internal/adapters/processor/`) — nunca se había
construido nada de eso todavía.

El requerimiento de negocio real de KBM, hasta ahora no capturado en
ningún ADR, es: **KBM gestiona saldos, pero no autoriza movimientos** —
la autorización siempre viene de un procesador de tarjetas externo. Dos
flujos, con dirección opuesta:

1. **Dispersión/Deducción (KBM → procesador)**: el staff solicita mover
   saldo entre la Concentradora de un Cliente y una tarjeta. KBM le pide
   al procesador que ejecute el movimiento real; solo cuando el
   procesador confirma, KBM refleja el movimiento en su propio ledger.
2. **Compra con tarjeta (procesador → KBM)**: un Tarjetahabiente usa su
   tarjeta en un comercio. La autorización ocurre enteramente del lado
   del procesador — KBM nunca la ve en tiempo real. Después de
   autorizar, el procesador le notifica a KBM para que refleje el
   movimiento en el saldo de esa tarjeta.

Esto significa que, para "Compra", **KBM nunca es la fuente de verdad de
si un movimiento se autoriza o no** — solo lo registra después de que ya
ocurrió. Es una asimetría real con "Dispersión/Deducción", donde KBM sí
inicia el movimiento.

## Decisión

1. **Postgres pasa a ser el backend por defecto** para Cards/Ledger — ya
   no el adaptador en memoria de ADR-0010. El modo "demo" (en memoria)
   se conserva como opción explícita vía variable de entorno, para poder
   seguir probando UI sin depender de una base de datos corriendo. La
   interfaz de los puertos no cambia — es una decisión de wiring en
   `cmd/api/main.go`, tal como ADR-0010 ya anticipaba.
2. **Postgres local se conteneriza con Podman** (ver actualización a
   `docs/adr/0004-aws-fargate-terraform-local-no-containers.md`) —
   mismo `docker-compose.yml`, motor más ligero. El volumen nombrado ya
   existente (`kbm_postgres_data`) sobrevive a `podman compose down` sin
   `-v` — es la persistencia que se pedía.
3. **Toda comunicación con el procesador pasa por el puerto
   `CardProcessorGateway`** (`internal/application/ports`), nunca un SDK
   de un procesador específico embebido directamente en un caso de uso —
   es la aplicación literal de la arquitectura hexagonal ya decidida en
   ADR-0001 a este problema concreto.
4. **La llamada saliente (Dispersión/Deducción) es asíncrona, con
   reintentos** — usa el patrón outbox/queue/worker ya escaffoldeado
   (`outbox_events`, `internal/adapters/outbox`, `internal/adapters/queue/{local,sqs}`,
   `cmd/worker`), no una llamada síncrona dentro de la petición HTTP de
   aprobación. `operation_status` ya distingue `approved` de `executed`
   — `approved` pasa a significar "aprobado, despachado al procesador";
   `executed` significa "el procesador confirmó, el ledger ya se
   actualizó". Elegido así aunque no sepamos todavía qué tan rápido
   responde el procesador real, porque la resiliencia (reintentos, no
   bloquear la petición HTTP) no depende de eso.
5. **La llamada entrante (Compra) es un adaptador nuevo, sin precedente
   en el scaffold actual** — nunca existió nada para "alguien externo
   nos llama a nosotros". Requiere:
   - Un endpoint HTTP dedicado, autenticado según el mecanismo del
     procesador (firma, mTLS, API key — el adaptador concreto lo
     resuelve, el puerto lo normaliza).
   - **Idempotencia por ID de transacción del procesador** — columna
     nueva con restricción de unicidad; sin esto, un reintento de red
     del procesador duplicaría el movimiento. No existe hoy en el
     schema.
   - Una tabla nueva para el registro crudo de la autorización
     (`operation_type` no tiene `'purchase'`, y `balance_operations` es
     el lugar equivocado — esa tabla es para operaciones que **nosotros**
     iniciamos y pueden requerir aprobación; una compra ya fue
     autorizada por el procesador, nunca pasa por `approval_rules`,
     mismo criterio que ya aplica a la transferencia C2C del
     Tarjetahabiente).
6. **Sin procesador real elegido todavía**: se construye un adaptador
   simulador (`internal/adapters/processor`, implementación "fake") que
   cumple el mismo puerto `CardProcessorGateway`, más una forma de
   simular al procesador llamándonos (para probar el flujo de Compra sin
   depender de nadie externo). Mismo criterio que ya se usó para
   construir `admin/`/`cardholder/` contra fakes antes de tener un
   backend real — el puerto queda listo para "montar" el procesador real
   después, sin rediseño.

## Consecuencias
- **Implementado (2026-09-20)**: `cmd/api/main.go` elige el adaptador de
  Cards/Ledger vía `STORAGE_BACKEND` (`internal/platform/config`),
  independiente de `APP_ENV` — default `postgres`, opt-in explícito
  `memory`. Ver `docs/tdr/0004-postgres-repository-adapter.md` para el
  detalle de implementación (sqlc, mapper, concurrencia, columnas de
  schema que hicieron falta y no existían: `cards.pan_hash`,
  `cards.blocked_reason`).
- El adaptador Postgres real (`internal/adapters/postgres/repository` +
  `mapper`) implementa los mismos puertos que ya implementa el adaptador
  en memoria — `admin/` y `cardholder/` no se enteraron del cambio,
  verificado en vivo contra la API real.
- Row-Level Security sigue habilitada en las tablas relevantes
  (`migrations/0001_init.sql`) pero **sin políticas todavía** — la app
  se conecta como dueño de las tablas (por default no sujeto a RLS), así
  que hoy el aislamiento sigue siendo el mismo que ya existía (filtrado
  en la capa de aplicación), simplemente no reforzado también en la base
  de datos. Sigue siendo trabajo futuro explícito, no un olvido.
- El trabajo de integración real del procesador (adaptador concreto,
  contrato exacto, autenticación) queda bloqueado hasta que se elija un
  procesador — mientras tanto, todo se construye y prueba contra el
  simulador.

## Alternativas consideradas
- **Mantener el backend en memoria como default**: descartado — ya
  cumplió su propósito táctico (ADR-0010), y KBM necesita persistencia
  real para dejar de ser una demo, que es justamente el objetivo de esta
  ADR.
- **Llamar al procesador de forma síncrona dentro de la petición HTTP**:
  descartado por ahora — más simple de implementar, pero no aprovecha
  el outbox/queue/worker ya pensado, y ata la resiliencia del sistema a
  qué tan rápido/confiable sea un procesador que ni siquiera se ha
  elegido todavía.
- **Esperar a tener un procesador elegido para empezar**: descartado —
  bloquearía todo el trabajo de arquitectura (puerto, outbox, idempotencia,
  Postgres) sin necesidad; el simulador permite avanzar en paralelo.

## Ver también
- `docs/adr/0001-go-hexagonal-modular-monolith.md` — el puerto
  `CardProcessorGateway` es la aplicación de esa decisión a este
  problema.
- `docs/adr/0004-aws-fargate-terraform-local-no-containers.md` — cambio
  de Docker a Podman para el Postgres local.
- `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` — el
  backend que este ADR reemplaza como default (sigue existiendo como
  modo demo).
- `backend/docs/tdr/0001-sqlc-pgx-over-orm.md` — decisión de fondo
  (sqlc+pgx sobre un ORM) que el adaptador Postgres real aplica.
- `backend/docs/tdr/0004-postgres-repository-adapter.md` — cómo se
  implementó el adaptador Postgres real.
