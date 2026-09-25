# Tesorería del Cliente: Cuenta Concentradora y Cuenta Colectora

> Referencia viva. Última revisión: 2026-09-24.

## Por qué existen estos dos conceptos

Hasta ahora, una Dispersión sobre una tarjeta simplemente "aparecía" —
creaba saldo en el `ledger_account` de esa tarjeta sin ninguna fuente. Eso
no sostiene un negocio real: el dinero que se dispersa a las tarjetas de
un Cliente tiene que salir de algún lado, y ese "algún lado" es lo que
modelan estos dos conceptos, tomados de cómo opera la banca/tesorería
corporativa real en México:

- **Cuenta Concentradora**: el pool de dinero real de un Cliente — de ahí
  sale el dinero de cada Dispersión, y ahí regresa el de cada Deducción.
  Es la cuenta operativa con cargos y abonos.
- **Cuenta Colectora**: el punto de entrada cuando el Cliente deposita
  dinero externo (vía transferencia bancaria en la vida real) para
  fondear a sus tarjetahabientes. No es la misma cuenta que la
  Concentradora — es un paso de **conciliación** antes de que ese dinero
  quede disponible para dispersarse.

## Alcance: una Concentradora y una Colectora por Cliente

Cada Cliente (incluidas las subsidiarias, no solo la empresa raíz de una
jerarquía) tiene su propia Cuenta Concentradora y su propia Cuenta
Colectora, independientes entre sí. No hay consolidación automática entre
una empresa padre y sus hijas — mismo criterio que ya aplica al pool de
tarjetas (`docs/business/tarjetas-y-asignacion.md`): cada Cliente opera su
propio dinero, la jerarquía solo determina *quién tiene acceso para
operarlo* (ver "Herencia sobre la jerarquía padre/hija" en
`docs/business/roles-and-permissions.md`), no que los fondos se compartan
entre empresas.

## El flujo de fondeo: dos pasos, no uno

1. **Registrar el depósito** — un Operador (o Admin Cliente/Super Admin)
   registra que llegó dinero externo: monto, referencia/folio bancario, y
   queda en la Colectora en estado `pending`. Esto **no** hace el dinero
   disponible todavía.
2. **Conciliar** — un Admin Cliente o Super Admin confirma que ese
   depósito es legítimo y lo mueve a la Concentradora: el depósito pasa a
   `reconciled` y el saldo de la Concentradora aumenta por ese monto.

Este segundo paso separado es el punto central de tener una Colectora en
absoluto — si registrar y conciliar fueran el mismo paso, la Colectora no
haría nada que la Concentradora no hiciera ya. La separación de roles
(quien registra no es necesariamente quien concilia) es un control real:
evita que una sola persona declare que llegó dinero y lo vuelva
disponible para dispersar sin que nadie más lo confirme.

## Cómo esto cambia Dispersión y Deducción (doble entrada)

Antes, Dispersión y Deducción solo tocaban el `ledger_account` de la
tarjeta. Ahora:

- **Dispersión**: debita la Concentradora del Cliente dueño de la
  tarjeta, y acredita el `ledger_account` de la tarjeta. Si la
  Concentradora no tiene saldo suficiente, la operación falla
  (`failed`) — exactamente el mismo tratamiento de fondos insuficientes
  que ya existía para Deducción/Transferencia, solo que ahora también
  aplica al lado de fondeo.
- **Deducción**: debita el `ledger_account` de la tarjeta (sin cambios,
  ya validaba fondos suficientes ahí) y **acredita** la Concentradora —
  el dinero deducido de una tarjeta regresa al pool del Cliente, no
  desaparece.
- **Transferencia**: sigue sin tocar la Concentradora — mueve saldo entre
  dos tarjetas del mismo Cliente, es una reasignación interna del mismo
  pool que la Concentradora ya respalda en conjunto, no un movimiento de
  entrada/salida de ese pool.

Esto significa que el orden de validación en una Dispersión ahora es:
primero se intenta debitar la Concentradora (puede fallar ahí), y solo si
eso tiene éxito se acredita la tarjeta — igual que una Transferencia
nunca dejó a medias un movimiento (débito en origen sin el crédito en
destino), una Dispersión fallida por fondos insuficientes en la
Concentradora nunca deja un crédito huérfano en la tarjeta.

## Quién puede hacer qué

| Acción | Rol mínimo |
|---|---|
| Ver saldo y movimientos de la Concentradora y la Colectora | Cualquier rol de staff dentro de su alcance (incluye Auditor, solo lectura) |
| Registrar un depósito en la Colectora | Operador de Saldos, Admin Cliente, Super Admin |
| Conciliar un depósito (Colectora → Concentradora) | Admin Cliente, Super Admin |

La asimetría es deliberada: registrar un depósito es una tarea operativa
del día a día (igual que Dispersión/Deducción/Transferencia, ver
`docs/business/roles-and-permissions.md`); confirmar que ese dinero
declarado es real y ya se puede dispersar es una decisión de
administrador, con el mismo criterio de separación de responsabilidades
que ya existe entre solicitar y aprobar una operación de saldo.

## Un segundo camino de fondeo, paralelo a este (implementado — ADR-0021)

Este documento describe el fondeo **a nivel Cliente** (empresa deposita
en su Colectora, se concilia, se dispersa a tarjetas vía la
Concentradora). Desde `docs/adr/0021-conector-spei.md` existe un segundo
camino, **a nivel Tarjetahabiente**: un depósito SPEI directo a la CLABE
de la Cuenta Individual de una persona (`docs/adr/0020-cuenta-individual-tarjetahabiente.md`),
que **no** pasa por Colectora ni por conciliación manual — el proveedor
SPEI ya confirmó el depósito, acredita la Cuenta de inmediato. Un mismo
Tarjetahabiente puede recibir dinero por ambos caminos sin distinguirse
en su saldo (ver ADR-0020, "una sola Cuenta, sin distinguir origen del
dinero") — este documento (Concentradora/Colectora) sigue exactamente
igual, sin cambios, conviviendo con el nuevo camino.

## Fuera de alcance de esta iteración

- **Depósito SPEI directo a una tarjeta/Concentradora** vía este mismo
  flujo de Colectora: no aplica — el fondeo por SPEI vive a nivel Cuenta
  Individual, ver la sección de arriba, no como una forma nueva de
  registrar un depósito de Colectora.
- **Rechazar un depósito registrado por error**: no hay una acción para
  "descartar" un depósito `pending` sin conciliarlo — fuera de alcance,
  no solicitado.
- **Consolidación de Concentradoras entre empresa padre e hijas**: cada
  Cliente tiene la suya, sin vista consolidada de grupo — ver "Alcance"
  arriba. El "Estado de cuenta para directivos" (ADR-0022, ver abajo)
  muestra una fila de resumen **por** Cliente/filial, nunca una sola
  cifra sumada entre todos — sigue sin haber consolidación real.
- **Retirar dinero de la Concentradora hacia una cuenta bancaria externa**
  (lo inverso de un depósito): fuera de alcance, no solicitado.

## Visión futura (no implementado): cuenta raíz de Koons con comisión

Conversación de negocio del 2026-09-19: eventualmente el dinero de un
depósito externo no entrará directo a la Colectora de un Cliente como se
describe arriba. En su lugar, Koons (la empresa que opera la plataforma)
tendría su **propia cuenta a nivel raíz** — un nivel arriba de cualquier
Cliente, no una subsidiaria más de la jerarquía existente — y el flujo
completo sería:

```
Depósito externo → Cuenta [Concentradora/Colectora] de Koons (raíz) →
  Koons retiene una comisión → el neto se deposita en la Colectora del
  Cliente → (flujo ya descrito arriba) conciliar → Concentradora del
  Cliente → Dispersión a tarjetas
```

Esto convierte a Koons en el intermediario de todo el dinero que entra a
la plataforma, con un mecanismo de ingreso (la comisión) integrado al
flujo de fondeo mismo — no es una subsidiaria del Grupo Koons Holding del
seed de datos, es la empresa que opera KBM, conceptualmente por encima de
toda la jerarquía de Clientes.

**Deliberadamente no implementado todavía** — falta definir, entre otras
cosas: cómo se calcula la comisión (monto fijo, porcentaje, configurable
por Cliente), quién la configura, y si este flujo reemplaza por completo
el registro directo de depósitos en la Colectora de un Cliente (ya
implementado) o convive con él. No implementar nada de esto sin ese
diseño explícito — ver la regla MUST del `README.md` raíz.

## Estado de cuenta para directivos (ADR-0022, formato de descarga corregido por ADR-0023)
Solo Super Admin y Admin Cliente (`canViewExecutiveDashboard`) pueden ver
un resumen de movimientos de Concentradora + depósitos conciliados de
Colectora por periodo, con una fila por Cliente/filial dentro de su
alcance y detalle expandible línea por línea, más una descarga (PDF, con
branding de KBM/Koons) de ese detalle. Vive dentro de esta misma pestaña
"Tesorería", no es una pantalla nueva — ver
`docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`,
`docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md`, y
`docs/feature/tesoreria-cliente/README.md` para el detalle completo.
Operador y Auditor no ven esta sección específica, aunque sí el resto de
la Tesorería sin cambio.

## Ver también
- `docs/adr/0021-conector-spei.md` — el segundo camino de fondeo, a nivel
  Tarjetahabiente, que convive con este.
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — dónde vive el
  saldo que ese segundo camino acredita.
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — estado
  de cuenta para directivos y descarga de movimientos.
- `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` — formato PDF
  de esa descarga.
- `docs/business/approval-policy.md` y
  `docs/business/roles-and-permissions.md` — reglas de aprobación y roles
  que ya aplicaban a Dispersión/Deducción/Transferencia, sin cambios ahí.
- `docs/business/saldo-y-ledger.md` — el mismo patrón de ledger
  append-only, aplicado aquí a nivel Cliente en vez de Tarjeta.
- `docs/feature/tesoreria-cliente/` — detalle funcional y criterios de
  aceptación.
