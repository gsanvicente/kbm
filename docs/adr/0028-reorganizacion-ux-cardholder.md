# ADR-0028: Reorganización UX del portal de Tarjetahabientes — Inicio/Movimientos/Beneficiarios, y corrección de alcance de reclamos sin tarjeta

- Estado: Aceptada
- Fecha: 2026-09-25

## Contexto
Retroalimentación directa del negocio sobre `cardholder/`, resumida:

1. El orden de pestañas ("Movimientos" antes que "Cuenta") ya reflejaba
   la prioridad correcta, pero eso no era el problema real: la pestaña
   "Cuenta" mezclaba CLABE, Beneficiarios, saldo, depósitos recibidos e
   historial de pagos en una sola lista — con muchos "Depósitos
   recibidos" sembrados, la opción de mandar un SPEI podía quedar fuera
   de la vista sin hacer scroll.
2. Transferencia C2C y pago SPEI **afectan el mismo saldo** (la Cuenta
   Individual, ver ADR-0020) pero vivían en pantallas distintas —
   "Transferir" en Inicio, "Enviar SPEI" en Cuenta — sin ninguna razón de
   negocio para esa separación, solo histórica (SPEI se agregó después,
   ADR-0021, y se anexó donde ya vivían los Beneficiarios).
3. Los Beneficiarios deberían aparecer principalmente **al momento de
   enviar dinero**, no como una lista permanente que compite por espacio
   con el saldo — gestionarlos con calma es un caso de uso aparte, más
   parecido a una libreta de direcciones que a una vista de cuenta.
4. Pedido explícito: "debe ser como el de una plataforma bancaria" — se
   evaluaron tres niveles de intervención (rediseño total de una sola
   pantalla, consolidación quirúrgica de las pantallas existentes, o un
   parche táctico de reordenar); el negocio eligió la consolidación
   quirúrgica.

Al implementar la reorganización para Tarjetahabientes **sin ninguna
tarjeta asignada todavía** (`HomeShell._AccountOnlyShell`, que hasta hoy
delegaba todo al antiguo `SpeiSection`), surgió una pregunta que no tenía
respuesta clara en el código: ¿puede alguien sin tarjeta presentar un
reclamo sobre un depósito/pago SPEI de su propia Cuenta? Investigar esto
encontró un bug real, independiente de este rediseño pero que lo bloqueaba
— ver punto 5 de la Decisión.

## Decisión

### 1. Tres secciones, no tres vistas fragmentadas de lo mismo
`CardholderShell` (con tarjeta) y `HomeShell._AccountOnlyShell` (sin
tarjeta) comparten ahora la misma organización:

- **Inicio** — saldo + las dos formas de sacar dinero de la misma Cuenta
  ("A una tarjeta KBM" / Transferencia C2C, y "A una cuenta (SPEI)"),
  lado a lado bajo un solo encabezado "ENVIAR DINERO" (`HomeTab`). Sin
  tarjeta asignada, solo aparece la opción SPEI — la C2C exige tarjeta en
  ambos extremos (`TransferDialog`: siempre tarjeta a tarjeta, nunca toca
  una Cuenta Concentradora), así que es la única de las dos que puede
  existir desde el día del alta del Tarjetahabiente.
- **Movimientos** — historial completo y único de la Cuenta (Dispersión,
  Deducción, Transferencia C2C, SPEI entrante/saliente — todo lo que
  afecta el mismo saldo, ver ADR-0020), con el filtro de periodo, el
  resumen de totales, "Descargar estado de cuenta" (movido aquí desde la
  antigua pestaña "Cuenta") y el detalle de reclamos, todo en un solo
  lugar. `MovementsTab` se desacopla de requerir una tarjeta vía un
  callback `loadMovements` — `CardholderShell` lo llama con
  `cardRepository.listMovements(card.id)`, `_AccountOnlyShell` con
  `speiRepository.getAccountLedger(cardholderId).movements` — mismo dato
  real, dos formas válidas de pedirlo.
- **Beneficiarios** (antes "Cuenta") — CLABE propia y el directorio de a
  quién se le puede pagar por SPEI, sin el saldo ni el historial
  compitiendo por espacio. Es gestión de contactos de pago, no una
  segunda vista de la Cuenta.

### 2. Comprobante SPEI dentro del detalle de un movimiento
`LedgerMovement` no trae folio, CLABE de beneficiario ni referencia del
proveedor — esos datos viven en `SpeiPayment`/`SpeiDeposit`. En vez de
agregar esos campos al ledger genérico (cambio de esquema fuera de
alcance de este ADR), `MovementsTab` resuelve la coincidencia por
heurística: mismo monto exacto y el timestamp más cercano dentro de una
ventana de 5 minutos, contra `listPayments`/`listDeposits` del propio
Tarjetahabiente (pedidos una sola vez, perezosamente, la primera vez que
se abre un movimiento que luce como SPEI por su descripción).

**Limitación conocida**: esto es una heurística, no una relación real por
folio. Un movimiento genuino de SPEI siempre tiene coincidencia exacta de
monto y prácticamente el mismo instante (se crean en la misma
transacción), así que el margen de error práctico es mínimo, pero no es
imposible en teoría que dos pagos por el mismo monto en la misma ventana
de tiempo se confundan. Si esto importa lo suficiente, la solución
correcta es un campo de referencia explícito en `ledger_entries` (o un
`source_id`/`source_type`) — evaluado y pospuesto por alcance.

### 3. Agregar un Beneficiario nuevo sin salir de "Enviar dinero"
`SendSpeiDialog` gana un enlace "Agregar nuevo beneficiario" dentro del
propio formulario de envío, que abre `AddBeneficiaryDialog` sin cerrar el
diálogo de envío — el beneficiario recién creado se agrega a la lista
local ya cargada y se autoselecciona. Esto era necesario para que "los
beneficiarios se muestran hasta que se quiere hacer un SPEI" (punto 3 del
pedido original) no se sintiera como un callejón sin salida la primera
vez que alguien no tiene ningún beneficiario todavía: la pestaña
"Beneficiarios" sigue existiendo para administrarlos con calma, pero ya
no es el único lugar donde se puede dar de alta uno.

### 4. `HomeShell._AccountOnlyShell` deja de ser un caso especial pobre
Antes delegaba todo a `SpeiSection` (CLABE + Beneficiarios + saldo +
depósitos + pagos, todo junto, sin pestañas). Ahora tiene la misma
organización Inicio/Movimientos/Beneficiarios que un Tarjetahabiente con
tarjeta, con `NavigationBar` propio (no hay sidebar/tarjeta que mostrar) —
la única asimetría real es que "Inicio" aquí es saldo + un solo botón
SPEI, sin tarjeta visual ni Transferencia C2C.

### 5. Corrección: el chequeo de pertenencia de un reclamo seguía
   asumiendo que todo movimiento cuelga de una tarjeta
Al diseñar la pestaña Movimientos para un Tarjetahabiente sin tarjeta, se
encontró que `GetLedgerEntryCardholderID`
(`backend/internal/adapters/postgres/sqlc/queries/claims.sql`) —
el chequeo de "¿este movimiento es realmente tuyo?" que usa
`entryOwnedByCaller` para `getClaim`/`fileClaim` — todavía hacía
`JOIN cards c ON c.id = la.card_id`. Esa columna
(`ledger_accounts.card_id`) **se eliminó** en
`migrations/0009_cuenta_individual.sql` al mover el saldo de la tarjeta a
la Cuenta Individual (ADR-0020): la consulta quedó referenciando una
columna que ya no existe en el esquema real, y habría fallado (error SQL)
contra Postgres real para **cualquier** movimiento, no solo los de un
Tarjetahabiente sin tarjeta — nadie lo notó porque el doble en memoria
usado por las pruebas Go (`internal/adapters/memory/repository/store.go`)
nunca migró de ese mismo modelo pre-ADR-0020 (sigue indexando
`s.entries`/`s.accounts` por `cardID`), así que las pruebas existentes no
podían detectarlo.

Se corrigió la consulta para ir por el esquema actual:
`ledger_entries → ledger_accounts → individual_accounts.cardholder_id`,
sin pasar por `cards` en absoluto. Esto de paso es lo que hace correcto
reclamar un movimiento SPEI de un Tarjetahabiente sin ninguna tarjeta
asignada — antes ni siquiera habría sido posible verificar la
pertenencia. Verificado en vivo contra el backend local real (Postgres):
`getClaim`/`fileClaim` ahora funcionan para el propio Tarjetahabiente, y
el aislamiento entre Tarjetahabientes de otra Cuenta se sigue respetando
(otro Tarjetahabiente pidiendo el mismo `ledgerEntryId` sigue recibiendo
`404`).

Con esta corrección, `_AccountOnlyShell` reutiliza el mismo
`cardRepository` real (no un stand-in) para `getClaim`/`fileClaim` en su
pestaña Movimientos — sus otros métodos (`listMine`, `listMovements`,
`setFrozen`) simplemente nunca se llaman desde ahí.

## Consecuencias
- `movements_tab.dart`, `home_tab.dart`, `cardholder_shell.dart` y
  `home_shell.dart` se reescribieron; `spei_section.dart` y
  `receipt_dialog.dart` se eliminaron (sin más referencias tras el
  rediseño).
- La pestaña se renombra de "Cuenta" a "Beneficiarios" en toda la UI y en
  `docs/business/autoservicio-tarjetahabiente.md` /
  `docs/feature/portal-autoservicio-tarjetahabiente/README.md`.
- El doble en memoria del backend Go (`internal/adapters/memory/repository/store.go`)
  sigue modelando el ledger como si colgara de la tarjeta, no de la
  Cuenta Individual — funciona porque sus propias pruebas nunca ejercitan
  el camino de "sin tarjeta", pero es deuda pendiente real desde
  ADR-0020, no solo de este ADR. Evaluar si migrarlo antes de que algún
  flujo nuevo dependa de probarse contra ese doble en vez de Postgres
  real.
- La heurística de comprobante SPEI en Movimientos (punto 2) queda
  documentada como limitación conocida, no como bug pendiente.

## Alternativas consideradas
- **Opción A — Unificación total en una sola pantalla de Cuenta** (saldo,
  ambas formas de enviar dinero, Beneficiarios y Movimientos todo en una
  vista con secciones colapsables): más cercana a algunos apps bancarios
  reales, pero cambiaba la navegación de fondo (adiós a pestañas) sin que
  el negocio lo hubiera pedido explícitamente — mayor riesgo/alcance por
  el mismo beneficio.
- **Opción C — Parche táctico** (solo reordenar "Cuenta" internamente,
  mover el botón SPEI arriba del todo): resolvía el síntoma inmediato
  (perder el botón entre depósitos) pero dejaba intacta la causa real —
  Beneficiarios, saldo e historial seguirían compitiendo por la misma
  pantalla, y Transferencia/SPEI seguirían separados sin motivo.
- El negocio eligió explícitamente la Opción B (esta), como consolidación
  suficiente sin el riesgo de un rediseño de navegación completo.

## Ver también
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — por qué
  Transferencia C2C y SPEI afectan el mismo saldo.
- `docs/adr/0021-conector-spei.md` — flujo de Beneficiarios y pagos SPEI.
- `docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md`,
  `docs/adr/0027-validacion-de-saldo-y-estatus-de-pago-spei.md` — mismo
  criterio de "insertar localmente el resultado del propio POST" que
  ahora también usa "Agregar beneficiario" desde `SendSpeiDialog`.
- `docs/business/reclamos-de-movimientos.md` — a quién le pertenece un
  reclamo; corregido para reflejar que ya no pasa por `cards`.
