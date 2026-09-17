# Tarjetas: ciclo de vida y asignación

> Referencia viva. Última revisión: 2026-09-17.

## Ciclo de vida de una Tarjeta

```
disponible → (asignación) → activa → bloqueada / congelada / cancelada
```

- **Disponible**: existe en el sistema, pertenece a un Cliente, pero no
  está ligada a ningún Tarjetahabiente todavía — es el "lote de tarjetas
  disponibles" que un Admin puede repartir.
- **Activa**: asignada a un Tarjetahabiente, en uso normal.
- **Bloqueada**: asignada, pero deshabilitada temporalmente por el staff
  (ver `docs/feature/bloqueo-de-tarjeta/`) — reversible, vuelve a
  **Activa** al desbloquear.
- **Congelada / Cancelada**: estados operativos aún no implementados
  (gestión de saldo, feature futura — ver
  `docs/feature/operacion-saldo-con-aprobacion/`).

Una tarjeta nace **disponible**, siempre perteneciendo a un Cliente
específico desde el inicio (el pool no es "global sin dueño" — una
tarjeta que llegó para Koons Subsidiaria A no puede asignarse a un
tarjetahabiente de Subsidiaria B). Su `ledger_account` (cuenta de saldo)
se crea **en el momento de la asignación**, no antes — no tiene sentido
llevar saldo de algo que nadie tiene todavía.

## Límite de tarjetas activas por Tarjetahabiente

Configurable por Cliente (`client_settings.max_active_cards_per_cardholder`,
mismo patrón que `approval_rules`), cuenta **solo tarjetas activas** — una
tarjeta cancelada o reemplazada libera espacio para asignar una nueva. Sin
límite configurado = sin restricción.

## Quién puede asignar

Mismo criterio que gestionar Tarjetahabientes (ver
`docs/business/roles-and-permissions.md`): Super Admin y Admin Cliente.
Operador y Auditor pueden ver el estado de las tarjetas pero no asignar.

## Quién puede bloquear / desbloquear

Distinto del criterio de asignación: **Super Admin, Admin Cliente y
Operador** pueden bloquear/desbloquear (el rol Operador existe
específicamente para operar sobre tarjetas ya asignadas — ver la tabla de
roles). Solo **Auditor** no puede. Ver
`docs/feature/bloqueo-de-tarjeta/README.md` para el alcance exacto de
esta iteración (acción directa, sin flujo de aprobación todavía, aunque
el modelo de datos ya lo soporta vía `approval_rules` para cuando exista
la cola de Aprobaciones).

## Datos que se muestran (y los que no)

KBM nunca almacena ni muestra el PAN completo — ver
`docs/security/compliance-notes.md`. Lo visible es: `masked_pan`
(terminaciones), red (Visa/Mastercard), vigencia (mes/año), estado, y
fecha de asignación. No hay enmascaramiento adicional por rol dentro de
esta iteración (mismo criterio que se documentó para los datos KYC del
Tarjetahabiente).

## Fuera de alcance de esta iteración

- **Alta de tarjetas nuevas en el sistema**: cómo una tarjeta llega a
  estado "disponible" por primera vez depende de la integración real con
  el procesador de tarjetas externo — no implementado todavía. El pool de
  disponibles en esta iteración es dato semilla fijo.
- **Trackeo formal de lotes/envíos** (ej. "Lote #123, 50 tarjetas
  recibidas el 10/09"): se evaluó y se descartó para esta iteración —
  cada tarjeta solo tiene un estado `disponible`/`activa`/etc., sin
  entidad de lote. Revisitar si el negocio lo necesita.
- **Congelar/cancelar una tarjeta**: es una operación de saldo aún no
  implementada (ver `docs/feature/operacion-saldo-con-aprobacion/`).
  Bloquear/desbloquear sí está implementado — ver
  `docs/feature/bloqueo-de-tarjeta/`.
- **Flujo de aprobación para bloquear/desbloquear**: el modelo de datos
  ya soporta configurar `approval_rules` para `operation_type = 'block'`
  o `'unblock'`, pero no hay cola de Aprobaciones todavía para resolver
  una que quede pendiente — por eso, en esta iteración, ningún Cliente
  tiene esa regla activada (bloquear/desbloquear siempre se ejecuta de
  inmediato). Activarla sin la cola de Aprobaciones dejaría la operación
  atascada sin forma de aprobarla.
