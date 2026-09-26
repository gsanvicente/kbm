# ADR-0021: Conector SPEI — cuenta CLABE, depósitos y pagos a terceros

- Estado: Aceptada — **corregida parcialmente por
  `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`**: el
  punto 3 de "Nueva entidad Beneficiario de Pago" ya no implica que
  staff nunca pueda verlo (ver ese ADR); todo lo demás de esta decisión
  sigue vigente sin cambio.
- Fecha: 2026-09-24

## Contexto
Se recibió un documento de referencia de negocio ("Referencia App Móvil
Plataforma Bancaria") describiendo una app bancaria con cuenta CLABE,
depósitos, transferencias entre cuentas, pagos a terceros con registro de
beneficiarios y reportes — este ADR cubre **únicamente la parte de SPEI**
de ese documento (cuenta CLABE, depósitos entrantes, beneficiarios, pagos
a terceros); el resto (pago de servicios, recarga de tiempo aire, tarjetas
corporativas) queda fuera de alcance de esta decisión.

KBM ya tiene un precedente arquitectónico exacto para "conectar con un
proveedor externo sin haberlo elegido todavía":
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
(el `CardProcessorGateway`). Este ADR aplica el mismo molde a SPEI, sobre
la Cuenta Individual que introduce
`docs/adr/0020-cuenta-individual-tarjetahabiente.md` (prerrequisito
directo — SPEI no puede dirigirse a una tarjeta, solo a una CLABE).

## Decisión

### Arquitectura (mismo molde que ADR-0011)
1. **Puerto nuevo `SPEIGateway`** en `internal/application/ports` — nunca
   un SDK de un proveedor específico embebido en un caso de uso, misma
   aplicación de la arquitectura hexagonal (ADR-0001). Dos direcciones:
   - **Saliente (pago a un beneficiario)**: asíncrona, vía el patrón
     outbox/queue/worker ya escaffoldeado (`outbox_events`,
     `internal/adapters/outbox`, `internal/adapters/queue/{local,sqs}`,
     `cmd/worker` — hoy solo placeholders, sin código real). Reutiliza
     `operation_status.approved`, reservado desde
     `docs/business/approval-policy.md` justo para "aprobar ahora,
     ejecutar después vía un worker" — coincide exacto con lo que un pago
     SPEI necesita (aprobado internamente → despachado al proveedor →
     `executed` cuando el proveedor confirma, o `failed`).
   - **Entrante (depósito SPEI)**: adaptador nuevo sin precedente en el
     scaffold actual (nunca existió "alguien externo nos llama"), mismo
     criterio que "Compra" en ADR-0011 — endpoint HTTP dedicado,
     autenticado según el proveedor, **idempotente por ID de transacción
     del proveedor** (columna nueva con restricción de unicidad).
2. **Sin proveedor real elegido todavía**: `internal/adapters/spei/`
   (carpeta reservada, adaptador simulador) cumple el mismo puerto — mismo
   criterio exacto que `internal/adapters/processor/`. El puerto queda
   listo para "montar" un proveedor real (STP, Banorte, Arcus, etc.)
   después, sin rediseño.
3. **Nueva entidad "Beneficiario de Pago"** (CLABE + banco + alias +
   dueño = Tarjetahabiente) — nombre elegido deliberadamente distinto de
   `BENEFICIARIO_CONTROLADOR` (el dueño mayoritario de un Cliente para
   KYB, `docs/business/domain-model.md`), que es un concepto de persona
   completamente distinto y no debe confundirse con este.
4. **Nueva tabla para pagos SPEI salientes**, no reutiliza
   `balance_operations` — mismo criterio que "Compra" en ADR-0011: es un
   tipo de movimiento con reglas propias, no una operación que el staff
   inicia sobre una tarjeta.

### Reglas de negocio
5. **Quién origina un pago**: el propio Tarjetahabiente, desde su portal
   de autoservicio (`cardholder/`) — esto **corrige**
   `docs/business/autoservicio-tarjetahabiente.md`, que hoy dice
   "Transferencias hacia fuera del ecosistema KBM: fuera de alcance". Un
   pago SPEI a un tercero es justo eso, y deja de estarlo.
6. **De dónde sale el dinero**: el saldo de la **Cuenta Individual**
   propia del Tarjetahabiente (ADR-0020) — nunca la Concentradora del
   Cliente. A diferencia de Dispersión (que sí debita la Concentradora),
   un pago a tercero es dinero que ya era del Tarjetahabiente.
7. **Aprobación con umbral configurable por Cliente**: un pago SPEI a
   tercero usa el mismo mecanismo de `approval_rules` que ya existe para
   Dispersión/Deducción/Transferencia — `min_amount` configurable por
   Cliente; por debajo del umbral se ejecuta directo, por encima queda
   `pending_approval`. Mismo default fail-safe que ya rige todo el
   sistema (`docs/business/approval-policy.md`): sin regla configurada
   para ese Cliente, requiere aprobación siempre, nunca se asume
   "libre" por omisión.
8. **Depósito SPEI entrante concilia automáticamente** — a diferencia del
   depósito declarado manualmente en la Colectora
   (`docs/business/tesoreria-cliente.md`, que sí exige el paso humano de
   "conciliar"), un depósito SPEI ya viene confirmado por el banco del
   proveedor: no pasa por un segundo control humano, acredita la Cuenta
   Individual de inmediato. Este es un camino de fondeo **paralelo** al
   de Concentradora/Colectora, no lo reemplaza — una Cuenta puede recibir
   dinero por ambos caminos (ver ADR-0020, punto 8, sobre no distinguir
   el origen del saldo).
9. **Comprobante propio, no CEP oficial de Banxico** — decisión de
   alcance explícita tomada del documento de referencia: se genera un
   comprobante interno de KBM, no se integra la consulta oficial de
   Banxico en esta fase.

### Seguridad — candados implementables ya, sin depender de ningún proveedor
No hay compliance real posible sin elegir un proveedor SPEI (ver
"Fuera de alcance"), pero estos controles no dependen de eso y se
construyen desde ahora:
- **Validación de CLABE por dígito verificador** (algoritmo público,
  módulo 10 con pesos 3-7-1) — rechaza CLABEs mal formadas antes de
  intentar nada.
- **Catálogo de bancos por código** (los primeros 3 dígitos de la CLABE)
  — detecta bancos inexistentes o typos.
- **Confirmación explícita antes de pagar** (nombre + banco del
  beneficiario, enmascarado) — mismo patrón que ya usa la Transferencia
  C2C (`docs/feature/transferencia-c2c-tarjetahabiente/README.md`).
- **Bloqueo tras intentos fallidos** al registrar un beneficiario —
  mismo mecanismo que ya existe para la resolución de destino C2C.
- **Periodo de enfriamiento para beneficiarios nuevos**: un beneficiario
  recién agregado no puede recibir montos grandes de inmediato — mitiga
  que una cuenta comprometida vacíe el saldo al instante de agregar un
  destino nuevo.
- **Nunca la propia CLABE como beneficiario.**
- **Trazabilidad completa en `audit_log`** — alta de beneficiario y cada
  pago, mismo criterio que el resto del proyecto.

## Consecuencias
- **Depende de `docs/adr/0020-cuenta-individual-tarjetahabiente.md`** —
  no se construye antes de esa entidad.
- Documentos que este ADR corrige o extiende:
  `docs/business/autoservicio-tarjetahabiente.md` (corrige "fuera de
  alcance"), `docs/business/tesoreria-cliente.md` (segundo camino de
  fondeo), `docs/security/threat-model.md` (punto nuevo).
- **Riesgo regulatorio marcado, no resuelto aquí**: verificación real
  contra listas de PLD/OFAC/SAT requiere un proveedor externo — ninguno
  de los candados de la sección "Seguridad" la sustituye. Validar con
  quien lleve el tema legal/compliance en Koons antes de mover dinero
  real; no es una decisión técnica.
- El trabajo de integración real (adaptador concreto, contrato exacto,
  autenticación del webhook) queda bloqueado hasta elegir proveedor —
  mientras tanto, todo se construye y prueba contra el simulador, mismo
  criterio que ADR-0011.

## Notas de implementación (2026-09-24)
Detalles resueltos durante la implementación, no decisiones de
arquitectura — se documentan aquí para que quien los revise después no
tenga que leer el código para saber que existen:
- **Periodo de enfriamiento**: 24 horas desde el alta del Beneficiario;
  mientras dura, ningún pago individual puede superar $1,000 MXN
  (`beneficiary.CoolingPeriodMaxAmount`). Valor ilustrativo de esta
  iteración, ajustable en código sin migración — no es un monto acordado
  con el negocio.
- **Catálogo de bancos** (`internal/domain/clabe`): lista ilustrativa de
  instituciones mexicanas comunes por los primeros 3 dígitos de la
  CLABE, no el catálogo oficial completo de Banxico. Suficiente para
  rechazar typos y códigos inventados; se reemplaza por el catálogo real
  del proveedor elegido.
- **Autenticación del webhook de depósito** (placeholder, mientras no
  hay proveedor real): secreto compartido en el header
  `X-SPEI-Webhook-Secret` (`SPEI_WEBHOOK_SECRET`), comparado en tiempo
  constante. Un proveedor real traería su propio esquema de firma —
  reemplaza esto, no lo complementa.
- **Reverso automático**: si el proveedor rechaza un pago ya debitado de
  la Cuenta (`SPEIGateway.DispatchPayment` devuelve error), se revierte
  con un crédito compensatorio inmediato antes de marcar el pago
  `failed` — nunca deja al Tarjetahabiente con el monto descontado sin
  un pago real en curso. No estaba explícito en la sección "Decisión"
  original; es la misma disciplina de "nunca a medias" que ya rige
  Dispersión/Deducción/Transferencia (`docs/business/saldo-y-ledger.md`).
- **Saldo de la Cuenta sin depender de una tarjeta** (`GET
  /v1/cardholders/{id}/account/ledger`): la validación posterior a la
  primera implementación encontró que un Tarjetahabiente sin ninguna
  tarjeta asignada —el caso exacto que ADR-0020 punto 3 habilita— no
  tenía forma de ver su saldo ni sus depósitos en ningún lado. Este
  endpoint (self-only, mismo criterio que el resto de SPEI) resuelve la
  Cuenta por `cardholderId` en vez de por tarjeta.
- **Comprobante propio, implementado** (no solo decidido): `GET
  /v1/cardholders/{id}/spei-deposits` lista los depósitos con su
  `providerReference` propio, y cada pago SPEI ya trae todo lo necesario
  para un comprobante (folio, beneficiario, monto, estatus, referencia
  del proveedor). `cardholder/` renderiza ambos en un diálogo de
  comprobante — ver punto 9 de "Reglas de negocio".
- **Capa 2 de `docs/business/desactivacion-de-clientes.md` extendida al
  Tarjetahabiente**: la primera implementación solo agregó el chequeo de
  Cliente activo (`IsOperable`) en `ApprovePayment`/`RejectPayment`
  (staff) — la validación posterior encontró que el login de
  Tarjetahabiente nunca verificaba el `is_active` de su Cliente (solo el
  propio), y que `EnsureCLABE`/`RegisterBeneficiary`/`CreatePayment`
  tampoco lo hacían. Corregido: mismo patrón que `staff_auth.go` en
  ambos lados.

## Fuera de alcance de esta iteración
- **Verificación PLD/OFAC/SAT real** de un beneficiario — requiere
  proveedor externo, ver "Seguridad" y "Consecuencias".
- **CEP oficial de Banxico** — decisión de alcance explícita (punto 9).
- **Pago de servicios y recarga de tiempo aire** (parte del documento de
  referencia, no de SPEI) — fuera de alcance de este ADR.
- **Transferencias entre Cuentas Individuales del mismo Tarjetahabiente**
  (si llegara a tener más de una Cuenta) — el documento de referencia las
  menciona ("transferencias entre cuentas"), pero es un concepto distinto
  de "pago a tercero" y no se diseña aquí.
- **Elegir el proveedor SPEI real**: fuera de alcance de un ADR de
  arquitectura — se construye y prueba contra el simulador hasta que el
  negocio elija uno.

## Alternativas consideradas
- **Reusar el flujo de Colectora (conciliación manual) para depósitos
  SPEI**: descartado — decisión de negocio explícita (punto 8): un
  depósito ya confirmado por el banco del proveedor no necesita un
  segundo control humano.
- **Pagos a terceros libres, sin aprobación, como la Transferencia
  C2C**: descartado — el negocio pidió un umbral configurable, no
  libertad total, dado que es dinero saliendo de verdad del ecosistema.
- **Construir directo contra un proveedor real (ej. STP) desde ahora**:
  descartado — no hay proveedor elegido; mismo razonamiento que
  ADR-0011, "Alternativas consideradas".

## Ver también
- `docs/adr/0020-cuenta-individual-tarjetahabiente.md` — prerrequisito.
- `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
  — el mismo molde de conector aplicado aquí.
- `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md` — corrige
  la privacidad total de Beneficiarios decidida aquí, agrega reportes de
  staff y descarga de estado de cuenta.
- `docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md`
  — reutiliza en Dart el catálogo de bancos y el algoritmo de CLABE
  definidos aquí, para una vista previa client-side antes de guardar.
- `docs/adr/0027-validacion-de-saldo-y-estatus-de-pago-spei.md` —
  corrige "Enviar dinero": valida saldo antes de enviar y arregla el
  estatus/refresco tras enviarlo.
- `docs/business/autoservicio-tarjetahabiente.md`
- `docs/business/tesoreria-cliente.md`
- `docs/security/threat-model.md`
