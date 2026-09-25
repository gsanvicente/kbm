# Autoservicio del Tarjetahabiente

> Referencia viva. Última revisión: 2026-09-24 (reportes de staff y descarga de estado de cuenta, ADR-0022).

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
6. **Recibir depósitos SPEI y pagar a terceros** desde su propia Cuenta
   Individual, con su propia CLABE — **implementado** (2026-09-24), ver
   "Pagos a terceros vía SPEI" más abajo.

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

## Pagos a terceros vía SPEI (implementado 2026-09-24)
Desde `docs/adr/0020-cuenta-individual-tarjetahabiente.md` y
`docs/adr/0021-conector-spei.md`: cada Tarjetahabiente tiene una **Cuenta
Individual** propia (no confundir con la Cuenta Concentradora/Colectora
del Cliente, que son de la empresa) con su propia **CLABE**. Desde
`cardholder/` puede:

- **Recibir depósitos SPEI** directo a esa CLABE — se acreditan de
  inmediato (el proveedor SPEI ya confirmó el depósito, no pasa por
  ningún paso de conciliación manual, a diferencia del fondeo que hace la
  empresa vía Colectora, ver `docs/business/tesoreria-cliente.md`).
- **Registrar Beneficiarios de Pago** (CLABE + banco + alias de un
  tercero) y **pagar a terceros** desde el saldo de su propia Cuenta —
  esto **corrige** lo que esta nota decía antes: que las transferencias
  fuera del ecosistema KBM y la recarga con dinero propio quedaban fuera
  de alcance. Ya no. Al capturar la CLABE, ve una vista previa del banco
  detectado (calculada en el cliente, sin esperar al servidor) para
  confirmar que la capturó bien antes de guardar — ver
  `docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md`.
- Un pago por encima de un monto configurable por Cliente
  (`approval_rules`, mismo mecanismo que ya usan Dispersión/Deducción)
  requiere aprobación del staff; por debajo del umbral se ejecuta directo
  — mismo criterio de "sin regla configurada, requiere aprobación por
  defecto" que ya rige el resto del sistema.
- Recibe un comprobante propio de KBM, no el CEP oficial de Banxico —
  decisión de alcance explícita, ver la ADR. Se genera tanto para un
  pago saliente como para un depósito entrante (`GET
  .../spei-deposits`), cada uno con su propio folio y referencia del
  proveedor.
- Puede ver el **saldo de su Cuenta** aunque no tenga ninguna tarjeta
  asignada todavía (`GET .../account/ledger`) — antes de esta
  corrección, ese caso (el que justamente motivó "la Cuenta nace al
  alta", punto 3 de ADR-0020) no tenía ninguna pantalla ni endpoint que
  lo mostrara.
- Puede **descargar** (PDF con branding de KBM/Koons) el estado de
  cuenta de su propia Cuenta Individual — ver
  `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`, punto 6,
  y `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` (formato).

Ver `docs/adr/0021-conector-spei.md`, sección "Seguridad", para los
candados de validación de CLABE/beneficiario ya construidos, y para el
riesgo regulatorio (PLD/OFAC) marcado como pendiente de validar con
compliance, no resuelto en este ADR.

### Corrección de visibilidad para staff (ADR-0022, 2026-09-24)
Todo lo de arriba sigue siendo 100% self-service del Tarjetahabiente en
cuanto a **quién lo hace** — nadie de staff registra un Beneficiario ni
inicia un pago en su nombre, eso no cambió. Lo que sí cambió es la
**lectura**: staff con alcance sobre este Tarjetahabiente ahora puede
*ver* su CLABE, sus Beneficiarios, su historial de pagos/depósitos y el
saldo de su Cuenta (antes, cualquier intento de staff devolvía un 404
explícito, sin distinguir "no existe" de "no tienes permiso"). Motivo:
soporte y cumplimiento (PLD/AML) — ver
`docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` y
`docs/feature/reportes-admin/README.md`.

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

## Login y Tarjetahabiente/Cliente inactivo (implementado)
El login de este portal aplica la misma regla de Capa 1 que ya se
documentó para el staff: un Tarjetahabiente con `is_active = false` no
puede iniciar sesión — mismo mensaje genérico que una contraseña
incorrecta, nunca distingue el motivo. Ver
`docs/business/desactivacion-de-tarjetahabientes.md`, "Enforcement".
Desde ADR-0021 (2026-09-24) esto también verifica el `is_active` del
**Cliente** del Tarjetahabiente (y sus ancestros) — antes solo se
verificaba el propio; ver
`docs/business/desactivacion-de-clientes.md`, "Autoservicio del
Tarjetahabiente".

## Fuera de alcance
- ~~Recargar la tarjeta con dinero propio~~ — **implementado desde
  2026-09-24**: un depósito SPEI a la CLABE de la Cuenta Individual es
  justo eso. Ver "Pagos a terceros vía SPEI" más abajo y
  `docs/adr/0021-conector-spei.md`.
- ~~Transferencias hacia fuera del ecosistema KBM~~ — **implementado
  desde 2026-09-24**, ver el mismo punto de arriba. Corrección explícita:
  esta nota decía que requeriría integración bancaria real y quedaba
  fuera de alcance; la integración (SPEI) ya se diseñó.
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
- Verificación PLD/OFAC real de un Beneficiario de Pago, y CEP oficial de
  Banxico: requieren un proveedor SPEI elegido — ver
  `docs/adr/0021-conector-spei.md`.
- Transferencias entre Cuentas Individuales propias del mismo
  Tarjetahabiente (si llegara a tener más de una): no diseñado, ver esa
  misma ADR, "Fuera de alcance".

## Ver también
- `docs/feature/portal-autoservicio-tarjetahabiente/README.md` — pantallas y flujo.
- `docs/feature/transferencia-c2c-tarjetahabiente/README.md` — la transferencia C2C en detalle.
- `docs/feature/activacion-de-tarjetahabiente/README.md` — la activación de cuenta en detalle.
- `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` — decisión de manejo del PAN.
- `docs/adr/0019-cardholder-self-activation.md` — decisión de diseño de la activación de cuenta.
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — la Cuenta Individual detrás de todo esto.
- `docs/adr/0021-conector-spei.md` — depósitos y pagos a terceros vía SPEI, en detalle.
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — corrección de visibilidad para staff y descarga de estado de cuenta.
- `docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md` — formato PDF de esa descarga.
- `docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md` — vista previa de banco y corrección del refresco al agregar un Beneficiario.
- `docs/security/threat-model.md` puntos 6, 11, 12, 16, 17 y 18.
