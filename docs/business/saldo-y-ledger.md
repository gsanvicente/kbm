# Saldo (Ledger) de una Tarjeta

> Referencia viva. Última revisión: 2026-09-18.

## Qué es el "saldo" que se muestra

El saldo de una tarjeta **no es un campo editable** — es el
`balance_after` del movimiento (`ledger_entries`) más reciente de su
`ledger_account`. El ledger es append-only (ver
`docs/security/threat-model.md` punto 3): nunca se "pone" un saldo
directamente, se llega a él acumulando movimientos. Esta pantalla, por
ahora, solo **muestra** ese valor — no lo modifica.

## Por qué algunas tarjetas no tienen saldo que mostrar

Una tarjeta **disponible** (sin asignar) no tiene `ledger_account`
todavía — se crea recién en el momento de la asignación (ver
`docs/business/tarjetas-y-asignacion.md`). Por lo tanto no existe un
"saldo en cero" que mostrar para una tarjeta disponible: no hay cuenta,
punto. La UI debe distinguir claramente "sin cuenta de saldo" (tarjeta
disponible) de "cuenta con saldo cero" (tarjeta asignada sin movimientos
todavía) — son estados distintos.

## Una tarjeta bloqueada conserva su saldo

Bloquear una tarjeta (`docs/feature/bloqueo-de-tarjeta/`) es un estado
operativo de la tarjeta, no del dinero — el saldo no se toca ni se oculta
al bloquearla.

## Cómo cambia el saldo ahora

El saldo deja de ser puramente de lectura: `docs/business/approval-policy.md`
y `docs/feature/operacion-saldo-con-aprobacion/` cubren cómo una
Dispersión, Deducción o Transferencia terminan escribiendo un nuevo `ledger_entry` (append-only,
nunca se edita uno existente) y recalculando el `balance` cacheado de la
cuenta.

## Fuera de alcance de esta iteración

- **Multi-moneda por Cliente**: el campo `currency` existe en el modelo
  (por tarjeta), pero no hay conversión ni consolidación entre monedas.
- **Notificaciones al Tarjetahabiente** cuando su saldo cambia: fuera de
  alcance, no hay autoservicio todavía.

## Ver también
- `docs/feature/visualizacion-de-saldo/` — dónde se muestra este dato.
- `docs/feature/reclamos-de-movimientos/` — historial de movimientos y
  disputas sobre ellos (ya implementado, ver
  `docs/business/reclamos-de-movimientos.md`).
- `docs/feature/operacion-saldo-con-aprobacion/` — cómo y cuándo el saldo
  efectivamente cambia.
- `docs/business/tarjetas-y-asignacion.md` — ciclo de vida de la tarjeta
  y cuándo se crea el `ledger_account`.
