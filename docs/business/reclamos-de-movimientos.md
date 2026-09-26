# Reclamos sobre Movimientos

> Referencia viva. Última revisión: 2026-09-25.

## Qué es un reclamo y por qué es una entidad separada

Un reclamo (`movement_claims`) es una disputa sobre un movimiento
(`ledger_entries`) **ya ejecutado** — "no reconozco este cargo", "el
monto está mal". Es deliberadamente **distinto** de `balance_operations`
(que es una operación *antes* de ejecutarse, sujeta a aprobación — ver
`docs/business/approval-policy.md`): un reclamo nace después del hecho, y
nunca modifica el movimiento original (`ledger_entries` sigue siendo
append-only, ver `docs/security/threat-model.md` punto 3) — solo lo
acompaña con un registro de disputa.

Relación 1:1 — un movimiento tiene a lo sumo un reclamo.

## Ciclo de vida

```
Abierto → (En revisión) → Resuelto a favor / Rechazado
```

- **Abierto**: recién solicitado.
- **En revisión**: existe en el modelo para cuando se implemente
  asignación de revisores — en esta iteración nadie lo establece
  manualmente, solo aparece si se sembró así.
- **Resuelto a favor / Rechazado**: estados finales, con notas de
  resolución obligatorias.

Resolver un reclamo **no revierte el movimiento ni mueve saldo** — es un
registro de la decisión, no una operación financiera. Si en el futuro
"resuelto a favor" implica devolver dinero, esa reversión sería una
`balance_operation` nueva y separada (con su propia aprobación si
corresponde), no parte de esta feature.

## Quién puede solicitar y quién puede resolver

Separación deliberada de responsabilidades:

- **Solicitar un reclamo** (desde `admin/`, en nombre de un
  Tarjetahabiente): Super Admin, Admin Cliente, **Operador** — mismo
  grupo que puede bloquear/desbloquear tarjetas (ver
  `docs/business/tarjetas-y-asignacion.md`), es una acción operativa del
  día a día.
- **El propio Tarjetahabiente también puede solicitar un reclamo**,
  desde `cardholder/`, únicamente sobre sus propios movimientos —
  mismo mecanismo (`movement_claims`), nunca sobre el movimiento de
  otro. Ver `docs/adr/0018-cardholder-filed-claims.md` para el cambio de
  schema que esto requirió (`requested_by` — staff — pasó a ser
  opcional, con una columna paralela hacia `cardholders`). El chequeo de
  pertenencia es por Cuenta Individual, no por tarjeta (ver
  `docs/adr/0020-cuenta-individual-tarjetahabiente.md`,
  `docs/adr/0028-reorganizacion-ux-cardholder.md`) — un Tarjetahabiente
  sin ninguna tarjeta asignada todavía puede reclamar un depósito o pago
  SPEI de su Cuenta igual que uno con tarjeta.
- **Resolver un reclamo** (a favor o rechazado): solo **Super Admin y
  Admin Cliente** — quien opera el día a día (o el propio
  Tarjetahabiente que lo presentó) no decide el resultado de una
  disputa.
- **Auditor**: ve reclamos y su estado, no puede solicitar ni resolver.

## Dónde vive en la UI

No es una entidad navegable independiente en esta iteración — se
solicita y se ve desde el detalle del movimiento al que pertenece
(panel/diálogo, no una pantalla ni breadcrumb propios), tanto en
`admin/` como en `cardholder/` (cada app con su propio diálogo, sin
código compartido — ADR-0002). Ver
`docs/feature/reclamos-de-movimientos/README.md`.

## Fuera de alcance de esta iteración

- Adjuntar evidencia (archivos) al reclamo — solo motivo en texto libre.
- Transición manual a "En revisión" (asignación de revisor).
- Notificar al Tarjetahabiente sobre el estado de su reclamo.
- Listado global de Reclamos (cross-tarjeta) — evaluar cuando haya
  volumen suficiente para justificarlo, mismo criterio que se usó para
  los listados globales de Tarjetahabientes/Tarjetas.
- Reversión de saldo cuando un reclamo se resuelve a favor (ver nota de
  ciclo de vida arriba).
