# Política de aprobación de operaciones — KBM

> Referencia viva. Última revisión: 2026-09-15.

## Principio

No toda operación de saldo requiere aprobación — las reglas son
**configurables por Cliente**, no una regla global fija. Cada Cliente
define, por tipo de operación, si requiere aprobación y a partir de qué
monto (`approval_rules`, ver `backend/migrations/0001_init.sql`).

Ejemplo (el que usa el seed local en
`backend/scripts/init-db/001_seed.sql`): transferencias por encima de
$500 requieren aprobación; cargas no requieren aprobación.

## Flujo

1. Un usuario (Operador, Admin Cliente, o el propio Tarjetahabiente vía
   autoservicio) solicita una operación de saldo.
2. El caso de uso evalúa las `approval_rules` del Cliente para ese tipo de
   operación y monto.
3. Si no requiere aprobación → la operación pasa directo a `executed`.
4. Si requiere aprobación → queda en `pending_approval`. El aprobador
   típico es el Admin Cliente de la empresa dueña de la tarjeta.
5. Aprobada → `executed` (se escribe el movimiento en el ledger).
   Rechazada → `rejected` (no se toca el ledger).

## Por qué es un estado, no una transacción directa

Modelar la operación como una entidad con estado (no una escritura directa
al ledger) es lo que permite:
- Trazabilidad completa: quién solicitó, quién aprobó/rechazó, cuándo.
- Que el ledger (`ledger_entries`) siga siendo append-only y solo reciba
  movimientos ya aprobados — nunca solicitudes en proceso.

Ver también: `docs/security/threat-model.md` (repudio de operaciones) y
`docs/feature/operacion-saldo-con-aprobacion/` para el detalle funcional y
los escenarios Gherkin.
