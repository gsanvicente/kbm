# Saldo (Ledger) — de la Cuenta Individual, no de la Tarjeta

> Referencia viva. Última revisión: 2026-09-24.

## Corrección de alcance (ADR-0020)

Esta nota decía originalmente que el saldo era "de una Tarjeta". Ya no es
así: desde `docs/adr/0020-cuenta-individual-tarjetahabiente.md`, el saldo
vive en la **Cuenta Individual** del Tarjetahabiente — la tarjeta es un
instrumento de gasto sobre esa Cuenta, no la dueña del dinero. Para quien
usa `admin/` o `cardholder/` el efecto visible cambia poco (se sigue
mostrando "el saldo de tu tarjeta" en pantalla), pero conceptualmente el
dato ya no pertenece a la tarjeta: sobrevive a un reemplazo de tarjeta
(`docs/business/tarjetas-y-asignacion.md`, "Reemplazo de tarjeta") y
puede recibir movimientos (depósito SPEI, ver
`docs/adr/0021-conector-spei.md`) incluso antes de que exista una tarjeta
asignada.

## Qué es el "saldo" que se muestra

El saldo de una Cuenta Individual **no es un campo editable** — es el
`balance_after` del movimiento (`ledger_entries`) más reciente de su
`ledger_account`. El ledger es append-only (ver
`docs/security/threat-model.md` punto 3): nunca se "pone" un saldo
directamente, se llega a él acumulando movimientos. Esta pantalla, por
ahora, solo **muestra** ese valor — no lo modifica.

## Por qué algunas tarjetas no tienen saldo que mostrar

Una tarjeta **disponible** (sin asignar) no está ligada a ninguna Cuenta
Individual todavía — eso ocurre recién al asignarla (ver
`docs/business/tarjetas-y-asignacion.md`). Por lo tanto no existe un
"saldo en cero" que mostrar para una tarjeta disponible: no hay Cuenta
detrás, punto. La UI debe distinguir claramente "sin Cuenta" (tarjeta
disponible) de "Cuenta con saldo cero" (tarjeta asignada, Cuenta sin
movimientos todavía) — son estados distintos.

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
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — por qué el saldo
  dejó de vivir en la tarjeta.
- `docs/adr/0021-conector-spei.md` — depósitos y pagos que también
  afectan este mismo saldo.
- `docs/feature/visualizacion-de-saldo/` — dónde se muestra este dato.
- `docs/feature/reclamos-de-movimientos/` — historial de movimientos y
  disputas sobre ellos (ya implementado, ver
  `docs/business/reclamos-de-movimientos.md`).
- `docs/feature/operacion-saldo-con-aprobacion/` — cómo y cuándo el saldo
  efectivamente cambia.
- `docs/business/tarjetas-y-asignacion.md` — ciclo de vida de la tarjeta
  y cuándo se crea el `ledger_account`.
