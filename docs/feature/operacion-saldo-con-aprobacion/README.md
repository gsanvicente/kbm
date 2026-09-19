# Operación de saldo con aprobación configurable

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1, 2, 4 y 9
- Roles/actores involucrados: Operador (solicita), Admin Cliente/Super Admin (solicitan y aprueban/rechazan), Auditor (solo ve)

## Objetivo
Permitir que un Operador de Saldos (o un Admin Cliente/Super Admin)
solicite una Dispersión, Deducción o Transferencia de saldo sobre una
tarjeta específica, respetando las reglas de aprobación configuradas por
el Cliente dueño de esa tarjeta.

## Quién puede solicitar
**Operador, Admin Cliente y Super Admin** — solo Auditor no puede. Es
justamente el enfoque del rol "Operador de Saldos": operar el saldo del
día a día de las tarjetas de su Cliente (ver
`docs/business/roles-and-permissions.md`). El control real de negocio no
está en restringir quién solicita, sino en el *umbral de monto*
(`approval_rules.min_amount`) que determina si esa solicitud necesita
aprobación de un Admin Cliente/Super Admin antes de ejecutarse.

> **Nota histórica (2026-09-19):** este permiso se restringió por error a
> solo Admin Cliente/Super Admin, contradiciendo la tabla de roles ya
> documentada. Se revirtió el mismo día — ver la regla MUST en el
> `README.md` raíz sobre preguntar ante conflictos con lo ya documentado.

## Nomenclatura (revisado 2026-09-19)
Los nombres visibles para el usuario son **Dispersión**, **Deducción** y
**Transferencia** — no "Carga"/"Débito" (términos anteriores, ya
descartados por confusos para el usuario final). El identificador técnico
en el esquema (`operation_type`: `load`, `debit`, `transfer`) no cambia,
para no romper compatibilidad con lo ya migrado — es un detalle interno,
nunca visible en la UI.

## Contexto / motivación
Ver `docs/business/approval-policy.md` para el modelo completo. Esta
feature es el primer caso de uso "de escritura" real del sistema.
Depende de `docs/feature/tesoreria-cliente/` para la Cuenta Concentradora
que ahora respalda cada Dispersión/Deducción (ver "Flujo principal" más
abajo) — sin esa cuenta fondeada, una Dispersión no tiene de dónde
salir.

## Dónde vive esto en la UI (revisado 2026-09-19)
**Ya no hay un formulario global que primero te hace elegir una tarjeta
origen.** Cada tarjeta ya tiene una pantalla propia
(`docs/feature/tarjetas-de-tarjetahabiente/`) — igual que Movimientos, las
operaciones de saldo se solicitan **desde ahí**, en una tercera pestaña
"Operaciones":
- Muestra el historial de operaciones de saldo de **esa tarjeta**
  (cualquier estado), con el mismo componente visual que la lista global.
- Tres botones (visibles solo si el rol puede solicitar — ver
  `docs/business/roles-and-permissions.md`): **Dispersión**, **Deducción**,
  **Transferencia**. La tarjeta origen nunca se pregunta — es,
  implícitamente, la tarjeta que ya se está viendo.
- El historial de solo lectura de **esa tarjeta** vive ahí mismo, en esa
  pestaña "Operaciones" — para el historial **global** (todas las
  tarjetas del alcance del usuario), ver la siguiente sección.

## "Operaciones de saldo" es un hub con tres pestañas (revisado 2026-09-17)
Un solo ítem de menú, "Operaciones de saldo", concentra todo lo
relacionado a operaciones y depósitos — antes eran **dos** ítems
separados ("Operaciones de saldo" como historial, "Aprobaciones" como
cola de pendientes); se fusionaron porque tener dos entradas de menú
sobre el mismo dominio no aportaba claridad. Sus tres pestañas:
- **Pendientes de aprobación**: la cola de `BalanceOperation` en
  `pending_approval` dentro del alcance del usuario (antes era todo el
  contenido de "Aprobaciones").
- **Depósitos por conciliar**: la cola de `CollectorDeposit` en `pending`
  de la Cuenta Colectora de cada Cliente en el alcance del usuario — ver
  `docs/business/tesoreria-cliente.md` y
  `docs/feature/tesoreria-cliente/README.md`.
- **Historial completo**: cualquier operación, cualquier estado, con los
  filtros de Tipo/Estado/Empresa — el antiguo contenido de la sección
  separada "Operaciones de saldo". Sigue sin tener botón para crear una
  operación ahí: crear siempre pasa por la tarjeta específica (ver
  sección anterior), para que el origen nunca sea ambiguo y para no
  necesitar un selector de "tarjeta origen" que obligaría a buscar entre
  todas las tarjetas del Cliente.

"Pendientes de aprobación" y "Depósitos por conciliar" se mantienen en
pestañas separadas (no una sola lista mezclada) a propósito: aprobar
autoriza que se ejecute una operación, mientras que conciliar confirma
que un depósito externo realmente llegó — son acciones de negocio
distintas (ver `docs/security/threat-model.md` punto 10), no solo dos
"colas de pendientes" intercambiables. Conciliar un depósito sigue siendo
posible también desde la Tesorería de ese Cliente específico — ver "Dos
entry points para conciliar" en
`docs/feature/tesoreria-cliente/README.md`.

## Captura de la tarjeta destino (transferencias)
Un selector tipo combo que liste todas las tarjetas del Cliente para
elegir el destino expondría PANs enmascarados y nombres de personas con
las que el operador no necesariamente tiene relación directa, solo para
completar un formulario — ver `docs/security/threat-model.md` punto 9.
En vez de eso:
1. El formulario de Transferencia pide los **últimos 4 dígitos** de la
   tarjeta destino (el dato que el propio tarjetahabiente le daría al
   operador) — no un combo navegable.
2. Al escribir 4 dígitos, se busca una coincidencia única dentro del
   **mismo Cliente** que la tarjeta origen (ver "Destino de una
   transferencia" más abajo — el alcance entre Clientes no cambió).
3. Si hay exactamente una coincidencia, se muestra una confirmación
   (nombre del tarjetahabiente y PAN enmascarado) antes de poder enviar —
   igual que un banco real confirma "vas a transferir a Juan Pérez,
   terminación 1234" antes de dejarte continuar.
4. Si no hay coincidencia, o hay más de una (no debería pasar dentro de
   un mismo Cliente, pero se maneja igual), se explica el problema en vez
   de dejar avanzar con un destino ambiguo.

## Destino de una transferencia
Una transferencia mueve saldo entre **dos tarjetas del mismo Cliente**
(cualquier tarjetahabiente de esa empresa, no solo entre tarjetas de la
misma persona). No se permite transferir entre tarjetas de Clientes
distintos, ni siquiera entre padre e hija.

## Flujo principal
1. Desde el detalle de una tarjeta, pestaña "Operaciones", un Operador
   (o Admin Cliente/Super Admin) con alcance sobre el Cliente dueño
   solicita Dispersión, Deducción o Transferencia, con el monto (y, para
   Transferencia, la tarjeta destino resuelta como se describió arriba).
2. Se evalúan las `approval_rules` del Cliente dueño de la tarjeta origen
   para ese tipo de operación y monto — ver
   `docs/business/approval-policy.md` para el default cuando no hay regla
   configurada.
3. Sin aprobación requerida → se ejecuta de inmediato: se escribe el/los
   movimiento(s) en el ledger — **desde que existe la Cuenta
   Concentradora** (`docs/business/tesoreria-cliente.md`), una Dispersión
   también debita la Concentradora del Cliente (puede fallar aquí por
   fondos insuficientes en la Concentradora, no solo en la tarjeta) y una
   Deducción también la acredita. Una Transferencia sigue sin tocarla —
   ver "Fondos insuficientes" más abajo.
4. Con aprobación requerida → la operación queda `pending_approval` y
   aparece en "Operaciones de saldo" → pestaña "Pendientes de aprobación"
   para el Admin Cliente correspondiente (o el de una empresa ancestro,
   por herencia de jerarquía).
5. El Admin Cliente aprueba o rechaza desde ahí:
   - Aprobar → pide confirmación explícita primero (ver
     `docs/business/confirmaciones-de-accion.md`, se ejecuta de inmediato
     y no tiene forma de deshacerse), luego se intenta ejecutar en el
     momento (incluida la Concentradora si aplica). Si hay saldo
     suficiente en todos los lados que aplican, pasa a `executed` y se
     escribe el ledger. Si no, pasa a `failed` con el motivo, y ningún
     ledger se toca.
   - Rechazar → pasa a `rejected` (requiere un motivo breve, que ya
     cumple el propósito de una confirmación — ver
     `docs/business/confirmaciones-de-accion.md`). Ningún ledger se toca.
6. La pestaña "Operaciones" de la tarjeta y la pestaña "Historial
   completo" del hub muestran exactamente los mismos datos (el historial
   sin restringir a una tarjeta) — mismo repositorio, sin duplicar
   lógica.
7. Si la operación se ejecutó (no si quedó `pending_approval` ni si
   `failed`), la pestaña "Resumen" de esa misma tarjeta refresca su
   saldo automáticamente — no hace falta salir y volver a entrar al
   detalle de la tarjeta para verlo actualizado. Ver "Refresco del saldo
   mostrado" más abajo.

## Refresco del saldo mostrado
`CardDetailView` obtiene la cuenta de saldo una sola vez al entrar al
detalle de la tarjeta (`_ledgerFuture`). Ejecutar una operación desde la
pestaña "Operaciones" cambia el saldo real (vía
`LedgerRepository.postEntry`), pero eso no invalida por sí solo ese
Future ya resuelto — sin una señal explícita, "Resumen" seguiría
mostrando el saldo viejo hasta refrescar la pantalla completa. La
pestaña "Operaciones" avisa al detalle de la tarjeta (un callback,
`onOperationAttempted`), y el detalle vuelve a pedir la cuenta de
saldo — como esa nueva petición alimenta el mismo `FutureBuilder` que
usan tanto "Resumen" como "Movimientos", ambas pestañas quedan al día,
no solo el número de saldo.

**Se dispara ante cualquier intento, no solo `executed`** (cambio
2026-09-19): la primera versión solo avisaba cuando el resultado era
`executed`, razonando que `pending_approval`/`failed` "nunca tocan el
ledger". Eso asumía que el ledger de una tarjeta solo cambia por
acciones que esta misma pantalla dispara — cierto mientras `admin/` era
la única app que podía tocar Cards/Ledger. Con
`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`,
`cardholder/` comparte el mismo backend, así que un `failed` por fondos
insuficientes casi siempre significa que el propio Tarjetahabiente
movió su saldo (ej. una transferencia C2C) mientras un Operador tenía
esta pantalla abierta con un número viejo en memoria — justo el caso
que motivó este cambio, ver el punto siguiente.

**El backend nunca confía en lo que ve la pantalla** — esto es
importante separarlo del punto anterior, que es solo una mejora de UX:
`Store.PostEntry` (donde termina tanto una operación de saldo de
`admin/` como una transferencia C2C de `cardholder/`) relee el saldo
real bajo un mutex y valida ahí mismo, nunca contra un número que el
cliente le mande. Aunque `admin/` nunca refrescara nada, sería
imposible dejar una tarjeta en negativo o aplicar un movimiento a
medias por una pantalla desactualizada — lo único que estaba mal antes
de este cambio era que el Operador se quedaba viendo un número viejo
después de un rechazo, no que el rechazo mismo fuera incorrecto.

**El diálogo de nueva operación también relee el saldo al abrirse**
(mismo cambio): antes solo tenía la foto que `CardDetailView` tomó al
entrar a la pantalla, potencialmente desactualizada por el mismo motivo
de arriba. `_OperationsTab._openOperationDialog` ahora vuelve a pedir
la cuenta de saldo justo antes de abrir `_BalanceOperationDialog`, que
muestra "Saldo disponible: $X" — así quien decide el monto lo hace
viendo un número fresco, no uno que llevaba rato en pantalla. Sigue sin
ser una garantía (puede volver a cambiar entre que se abre el diálogo y
se confirma) — esa garantía la sigue dando el backend, ver el punto
anterior.

## Captura del monto
El campo de monto nunca acepta texto libre — solo dígitos, formateado en
vivo como moneda con 2 decimales (ej. escribir "12345" se ve como
"$123.45"), vacío se trata como "$0.00". Ver el componente compartido
`CurrencyField` en `admin/lib/shared_widgets/`.

## Fondos insuficientes
Ninguna cuenta involucrada (tarjeta o Concentradora) se deja nunca en
negativo. Se valida en el momento exacto en que se intentaría escribir
el movimiento (al solicitar, si no requiere aprobación; al aprobar, si sí
la requería) — no al momento de llenar el formulario, porque el saldo
puede cambiar entre que se solicita y se aprueba.

- **Deducción**: puede fallar por saldo insuficiente en la tarjeta.
- **Transferencia**: puede fallar por saldo insuficiente en la tarjeta
  origen (no toca la Concentradora).
- **Dispersión**: puede fallar por saldo insuficiente en la
  **Concentradora** del Cliente — nunca en la tarjeta (recibir dinero
  nunca falla del lado de la tarjeta). Se debita la Concentradora
  primero; si eso falla, la tarjeta nunca se toca — mismo principio de
  "nunca dejar un movimiento a medias" que ya aplicaba a Transferencia.

## Cliente inactivo (nuevo, 2026-09-17)
Ni `request` ni `approve` se ejecutan si el Cliente dueño de la tarjeta
(o cualquiera de sus ancestros) está inactivo — verificación en el
repositorio, no solo en la UI, porque cubre el caso de alguien que ya
tenía sesión iniciada antes de que el Cliente se desactivara. Una
operación que ya estaba en `pending_approval` cuando el Cliente se
desactiva **queda congelada tal cual** — ni se aprueba ni se rechaza
hasta reactivar. Ver `docs/business/desactivacion-de-clientes.md`.

## Reglas de negocio
Ver `docs/business/approval-policy.md`,
`docs/business/roles-and-permissions.md` y
`docs/business/desactivacion-de-clientes.md` — no se repiten aquí.

## Backend (diseñado, pendiente)
`LedgerRepository` migra a un backend Go compartido con `cardholder/` —
ver `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` — la
decisión de si una operación requiere aprobación sigue resolviéndose del
lado de `admin/` (`approval_rules` no forma parte de ese backend
compartido); el backend solo ejecuta el movimiento de ledger una vez que
`admin/` ya decidió que debe ejecutarse. Sin cambios en esta pantalla.

## Casos borde / fuera de alcance
- Qué pasa si el Cliente dueño de la tarjeta no tiene ningún Admin Cliente
  activo — ya cubierto por la herencia de jerarquía existente, no es un
  caso huérfano.
- Operaciones concurrentes sobre la misma tarjeta: fuera de alcance, el
  repositorio fake es single-threaded.
- Editar o cancelar una operación ya solicitada (antes de que se
  apruebe/rechace): fuera de alcance, no solicitado.
- Notificar al Tarjetahabiente cuando se ejecuta una operación sobre su
  tarjeta: fuera de alcance (no hay autoservicio todavía).
- Transferir escribiendo el PAN completo en vez de los últimos 4 dígitos:
  no aplica — KBM nunca tiene el PAN completo en este nivel (ver
  `docs/security/data-classification.md`), solo `masked_pan`.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
