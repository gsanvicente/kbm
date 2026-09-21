# Política de aprobación de operaciones — KBM

> Referencia viva. Última revisión: 2026-09-15.

## Principio

No toda operación de saldo requiere aprobación — las reglas son
**configurables por Cliente**, no una regla global fija. Cada Cliente
define, por tipo de operación, si requiere aprobación y a partir de qué
monto (`approval_rules`, ver `backend/migrations/0001_init.sql`).

Ejemplo (el que usa el seed local en
`backend/scripts/init-db/001_seed.sql`): transferencias por encima de
$500 requieren aprobación; Dispersiones no requieren aprobación (ver
`docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
"Nomenclatura" — "Dispersión" es el nombre visible del tipo `load`).

## Flujo

1. Un usuario (Operador, Admin Cliente, Super Admin, o el propio
   Tarjetahabiente vía autoservicio) solicita una operación de saldo —
   solo Auditor no puede.
2. El caso de uso evalúa las `approval_rules` del Cliente para ese tipo de
   operación y monto.
3. Si no requiere aprobación → la operación pasa directo a `executed`.
4. Si requiere aprobación → queda en `pending_approval`. El aprobador
   típico es el Admin Cliente de la empresa dueña de la tarjeta.
5. Aprobada → `executed` (se escribe el movimiento en el ledger).
   Rechazada → `rejected` (no se toca el ledger). En esta iteración
   aprobar ejecuta en el mismo paso — no existe un estado intermedio
   `approved` visible; ver la nota de estados más abajo.

## Qué pasa si el Cliente no configuró una regla para ese tipo de operación

**Sin `approval_rule` para ese Cliente + tipo de operación ⇒ requiere
aprobación por defecto.** Es una decisión deliberada, fail-safe: nunca se
mueve dinero sin control explícito solo porque a alguien se le olvidó
configurar la regla. El seed local (`001_seed.sql`) deja el tipo `debit`
sin regla en ambas subsidiarias a propósito, para ejercitar este default.

Un Cliente que sí quiere que un tipo de operación se ejecute siempre sin
aprobación debe configurarlo explícitamente
(`approval_rules.requires_approval = false`), como ya hace el seed con
`load`. **Editable desde 2026-09-21** vía la pestaña "Configuración" del
detalle de un Cliente (Super Admin/Admin Cliente) — ver
`docs/feature/configuracion-de-cliente/README.md`; antes solo se podía
cambiar editando `001_seed.sql` a mano.

## Umbral de monto (`min_amount`)

Cuando `requires_approval = true` y hay un `min_amount` configurado, la
aprobación solo aplica a montos que lo **superen** (estrictamente mayor,
no igual) — ver el escenario de transferencias >$500 en
`docs/feature/operacion-saldo-con-aprobacion/acceptance.feature`. Si
`min_amount` es `NULL` con `requires_approval = true`, aplica a
cualquier monto.

## Estados de una operación y por qué `approved` existe pero no se usa aún

`operation_status` tiene 5 valores (`pending_approval`, `approved`,
`rejected`, `executed`, `failed`) pero esta iteración solo produce 4:
aprobar pasa directo de `pending_approval` a `executed` (o a `failed` si
falla la ejecución, ej. fondos insuficientes en el origen). `approved`
queda reservado para un futuro flujo asíncrono (aprobar ahora, ejecutar
después vía un worker) — no lo elimines del enum ni lo trates como error
si aparece en otro lugar del código.

## Por qué es un estado, no una transacción directa

Modelar la operación como una entidad con estado (no una escritura directa
al ledger) es lo que permite:
- Trazabilidad completa: quién solicitó, quién aprobó/rechazó, cuándo.
- Que el ledger (`ledger_entries`) siga siendo append-only y solo reciba
  movimientos ya aprobados — nunca solicitudes en proceso.

Ver también: `docs/security/threat-model.md` (repudio de operaciones) y
`docs/feature/operacion-saldo-con-aprobacion/` para el detalle funcional y
los escenarios Gherkin.
