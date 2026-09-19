# Desactivación de Tarjetahabientes (gobernabilidad)

> Referencia viva. Última revisión: 2026-09-18.

## Por qué existe esto
Un Tarjetahabiente (persona física) puede dejar de estar asociado a un
Cliente — deja de trabajar ahí, termina una relación comercial, etc.
Cuando eso pasa, sus tarjetas no deben poder seguir usándose. A diferencia
de desactivar un **Cliente** (que es un control reversible pensado para
suspender temporalmente a toda una empresa mientras se resuelve algo),
desactivar un **Tarjetahabiente** es, en la práctica, un evento de "baja"
casi siempre permanente — de ahí que el diseño sea deliberadamente más
estricto: congela sus tarjetas de forma duradera y no permite corregir su
expediente mientras está inactivo.

## Qué significa "inactivo"
Un Tarjetahabiente tiene `is_active`. Mientras es `false`:
- Se puede **seguir viendo** (listado, detalle) por cualquiera con
  alcance de lectura sobre él — no es un borrado.
- **No se puede editar su expediente** — a diferencia de Cliente (que sí
  permite editar el KYB mientras está inactivo), aquí la decisión de
  negocio es la contraria: ningún campo se modifica una vez desactivado,
  para preservar el registro tal cual estaba de cara a una posible
  auditoría. El botón "Editar" ni siquiera aparece, y el repositorio
  también lo rechaza si se intentara sin pasar por la UI.
- **No se le puede asignar ninguna tarjeta nueva.**
- **Ninguna de sus tarjetas puede desbloquearse**, sin importar el motivo
  por el que estén bloqueadas (ver "Congelamiento de tarjetas" abajo).

## Congelamiento de tarjetas al desactivar
Al desactivar a un Tarjetahabiente, **todas sus tarjetas que no estuvieran
ya bloqueadas** pasan de inmediato a `blocked` con
`blocked_reason = cardholder_inactive` (ver
`docs/business/tarjetas-y-asignacion.md`, sección "Motivo de bloqueo").
Una tarjeta que ya estaba `blocked` por otra razón (ej. `manual`, bloqueada
antes por el staff por robo/fraude) **conserva su motivo original** — no
se sobrescribe. Esto es justo lo que permite distinguir, más adelante,
por qué está bloqueada cada tarjeta.

No se reutiliza el estado `frozen` (reservado para el autoservicio del
propio Tarjetahabiente, ver `docs/business/autoservicio-tarjetahabiente.md`,
"Congelar vs. bloquear una tarjeta") — este es un bloqueo del staff, mismo
estado `blocked` que produce la acción manual de
`docs/feature/bloqueo-de-tarjeta/`, solo que automatizado y con un motivo
distinto.

## Asimetría deliberada con la cascada de Cliente
La cascada de Cliente (`docs/business/desactivacion-de-clientes.md`) es
**simétrica**: reactivar deshace exactamente lo que la desactivación
cascadeó. Aquí, **no**:

- **Desactivar**: bloquea automáticamente las tarjetas sin bloqueo previo.
- **Reactivar**: solo permite que el Tarjetahabiente vuelva a recibir
  tarjetas nuevas, y habilita que un admin **pueda** desbloquear sus
  tarjetas bloqueadas — pero no las desbloquea por sí sola. Cada tarjeta
  requiere una acción manual y deliberada, una por una.

La razón de negocio: un bloqueo automático por baja del Tarjetahabiente no
debe poder revertirse "sin querer" con un solo clic al reactivar — reactivar
a alguien (ej. porque se dio de baja por error, o porque regresó a
trabajar) no debería, como efecto secundario invisible, dejar operables de
nuevo tarjetas que un admin quizás quiere revisar una por una antes de
reactivar.

## Quién puede desactivar/reactivar a quién
Mismo grupo que puede crear/editar Tarjetahabientes
(`canManageCardholders`: Admin Cliente + Super Admin, dentro de su propio
alcance de Clientes). Operador y Auditor no pueden.

## Enforcement: dos capas, no una
Mismo patrón que Cliente (ver
`docs/business/desactivacion-de-clientes.md`, "Enforcement"):

### Capa 1 — bloqueo de login (autoservicio futuro)
El portal de autoservicio del Tarjetahabiente
(`docs/business/autoservicio-tarjetahabiente.md`) todavía no existe, pero
cuando se construya, su login debe verificar `is_active` del
Tarjetahabiente, igual que ya se documentó para Cliente.

### Capa 2 — verificación en el repositorio
`CardholderRepository.isOperable(cardholderId)` (equivalente a
`ClientRepository.isOperable`, pero sin cadena de ancestros — un
Tarjetahabiente no tiene descendientes) es la fuente de verdad, verificada
en:
- `CardRepository.assign` — no se puede asignar una tarjeta a un
  Tarjetahabiente inactivo.
- `CardRepository.setBlocked` (solo al **desbloquear**, `blocked: false`)
  — no se puede desbloquear ninguna tarjeta de un Tarjetahabiente
  inactivo, sin importar el motivo de su bloqueo. Bloquear (`blocked:
  true`) no necesita este chequeo — no hay ningún escenario en el que
  bloquear más una tarjeta de alguien inactivo sea un problema.
- `CardholderRepository.update` — no se puede editar el expediente de un
  Tarjetahabiente inactivo.

Nótese que esto es **independiente** del chequeo de `ClientRepository.isOperable`
que ya existe en esas mismas acciones — un Tarjetahabiente puede estar
inactivo mientras su Cliente sigue perfectamente activo, y viceversa.
Ambos chequeos aplican, sin relación entre sí.

## Fuera de alcance
- Eliminar un Tarjetahabiente por completo: no solicitado, y un borrado
  real perdería historial financiero (append-only, ver
  `docs/business/saldo-y-ledger.md`).
- Desbloquear en lote todas las tarjetas de un Tarjetahabiente reactivado:
  ver "Asimetría deliberada" arriba — cada una se desbloquea por separado.
- Notificar (email/push) al Tarjetahabiente cuando se le desactiva o
  reactiva.
- Invalidación de sesiones de autoservicio ya iniciadas: mismo alcance que
  Cliente, ver `docs/business/desactivacion-de-clientes.md`.

## Ver también
- `docs/feature/alta-y-gestion-de-tarjetahabientes/README.md` — flujo de UI.
- `docs/business/tarjetas-y-asignacion.md` — motivo de bloqueo, ciclo de vida de la tarjeta.
- `docs/business/desactivacion-de-clientes.md` — el patrón equivalente para Cliente, y en qué difiere.
- `docs/security/threat-model.md` punto 14.
