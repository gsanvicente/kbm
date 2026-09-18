# Autoservicio del Tarjetahabiente

> Referencia viva. Última revisión: 2026-09-17.

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
1. **Ver saldo y estado de cuenta** — más "bancario" que el historial que
   ve el staff: filtros por rango de fechas y resumen del periodo, no
   solo una lista plana. Ver `docs/feature/portal-autoservicio-tarjetahabiente/README.md`.
2. **Transferencias C2C** — a la tarjeta de otro Tarjetahabiente del
   **mismo Cliente**, identificando el destino por su número de tarjeta
   completo. Ver `docs/feature/transferencia-c2c-tarjetahabiente/README.md`
   para el detalle completo (es la pieza más compleja de esta feature,
   tiene su propio documento).
3. **Congelar/descongelar su propia tarjeta** — ver "Congelar vs.
   bloquear" más abajo.
4. **Presentar un reclamo** sobre uno de sus propios movimientos — mismo
   mecanismo (`MovementClaim`) que ya usa un Operador en su nombre, ver
   "Reclamos" más abajo.

## Onboarding (fuera de alcance de la versión web)
El flujo de alta es: (1) el staff (Admin Cliente+) captura al
Tarjetahabiente y le asigna una tarjeta —flujo de CRUD de
Tarjetahabientes, ver "Dependencias" abajo—, (2) el Tarjetahabiente
descarga la app (probablemente móvil, no documentado todavía) y se
registra/activa, validando contra los datos que el staff ya capturó.

**La versión web que se documenta aquí asume que ese registro ya
ocurrió** — solo cubre login sobre una cuenta ya activada, no el flujo de
registro/activación en sí. Si más adelante se decide que la web también
debe soportar activación, es una extensión de alcance, no un cambio de lo
ya diseñado.

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

Esto **no requiere ningún cambio de modelo** — `CardStatus` ya distingue
`blocked` de `frozen` desde que se construyó (`admin/lib/core/models/card_status.dart`),
aunque hasta esta iteración `frozen` nunca se producía desde ningún flujo.
Las pantallas de tarjetas del staff (`payment_card_visual.dart`,
`card_tile.dart`) ya renderizan ambos estados correctamente sin cambios.

## Reclamos
El Tarjetahabiente puede presentar un reclamo sobre un movimiento propio
usando el mismo `LedgerRepository.fileClaim` que ya usa un Operador en su
nombre (ver `docs/business/reclamos-de-movimientos.md`) — el
`requestedByEmail` es simplemente el correo del propio Tarjetahabiente
(`Cardholder.email` ya existe en el modelo). No se identificó
complejidad adicional que justifique dejarlo fuera de esta primera
versión.

## Segundo factor de autenticación (MFA)
Se necesita para **ambos** planos de identidad (staff y Tarjetahabiente),
no solo autoservicio — decisión de negocio explícita. **No se implementa
en esta iteración** ("lo iteraremos" — no bloquea el diseño ni la
implementación del resto de esta feature). Login simple (o biométrico en
el futuro app móvil) sigue siendo lo que hay hoy — ver
`docs/security/data-classification.md`, "Dos planos de identidad, dos
políticas de autenticación".

## Dependencias (orden de construcción)
Antes de implementar código de este portal, se construyen:
1. CRUD de Clientes (crear una empresa desde cero — hoy solo existe
   lectura de la jerarquía).
2. CRUD de Tarjetahabientes (crear uno desde cero — hoy solo existe
   editar/desactivar uno ya sembrado, y asignarle una tarjeta del pool).

Esta documentación se escribe **antes** de esas dependencias a propósito,
para no perder el diseño ya acordado — ver la regla MUST de
documentación en el `README.md` raíz.

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
- Registro/activación de cuenta desde la web: ver "Onboarding" arriba.
- MFA: ver arriba.

## Ver también
- `docs/feature/portal-autoservicio-tarjetahabiente/README.md` — pantallas y flujo.
- `docs/feature/transferencia-c2c-tarjetahabiente/README.md` — la transferencia C2C en detalle.
- `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` — decisión de manejo del PAN.
- `docs/security/threat-model.md` puntos 6, 11 y 12.
