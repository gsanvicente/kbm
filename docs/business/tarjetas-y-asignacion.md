# Tarjetas: ciclo de vida y asignación

> Referencia viva. Última revisión: 2026-09-19.

## Ciclo de vida de una Tarjeta

```
disponible → (asignación) → activa ⇄ bloqueo temporal (frozen) → bloqueada / cancelada
```

- **Disponible**: existe en el sistema, pertenece a un Cliente, pero no
  está ligada a ningún Tarjetahabiente todavía — es el "lote de tarjetas
  disponibles" que un Admin puede repartir.
- **Activa**: asignada a un Tarjetahabiente, en uso normal.
- **Bloqueada**: asignada, pero deshabilitada por el staff (ver
  `docs/feature/bloqueo-de-tarjeta/`) — reversible, vuelve a **Activa**
  al desbloquear, salvo la excepción de "Motivo de bloqueo" abajo. Pesa
  más que un "Bloqueo temporal" — puede aplicarse encima de uno.
- **Bloqueo temporal** (`frozen`, etiqueta distinta de "Bloqueada" a
  propósito): autocongelamiento del propio Tarjetahabiente desde
  `cardholder/`, **implementado** — ver
  `docs/business/autoservicio-tarjetahabiente.md`, "Congelar vs.
  bloquear una tarjeta". El staff nunca lo origina, solo puede
  revertirlo (o bloquear encima).
- **Cancelada**: estado operativo aún no implementado (gestión de saldo,
  feature futura — ver `docs/feature/operacion-saldo-con-aprobacion/`).

Una tarjeta nace **disponible**, siempre perteneciendo a un Cliente
específico desde el inicio (el pool no es "global sin dueño" — una
tarjeta que llegó para Koons Subsidiaria A no puede asignarse a un
tarjetahabiente de Subsidiaria B). Su `ledger_account` (cuenta de saldo)
se crea **en el momento de la asignación**, no antes — no tiene sentido
llevar saldo de algo que nadie tiene todavía.

## Motivo de bloqueo

Una tarjeta `blocked` guarda por qué se bloqueó, `blocked_reason`:

- **`manual`**: alguien del staff la bloqueó directamente (ej. reporte de
  robo/fraude) — ver `docs/feature/bloqueo-de-tarjeta/`. Cualquiera con
  permiso de bloquear/desbloquear puede revertirlo.
- **`cardholder_inactive`**: se bloqueó automáticamente porque su
  Tarjetahabiente fue desactivado — ver
  `docs/business/desactivacion-de-tarjetahabientes.md`. **No se puede
  desbloquear mientras el Tarjetahabiente siga inactivo**, sin importar
  el rol de quien lo intente; una vez reactivado el Tarjetahabiente, sí
  se puede desbloquear, pero solo manualmente y una tarjeta a la vez —
  reactivar no las desbloquea automáticamente.

Desactivar a un Tarjetahabiente nunca sobrescribe un `blocked_reason`
existente — si una tarjeta ya estaba bloqueada manualmente, conserva ese
motivo aunque su Tarjetahabiente pase a inactivo después.

## Límite de tarjetas activas por Tarjetahabiente

Configurable por Cliente (`client_settings.max_active_cards_per_cardholder`,
mismo patrón que `approval_rules`), cuenta **solo tarjetas activas** — una
tarjeta cancelada o reemplazada libera espacio para asignar una nueva.

**Default: 1 tarjeta activa por Tarjetahabiente** — no "sin restricción".
Es el tipo de cuenta actual de KBM el que exige esto; un Cliente puede
tener un override explícito distinto (ej. Koons Subsidiaria B permite 2
en el seed de esta iteración, para probar que el mecanismo sí varía por
Cliente), pero cualquier Cliente sin override cae en el default de 1, no
en "sin límite". Esta iteración no expone una pantalla para editar el
valor por Cliente (mismo criterio que `approval_rules`, tampoco editable
todavía) — vive como dato sembrado en cada repositorio/adaptador.

## Quién puede asignar

Mismo criterio que gestionar Tarjetahabientes (ver
`docs/business/roles-and-permissions.md`): Super Admin y Admin Cliente.
Operador y Auditor pueden ver el estado de las tarjetas pero no asignar.
Tampoco se puede asignar una tarjeta a un **Tarjetahabiente inactivo** —
ver `docs/business/desactivacion-de-tarjetahabientes.md` — el selector de
Tarjetahabiente al asignar solo ofrece a los activos del Cliente dueño de
la tarjeta.

Dos puntos de entrada a la misma operación, en `admin/`:
- **Desde la tarjeta** (`Tarjetas` → una tarjeta `disponible` → botón
  "Asignar"): elige el Tarjetahabiente destino. Es el original de esta
  feature.
- **Desde el Tarjetahabiente** (su detalle → sección "Tarjetas" → botón
  "Asignar tarjeta"): elige la tarjeta disponible del mismo Cliente.
  Agregado después, porque con el límite de 1 la forma natural de
  pensarlo es "dale una tarjeta a esta persona", no "busca una tarjeta
  libre y dásela a alguien". Ambos llaman al mismo
  `CardRepository.assign`, con las mismas reglas.

**Fuera de alcance de esta pasada, deliberadamente**: liberar/reasignar
una tarjeta ya asignada (devolverla al pool, o moverla a otro
Tarjetahabiente). Con límite de 1 esto importa de verdad — hoy, si la
única tarjeta de alguien se pierde o esa persona cambia de tarjeta, no
hay forma de dejarle asignar una nueva sin pasar por otro camino (ej.
bloquear la vieja no libera el cupo, `assign()` solo acepta tarjetas
`disponible`). Se decidió no construirlo en esta pasada; revisitar antes
de considerar el límite de 1 completamente funcional en producción.

## Quién puede bloquear / desbloquear

Distinto del criterio de asignación: **Super Admin, Admin Cliente y
Operador** pueden bloquear/desbloquear (el rol Operador existe
específicamente para operar sobre tarjetas ya asignadas — ver la tabla de
roles). Solo **Auditor** no puede. Ver
`docs/feature/bloqueo-de-tarjeta/README.md` para el alcance exacto de
esta iteración (acción directa, sin flujo de aprobación todavía, aunque
el modelo de datos ya lo soporta vía `approval_rules` para cuando exista
la cola de Aprobaciones). Excepción: nadie, sin importar su rol, puede
**desbloquear** una tarjeta mientras su Tarjetahabiente esté inactivo —
ver "Motivo de bloqueo" arriba.

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

## Backend
`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` migró la
fuente de verdad de Tarjetas y Ledger (saldo/movimientos) a un backend Go
compartido entre `admin/` y `cardholder/`, en memoria — el ciclo de vida
y las reglas de esta página no cambiaron, solo dónde vive el dato. El
límite de tarjetas activas por Cliente vive ahí de forma independiente
(`backend/internal/adapters/memory/repository/seed.go`), no derivado de
los datos de Cliente de `admin/` — ese backend no conoce la jerarquía de
Clientes (ver esa ADR, alcance).
