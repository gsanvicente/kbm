# Tarjetas: ciclo de vida y asignación

> Referencia viva. Última revisión: 2026-09-24.

## Ciclo de vida de una Tarjeta

```
disponible → (asignación) → activa ⇄ bloqueo temporal (frozen) → bloqueada
                                  ↓
                              cancelada → (reemplazo) → activa (nueva tarjeta, misma Cuenta)
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
- **Cancelada** (`cancelled`, implementado desde
  `docs/adr/0020-cuenta-individual-tarjetahabiente.md`): a diferencia de
  `blocked`/`frozen`, **nunca es reversible** — esa tarjeta física/virtual
  específica queda retirada para siempre. Guarda `cancelled_reason`
  (`expirada` | `robada` | `extraviada`), mismo espíritu que
  `blocked_reason`. Dispara la sección "Reemplazo de tarjeta" más abajo.

Una tarjeta nace **disponible**, siempre perteneciendo a un Cliente
específico desde el inicio (el pool no es "global sin dueño" — una
tarjeta que llegó para Koons Subsidiaria A no puede asignarse a un
tarjetahabiente de Subsidiaria B).

**Corrección sobre lo que decía esta nota antes de ADR-0020**: se
afirmaba que el `ledger_account` se crea "en el momento de la asignación,
no antes — no tiene sentido llevar saldo de algo que nadie tiene
todavía". Eso ya no es cierto: el saldo vive en la **Cuenta Individual**
del Tarjetahabiente (`docs/business/saldo-y-ledger.md`), que nace al dar
de alta al Tarjetahabiente — antes incluso de que tenga una tarjeta
asignada. Una tarjeta ya no "trae" su propio saldo al asignarse: se
conecta a una Cuenta que puede ya existir y tener movimientos (por
ejemplo, un depósito SPEI recibido antes de que llegara la tarjeta — ver
`docs/adr/0021-conector-spei.md`).

## Reemplazo de tarjeta (implementado — ADR-0020)

Cierra el hueco que esta misma nota dejaba pendiente hasta ahora: *"si la
única tarjeta de alguien se pierde o esa persona cambia de tarjeta, no
hay forma de dejarle asignar una nueva sin pasar por otro camino"*.

- **Quién puede hacerlo**: solo staff — Super Admin o Admin Cliente,
  mismo criterio que "Quién puede asignar" más abajo. El propio
  Tarjetahabiente **no** puede iniciar un reemplazo en esta iteración
  (revisitar si el negocio lo pide).
- **Qué pasa, en una sola operación atómica**: la tarjeta actual pasa a
  `cancelled` (con su motivo) y, en la misma transacción, se toma una
  tarjeta `disponible` del mismo Cliente y se asigna a la **misma Cuenta
  Individual** — reutiliza el pool de tarjetas disponibles que ya existe,
  no crea una fuente nueva de tarjetas.
- **Qué no se toca**: el saldo, la CLABE y el historial de movimientos de
  la Cuenta — solo cambia el instrumento (PAN, vigencia) sobre esa misma
  Cuenta. Para quien ve el historial, es continuo; solo cambian los
  últimos 4 dígitos hacia adelante.
- **Por qué es atómica**: mismo principio de "nunca a medias" que ya
  rige cualquier operación de saldo en el proyecto — el invariante
  "siempre hay una tarjeta activa por Cuenta" nunca debe romperse en un
  estado observable, ni siquiera un instante.

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

## Límite de Cuentas (y por tanto de tarjetas activas) por Tarjetahabiente

Configurable por Cliente (`client_settings.max_active_cards_per_cardholder`,
mismo patrón que `approval_rules`). **Desde ADR-0020, cuenta Cuentas
Individuales, no tarjetas activas sueltas** — dentro de cada Cuenta,
"como máximo una tarjeta activa a la vez" ya está garantizado por
construcción (ver "Reemplazo de tarjeta" arriba), así que el límite deja
de necesitar la lógica de "una cancelada o reemplazada libera espacio":
una Cuenta ocupa su cupo mientras exista, sin importar cuántas tarjetas
haya tenido a lo largo del tiempo.

**Default: 1 Cuenta (y por tanto 1 tarjeta activa) por Tarjetahabiente** —
no "sin restricción".
Es el tipo de cuenta actual de KBM el que exige esto; un Cliente puede
tener un override explícito distinto (ej. Koons Subsidiaria B permite 2
en el seed de esta iteración, para probar que el mecanismo sí varía por
Cliente), pero cualquier Cliente sin override cae en el default de 1, no
en "sin límite". **Editable desde 2026-09-21** — pestaña "Configuración"
en el detalle de un Cliente, solo Super Admin/Admin Cliente, ver
`docs/feature/configuracion-de-cliente/README.md`. Antes de eso vivía
solo como dato sembrado, sin ninguna pantalla para cambiarlo.

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

**Resuelto por ADR-0020** (antes era deuda pendiente marcada aquí mismo):
reemplazar la única tarjeta de alguien (perdida, robada, vencida) ya no
requiere "otro camino" — ver "Reemplazo de tarjeta" arriba. Sigue **fuera
de alcance**, sin cambios: mover una tarjeta ya asignada a *otro*
Tarjetahabiente (eso no es un reemplazo, es una reasignación entre
personas distintas) — no solicitado.

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
- **Cancelar una tarjeta por decisión directa del staff** (fuera de los
  tres motivos ya cubiertos por "Reemplazo de tarjeta" — expirada, robada,
  extraviada): no implementado, no solicitado. Bloquear/desbloquear sí
  está implementado — ver `docs/feature/bloqueo-de-tarjeta/`.
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

## Ver también
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — dónde vive
  realmente el saldo desde esta ADR, y el diseño completo de "Reemplazo
  de tarjeta".
- `docs/business/saldo-y-ledger.md` — el saldo, ahora de la Cuenta
  Individual, no de la tarjeta.
- `docs/adr/0021-conector-spei.md` — por qué el saldo tuvo que dejar de
  vivir en la tarjeta.
