# Autoservicio del Tarjetahabiente

> Referencia viva. Última revisión: 2026-09-21 (activación de cuenta).

## Qué es
El plano de identidad y funcionalidad que le permite a un Tarjetahabiente
—no al staff— ver y operar **sus propias** cuentas, directamente,
sin intervención de un Operador/Admin Cliente. La analogía correcta es
"la versión web de un portal bancario", no una extensión de la consola
administrativa.

## Completamente independiente de la gestión de saldos del staff
Esto es una decisión de diseño explícita, no un detalle de
implementación: el autoservicio **no** usa Cuentas Concentradoras ni
Colectoras (`docs/business/tesoreria-cliente.md`) — esos conceptos
existen para que una **empresa** fondee las tarjetas de sus
Tarjetahabientes; el autoservicio es sobre el propio dinero que el
Tarjetahabiente ya tiene en su tarjeta, moviéndose entre tarjetahabientes.
Tampoco pasa por `docs/business/approval-policy.md` — el Tarjetahabiente
opera su propio saldo, no está pidiéndole a nadie más que autorice mover
dinero de la empresa.

## Alcance MVP
1. **Ver saldo y estado de cuenta** — **implementado**, más "bancario"
   que el historial que ve el staff: filtros por rango de fechas y
   resumen del periodo, no solo una lista plana. Ver
   `docs/feature/portal-autoservicio-tarjetahabiente/README.md`.
2. **Transferencias C2C** — a la tarjeta de otro Tarjetahabiente del
   **mismo Cliente**, identificando el destino por su número de tarjeta
   completo. Ver `docs/feature/transferencia-c2c-tarjetahabiente/README.md`
   para el detalle completo (es la pieza más compleja de esta feature,
   tiene su propio documento).
3. **Congelar/descongelar su propia tarjeta** — **implementado**
   (2026-09-19), ver "Congelar vs. bloquear" más abajo.
4. **Presentar un reclamo** sobre uno de sus propios movimientos —
   **implementado** (2026-09-21), ver "Reclamos" más abajo.
5. **Activar su cuenta** la primera vez, sin depender de que el staff le
   comparta nada — **implementado** (2026-09-21), ver "Onboarding" más
   abajo.

## Onboarding — activación de cuenta (implementado 2026-09-21)
El flujo de alta es: (1) el staff (Admin Cliente+) captura al
Tarjetahabiente y le asigna una tarjeta —flujo de CRUD de
Tarjetahabientes, ver "Dependencias" abajo—, (2) el Tarjetahabiente entra
a `cardholder/` (web o mobile, es la misma app, ver ADR-0002) y activa su
cuenta él mismo, sin ninguna acción nueva del staff — ver
`docs/feature/activacion-de-tarjetahabiente/README.md` y
`docs/adr/0019-cardholder-self-activation.md` para el diseño completo.

Sin infraestructura de correo/SMS en el proyecto (mismo hueco que ya
existía para staff, ver `docs/business/gestion-de-usuarios-staff.md`), la
activación no depende de ningún canal de entrega: el Tarjetahabiente
prueba quién es con dos datos que el staff ya capturó al darlo de alta
(email + número de identificación oficial) y elige ahí mismo su propia
contraseña — a diferencia del staff, donde es el admin quien la escribe.

**Corrección de alcance sobre lo que decía originalmente esta nota**: se
asumía que la activación sería "probablemente móvil" y que la web se
quedaría fuera de alcance. Se descartó esa restricción — es literalmente
el mismo código Flutter (ADR-0002), y no había ninguna razón de negocio
para impedir activar desde una computadora.

## Congelar vs. bloquear una tarjeta
Dos acciones sobre el mismo campo `card_status`, con dueños y peso
distintos:

| Acción | Quién | Resultado | Quién puede revertirla |
|---|---|---|---|
| Congelar | Tarjetahabiente (autoservicio) | `active → frozen` | El propio Tarjetahabiente, o el staff |
| Bloquear | Admin Cliente / Super Admin (consola) | `active`/`frozen` → `blocked` | Solo el staff |

**Regla de gobernabilidad**: un bloqueo del staff **siempre pesa más** —
si una tarjeta está `blocked`, el Tarjetahabiente no tiene ninguna acción
de autoservicio disponible sobre ella (ni para "descongelar", porque
nunca estuvo en ese estado desde su perspectiva — está bloqueada por el
administrador). Solo el staff puede regresarla a `active` desde
`blocked`. En cambio, si el Tarjetahabiente la congeló él mismo
(`frozen`), tanto él como el staff pueden regresarla a `active`.

**Etiqueta visible**: `frozen` se muestra como **"Bloqueo temporal"**,
nunca "Congelada" — a propósito distinto de "Bloqueada" (`blocked`), para
que sea obvio a simple vista quién originó el estado. Misma etiqueta en
ambas apps (`admin/lib/core/models/card_status.dart` y
`cardholder/lib/core/models/card_status.dart`).

**Implementado** (2026-09-19): `SetFrozen` en el backend Go compartido
(`POST /v1/cards/{cardId}/self-freeze`, ver ADR-0010) — nunca acepta
`cardholderId` de otro dueño, y solo permite `active→frozen` o
`frozen→active`, nunca tocar `blocked`. `CardStatus` ya distinguía
`blocked` de `frozen` desde que se construyó, pero `frozen` nunca se
producía desde ningún flujo hasta ahora. Al implementarlo se encontró un
bug real en `admin/`: `CardDetailView._canToggleBlock` solo consideraba
`active`/`blocked`, así que el botón "Bloquear" del staff **no aparecía
en absoluto** sobre una tarjeta `frozen` — corregido para incluir
`frozen`, ya que el bloqueo de staff debe poder aplicarse ahí también.

## Reclamos (implementado 2026-09-21)
El Tarjetahabiente puede presentar un reclamo sobre un movimiento propio,
únicamente el suyo — ver `docs/business/reclamos-de-movimientos.md`. A
diferencia de lo que se asumía originalmente en esta nota, esto **no**
pudo reutilizar el mismo `FileClaim` que usa un Operador tal cual:
`movement_claims.requested_by` era una FK obligatoria hacia `users`
(staff) — un Tarjetahabiente no tiene fila ahí. Requirió un cambio de
schema real (`requested_by` opcional + columna paralela
`requested_by_cardholder_id` hacia `cardholders`, exactamente una de las
dos siempre llena) — ver `docs/adr/0018-cardholder-filed-claims.md`.
Nunca puede resolver su propio reclamo, solo presentarlo y ver su
estado.

## Segundo factor de autenticación (MFA)
Se necesita para **ambos** planos de identidad (staff y Tarjetahabiente),
no solo autoservicio — decisión de negocio explícita. **No se implementa
en esta iteración** ("lo iteraremos" — no bloquea el diseño ni la
implementación del resto de esta feature). Login simple (o biométrico en
el futuro app móvil) sigue siendo lo que hay hoy — ver
`docs/security/data-classification.md`, "Dos planos de identidad, dos
políticas de autenticación".

## Dependencias (orden de construcción)
Antes de implementar código de este portal, se construyeron:
1. CRUD de Clientes — **implementado**, ver
   `docs/feature/alta-y-gestion-de-clientes/`.
2. CRUD de Tarjetahabientes — **implementado**, ver
   `docs/feature/alta-y-gestion-de-tarjetahabientes/`.

Con ambas dependencias resueltas, se implementó el mínimo de este portal
necesario para la Transferencia C2C, luego (2026-09-19) congelar/
descongelar la propia tarjeta, y luego (2026-09-21) el filtro de
fechas/resumen de periodo en Movimientos y presentar un reclamo — ver
"Estado" en `docs/feature/portal-autoservicio-tarjetahabiente/README.md`.

## Login y Tarjetahabiente inactivo (implementado)
El login de este portal aplica la misma regla de Capa 1 que ya se
documentó para el staff: un Tarjetahabiente con `is_active = false` no
puede iniciar sesión — mismo mensaje genérico que una contraseña
incorrecta, nunca distingue el motivo. Ver
`docs/business/desactivacion-de-tarjetahabientes.md`, "Enforcement".

## Fuera de alcance
- Recargar la tarjeta con dinero propio (ej. desde una cuenta bancaria
  externa del Tarjetahabiente): no existe ningún concepto de "recarga"
  en esta versión — todo el saldo proviene de cómo la empresa fondeó la
  tarjeta originalmente (Dispersión desde la Concentradora, ver
  `docs/business/tesoreria-cliente.md`), el autoservicio solo mueve ese
  saldo entre tarjetahabientes.
- Transferencias hacia fuera del ecosistema KBM (a una cuenta bancaria
  externa): fuera de alcance, requeriría integración bancaria real.
- Transferencias entre Tarjetahabientes de **distintos** Clientes:
  decisión de negocio explícita, ver
  `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.
- MFA: ver arriba.
- Reenvío/recuperación si el Tarjetahabiente olvida su contraseña ya
  activada: "restablecer contraseña" sigue sin existir para ningún plano
  de identidad (ver `docs/business/gestion-de-usuarios-staff.md`) — hoy
  solo se resuelve el caso de "nunca la ha puesto".
- Notificar automáticamente al Tarjetahabiente que ya puede activar su
  cuenta (correo/SMS): no hay infraestructura de mensajería en el
  proyecto — ver `docs/adr/0019-cardholder-self-activation.md`.

## Ver también
- `docs/feature/portal-autoservicio-tarjetahabiente/README.md` — pantallas y flujo.
- `docs/feature/transferencia-c2c-tarjetahabiente/README.md` — la transferencia C2C en detalle.
- `docs/feature/activacion-de-tarjetahabiente/README.md` — la activación de cuenta en detalle.
- `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` — decisión de manejo del PAN.
- `docs/adr/0019-cardholder-self-activation.md` — decisión de diseño de la activación de cuenta.
- `docs/security/threat-model.md` puntos 6, 11, 12 y 16.
