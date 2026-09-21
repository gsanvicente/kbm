# Roles y permisos — KBM

> Referencia viva. Última revisión: 2026-09-21.

## Roles administrativos/staff

| Rol | Alcance | Puede hacer |
|---|---|---|
| Super Admin (Koons) | Global, todos los Clientes | Crear/gestionar Clientes, usuarios, configuración del sistema, ver todo, incluye todo lo de Admin Cliente y de Operador de Saldos |
| Admin Cliente | Su Cliente + descendientes (si tiene hijas) | Gestionar tarjetahabientes/tarjetas, crear nuevas filiales dentro de su propio alcance, asignar Operadores, aprobar/rechazar operaciones pendientes |
| Operador de Saldos | Su Cliente + descendientes | **Dispersión, Deducción, Transferencia de saldo** (es justo su enfoque), bloquear/desbloquear tarjetas, solicitar reclamos sobre movimientos |
| Auditor | Su Cliente + descendientes (o global) | Ver saldos, movimientos, operaciones y reportes — sin poder modificar nada |

> **Nota histórica (2026-09-19):** por un momento este rol se restringió
> por error para NO poder solicitar Dispersión/Deducción/Transferencia
> (razonamiento: "mover dinero es acción de administrador"), contradiciendo
> esta tabla ya documentada. Se revirtió el mismo día — el enfoque de
> este rol siempre fue justamente operar el saldo del día a día, con el
> control real puesto en `approval_rules` (umbral de monto), no en
> restringir quién puede solicitar. Ver `docs/business/approval-policy.md`
> y la regla MUST en el `README.md` raíz sobre preguntar ante conflictos
> con lo ya documentado.

## Herencia sobre la jerarquía padre/hija

Cuando un Cliente tiene empresas hijas (ver
`docs/adr/0003-multitenancy-rls-hierarchy.md`):

- La visibilidad es **unidireccional**: el padre ve/opera sobre sus
  descendientes; una hija nunca ve al padre ni a sus hermanas.
- **Todos** los roles del padre heredan ese alcance sobre las
  descendientes — no solo Admin Cliente. Un Operador de la empresa padre
  puede operar tarjetas de las hijas exactamente igual que si fueran de su
  propia empresa.
- Esta herencia se aplica en dos capas (defensa en profundidad): la
  autorización de aplicación (puerto `AuthorizationPort`, ver
  `backend/internal/application/ports/doc.go`) y Row-Level Security en
  Postgres.

## Gestión de Clientes (alta, edición, desactivación)

**Super Admin** y **Admin Cliente** pueden dar de alta, editar,
desactivar y reactivar un Cliente (`canManageClients`, mismo grupo que
`canManageCardholders`) — **Operador y Auditor no pueden**.

**Alta**: el nuevo Cliente se crea siempre como hijo de un Cliente dentro
del alcance de quien lo crea:
- **Super Admin**: puede crear un Cliente sin padre (nueva empresa raíz),
  o como hijo de cualquier Cliente existente en el sistema.
- **Admin Cliente**: puede crear un Cliente como hijo de **su propia
  empresa**, o de **cualquiera de sus descendientes** (filiales ya
  existentes) — no solo directo debajo de sí mismo. No puede crear una
  empresa raíz nueva sin padre, ni un Cliente fuera de su propio alcance.

Cada Cliente nuevo (sin importar en qué punto de la jerarquía se cree)
requiere su propio expediente KYB completo — ver
`docs/business/kyb-cliente.md` — nunca hereda datos legales de su
empresa padre, porque cada filial es su propia entidad legal
independiente.

**Editar**: mismo alcance que crear — Super Admin en cualquiera, Admin
Cliente en su propia empresa y descendientes. Un Cliente **inactivo
puede seguir editándose** por quien tiene alcance sobre él.

**Desactivar/reactivar**: mismo grupo, con una restricción adicional —
un **Admin Cliente puede desactivar/reactivar cualquiera de sus
descendientes, pero nunca su propia empresa** (se auto-bloquearía a sí
mismo sin forma de revertirlo). Super Admin puede desactivar/reactivar
cualquier Cliente, incluida una empresa raíz. Desactivar se propaga en
cascada a **todos** los descendientes; una empresa inactiva no puede
operar en ningún nivel (ni su propio staff, ni un ancestro operando en
su nombre) — ver `docs/business/desactivacion-de-clientes.md` para el
detalle completo del enforcement.

## Gestión de Tarjetahabientes (alta, edición, desactivación)

Distinto de "ver" (todos los roles de staff pueden ver tarjetahabientes
dentro de su alcance): **dar de alta**, **editar información** (nombre,
documento, contacto) o **desactivar/reactivar** un tarjetahabiente está
limitado a:

- **Super Admin** y **Admin Cliente** — coherente con que Admin Cliente ya
  tiene "gestionar tarjetahabientes" en su alcance en la tabla de arriba.
  El alta siempre queda ligada al Cliente desde el que se crea (sin
  selector de empresa aparte, a diferencia de Cliente).
- **Operador** y **Auditor NO pueden** — el Operador gestiona *saldos*
  (operaciones de tarjeta), no el perfil del tarjetahabiente; el Auditor
  es de solo lectura por definición.

Ninguna de las tres requiere aprobación (no son `balance_operation`, no
mueven dinero) — son acciones directas sujetas solo al chequeo de rol de
arriba, aunque desactivar sí pide una **confirmación explícita** en la UI
por su impacto (bloquea las tarjetas del tarjetahabiente). A diferencia de
Cliente, un tarjetahabiente **inactivo no puede editarse** — el objetivo
es no modificar un registro que podría ser evidencia de auditoría. Ver
`docs/business/desactivacion-de-tarjetahabientes.md` y
`docs/feature/alta-y-gestion-de-tarjetahabientes/`.

## Gestión de usuarios de staff (alta, edición, desactivación)

Ver `docs/business/gestion-de-usuarios-staff.md` para el detalle
completo. Resumen: **Super Admin** y **Admin Cliente** pueden dar de
alta, editar y desactivar/reactivar usuarios de staff dentro de su
alcance (mismo grupo y misma herencia jerárquica que Clientes y
Tarjetahabientes) — **Operador y Auditor no pueden**. El rol asignable
nunca incluye Super Admin (esa cuenta sigue siendo solo de seed), y
nadie puede desactivar su propia cuenta.

## Tesorería del Cliente (Cuenta Concentradora / Cuenta Colectora)

Ver `docs/business/tesoreria-cliente.md` para el detalle funcional. Resumen de permisos:

- **Ver** saldo y movimientos de ambas cuentas: cualquier rol de staff
  dentro de su alcance, incluido Auditor (solo lectura).
- **Registrar un depósito** en la Colectora: Operador de Saldos, Admin
  Cliente, Super Admin — mismo grupo que ya solicita operaciones de
  saldo, es la misma naturaleza operativa.
- **Conciliar** un depósito (Colectora → Concentradora): solo Admin
  Cliente y Super Admin — separación deliberada, quien registra un
  depósito no necesariamente es quien confirma que es real y ya está
  disponible para dispersar. Disponible desde dos lugares (Tesorería del
  Cliente y la pestaña "Depósitos por conciliar" del hub "Operaciones de
  saldo") — mismo permiso, misma acción, ver
  `docs/feature/tesoreria-cliente/README.md`, "Dos entry points para
  conciliar".

## Gestión de Tarjetas (asignar del pool de disponibles)

Mismo criterio que la gestión de Tarjetahabientes: **Super Admin** y
**Admin Cliente** pueden asignar una tarjeta disponible a un
Tarjetahabiente; Operador y Auditor solo ven el estado de las tarjetas.
Ver `docs/business/tarjetas-y-asignacion.md` para el ciclo de vida
completo y el límite configurable de tarjetas activas por
Tarjetahabiente.

## Panel directivo ("Inicio")

Ver `docs/feature/panel-directivo/README.md` para el detalle funcional.
Resumen de permisos:

- **Super Admin** y **Admin Cliente** aterrizan en "Inicio" al iniciar
  sesión y son los únicos que ven ese ítem en el menú lateral
  (`Role.canViewExecutiveDashboard`, mismo grupo que
  `canManageCardholders`) — es un resumen ejecutivo pensado para quien
  gestiona la estructura de la empresa.
- **Operador** y **Auditor** no tienen esta pantalla — siguen aterrizando
  en "Clientes", igual que antes de que existiera este panel.
- El alcance de datos sigue la misma regla de herencia jerárquica de
  arriba: Super Admin ve todas las empresas, Admin Cliente ve su empresa
  más sus descendientes.

## Plano de autoservicio (Tarjetahabiente)

Identidad completamente separada de los roles de staff (`cardholder_users`
vs. `users`), y de negocio completamente independiente de la gestión de
saldos que hace el staff — sin Cuentas Concentradoras/Colectoras de por
medio. Ver `docs/business/autoservicio-tarjetahabiente.md` para el
detalle completo; resumen de permisos:

- **Ver** su propio saldo y estado de cuenta (movimientos, con filtros de
  fecha — más "bancario" que el historial que ve el staff): siempre, sin
  restricción.
- **Transferir** (C2C, a la tarjeta de otro Tarjetahabiente del **mismo
  Cliente**): libre, **sin pasar por `approval_rules`** — el
  Tarjetahabiente opera su propio saldo, distinto de cuando un Operador
  solicita una operación en su nombre. Ver
  `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.
- **Congelar/descongelar su propia tarjeta**: sí, pero un bloqueo hecho
  por un Admin Cliente/Super Admin **siempre pesa más** — el
  Tarjetahabiente no puede autodescongelar una tarjeta que el staff
  bloqueó. Ver "Congelar vs. bloquear" en
  `docs/business/autoservicio-tarjetahabiente.md`.
- **Presentar un reclamo** sobre su propio movimiento: sí, mismo
  mecanismo (`MovementClaim`) que ya usa un Operador en su nombre.
- **Onboarding**: fuera de alcance de la versión web — se asume que el
  Tarjetahabiente ya se registró (probablemente desde la app móvil, no
  documentado todavía). La versión web solo cubre login sobre una cuenta
  ya activada.

No implementado todavía: MFA (pendiente para ambos planos de identidad,
staff y Tarjetahabiente, "lo iteraremos" — no bloquea esta definición).
