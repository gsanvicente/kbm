# Desactivación de Clientes (gobernabilidad)

> Referencia viva. Última revisión: 2026-09-17.

## Por qué existe esto
Una empresa (Cliente) puede dejar de ser cliente de Koons — fin de
contrato, incumplimiento, disputa legal, lo que sea. Cuando eso pasa,
**no debe poder operar en ningún nivel**: ni su propio staff, ni nadie
más en su nombre. Esto es un control de gobernabilidad, no un borrado de
datos — el historial financiero de una empresa desactivada sigue
existiendo (append-only, ver `docs/business/saldo-y-ledger.md`) y sigue
siendo consultable por quien tenga alcance legítimo.

## Qué significa "inactivo"
Un Cliente tiene `is_active` (ya existe en el esquema,
`backend/migrations/0001_init.sql`). Mientras es `false`:
- Se puede **seguir viendo** (listado, detalle, historial) por cualquiera
  con alcance de lectura sobre él — no es un borrado, es un candado sobre
  las acciones.
- **Ninguna acción operativa** está disponible: operaciones de saldo,
  Tesorería (registrar/conciliar depósitos), gestión de
  tarjetahabientes/tarjetas, reclamos. Sí se puede **editar su
  expediente KYB** (ver `docs/feature/alta-y-gestion-de-clientes/README.md`,
  "Editar un Cliente existente") — administrar el propio registro no es
  lo mismo que operar sobre él.

## Cascada hacia las filiales
Desactivar un Cliente desactiva **también a todos sus descendientes**,
sin excepción — si el negocio con la empresa matriz termina, se asume
que también termina con todo lo que cuelga de ella. Reactivar es
simétrico: reactiva también a todo el subárbol (ver la simplificación
deliberada al respecto en
`docs/feature/alta-y-gestion-de-clientes/README.md`).

## Quién puede desactivar/reactivar a quién
Mismo grupo que puede crear Clientes (`canManageClients`: Admin Cliente +
Super Admin), con una restricción adicional:
- **Admin Cliente**: puede desactivar/reactivar cualquiera de sus
  **descendientes**, pero **nunca su propia empresa** — permitirlo se
  auto-bloquearía a sí mismo (y a todo su propio staff) de un solo clic,
  sin ninguna forma de revertirlo desde dentro de la consola.
- **Super Admin**: puede desactivar/reactivar cualquier Cliente del
  sistema, incluida una empresa raíz completa.
- **Operador y Auditor**: no pueden hacer ninguna de las dos cosas.

## Enforcement: dos capas, no una

### Capa 1 — bloqueo de login (la más importante)
Si el staff de un Cliente inactivo (o de cualquiera de sus ancestros
inactivos) no puede iniciar sesión, estructuralmente no puede hacer nada
en la consola — es el punto de control más simple y más fuerte que hay.
Extiende la regla que ya existe para un usuario individual inactivo
(`docs/feature/login-administrativo/README.md`): ahora el login también
verifica que el Cliente del usuario, y toda su cadena de ancestros, estén
activos.

**Limitación conocida de esta iteración**: esto bloquea el *siguiente*
intento de login, no invalida una sesión ya iniciada antes de la
desactivación — no hay mecanismo de push de servidor a cliente en este
repositorio fake para forzar un logout remoto. Con backend real, esto se
resolvería invalidando el token/sesión activa en el momento de
desactivar.

### Capa 2 — verificación en el repositorio (para quien sigue logueado)
La Capa 1 no cubre a un **ancestro** que ya tenía sesión iniciada antes
de la desactivación (ej. un Super Admin) e intenta operar sobre el
Cliente recién desactivado — su propio login sigue siendo válido, el
problema es la acción, no la sesión. Por eso las acciones que mueven
dinero o cambian estado verifican `is_active` del Cliente involucrado
(y de sus ancestros) antes de ejecutarse, sin importar quién las pida:
- `BalanceOperationRepository.request` / `.approve` (Dispersión,
  Deducción, Transferencia).
- `TreasuryRepository.registerDeposit` / `.reconcileDeposit`.
- Asignar/bloquear una Tarjeta, gestionar un Tarjetahabiente.
- `LedgerRepository.fileClaim` / `.resolveClaim`.
- **Desde ADR-0021 (2026-09-24)**: `SPEIStore.EnsureCLABE` / `.RegisterBeneficiary`
  / `.CreatePayment` (autoservicio del Tarjetahabiente) y
  `.ApprovePayment` / `.RejectPayment` (staff) — un pago SPEI saca dinero
  de verdad hacia un banco externo, así que este chequeo pesa más aquí
  que en la Transferencia C2C (que nunca sale del ecosistema KBM). Ver
  "Autoservicio del Tarjetahabiente" abajo.

Mismo patrón que ya existe para fondos insuficientes: una excepción de
dominio dedicada (`ClientInactiveException` o similar) en vez de dejar
que la operación "simplemente falle" de forma genérica.

## Operaciones pendientes al momento de desactivar
Una operación de saldo en `pending_approval` dentro del alcance de un
Cliente que se desactiva **queda congelada tal cual estaba** — ni se
aprueba, ni se rechaza, ni se cancela automáticamente. La Capa 2 ya lo
garantiza: `approve`/`reject` también verifican `is_active`. Al
reactivar, esas operaciones vuelven a estar disponibles para
aprobar/rechazar normalmente, sin haber perdido ningún dato ni cambiado
de estado mientras tanto.

## Autoservicio del Tarjetahabiente (implementado)
El login del portal de autoservicio
(`docs/business/autoservicio-tarjetahabiente.md`) aplica la misma regla
de la Capa 1: un Tarjetahabiente de un Cliente inactivo (o descendiente
de uno) no puede iniciar sesión, aunque su propio `is_active` siga en
`true` — mismo criterio exacto que `staff_auth.go`'s Login
(`IsOperable` sobre `row.ClientID`), mensaje genérico idéntico a
credenciales incorrectas. Auditado con `reason: "client_inactive"`, igual
que el lado staff.

## Fuera de alcance
- Eliminar un Cliente por completo (ver
  `docs/feature/alta-y-gestion-de-clientes/README.md`).
- Invalidación de sesiones activas (ver "Limitación conocida" arriba).
- Distinguir un descendiente que ya estaba inactivo por su cuenta antes
  de que su ancestro se desactivara — reactivar el ancestro reactiva
  todo el subárbol sin excepción, ver
  `docs/feature/alta-y-gestion-de-clientes/README.md`.
- Notificar (email/push) al staff o a los Tarjetahabientes cuando su
  empresa se desactiva o reactiva.

## Ver también
- `docs/feature/alta-y-gestion-de-clientes/README.md` — flujo de UI.
- `docs/feature/login-administrativo/README.md` — regla de login extendida.
- `docs/security/threat-model.md` punto 13.
