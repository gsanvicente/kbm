# Alta, edición y desactivación de Clientes

- Estado: **Implementado** (diseñado 2026-09-17, ampliado el mismo día
  con edición y desactivación, implementado 2026-09-17/18) — fue la
  primera pieza construida de esta fase, prerrequisito del CRUD de
  Tarjetahabientes y del portal de autoservicio.
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control
  de acceso), 2 (fuga de datos entre tenants) y 13 (enforcement de
  Cliente inactivo) — crear/desactivar un Cliente en el punto equivocado
  de la jerarquía, o dejar un hueco de enforcement al desactivar, son
  justamente esos riesgos
- Roles/actores involucrados: Super Admin, Admin Cliente (Operador y
  Auditor no tienen esta capacidad — ver
  `docs/business/roles-and-permissions.md`, "Gestión de Clientes")

## Objetivo
Permitir que Super Admin o Admin Cliente den de alta, editen y
desactiven/reactiven un Cliente (empresa) con su expediente legal (KYB)
completo, respetando la estructura multi-tenant: cada quien solo puede
actuar dentro de su propio alcance de la jerarquía.

## Contexto / motivación
Hoy `ClientRepository` solo tiene `listAccessibleClients` — no existe
ninguna forma de crear un Cliente real, todo el árbol viene sembrado en
`FakeClientRepository`. Este es el primer flujo de **escritura** sobre la
jerarquía de Clientes, y el prerrequisito para que el resto de features
recientes (Tesorería, Panel directivo, autoservicio del Tarjetahabiente)
tengan sentido con datos reales en vez de datos sembrados a mano.

## Nota de alcance de esta iteración
- Repositorio fake, mismo patrón que el resto del proyecto — sin backend
  real.
- **Solo datos estructurados** — sin carga de documentos (acta, poderes,
  comprobante de domicilio). Ver `docs/business/kyb-cliente.md`.
- Esta feature cubre **alta, edición y desactivación/reactivación**.
  Eliminar un Cliente por completo (borrado real, no solo inactivarlo)
  sigue fuera de alcance — no se pidió, y un borrado real de una empresa
  con historial financiero nunca sería lo correcto de todas formas
  (append-only, ver `docs/business/saldo-y-ledger.md`).

## Dónde vive esto en la UI
Un botón **"+ Nuevo Cliente"** en la pantalla "Clientes" (la misma que ya
existe, hoy de solo lectura — `docs/feature/panel-principal-admin/`),
visible solo si el rol tiene `canManageClients`.

### Selector de dónde crear (antes del formulario)
Antes de llegar al formulario KYB, se elige **bajo qué Cliente** se va a
crear el nuevo:
- **Admin Cliente**: ve un selector limitado a su propia empresa +
  todos sus descendientes (los mismos que ya ve en
  `listAccessibleClients`) — no puede crear una empresa raíz nueva sin
  padre.
- **Super Admin**: ve el mismo selector, más una opción explícita "Sin
  empresa padre (nueva empresa raíz)".

Esto no es un campo más del formulario — es una decisión previa que
determina el `parentClientId`, y por lo tanto el alcance de todo lo
demás.

### Formulario KYB (multi-paso)
Dado el volumen de campos (ver `docs/business/kyb-cliente.md`), el
formulario se divide en pasos, no una sola pantalla larga — mismo
criterio de UX que ya aplicamos al expediente KYC de Tarjetahabiente,
pero aquí con más secciones:
1. **Datos generales** — razón social, nombre comercial, RFC, fecha de
   constitución, objeto social, datos del acta constitutiva.
2. **Domicilio fiscal**.
3. **Apoderado(s) legal(es)** — el principal es parte del flujo
   obligatorio de este paso; "Agregar otro apoderado" es una acción
   opcional dentro del mismo paso, no un paso aparte.
4. **Beneficiario(s) controlador(es)** — mismo patrón: el mayoritario es
   obligatorio, "Agregar otro beneficiario" es opcional.
5. **Revisión** — resumen de todo antes de confirmar la creación.

### Editar un Cliente existente (revisado 2026-09-17)
**No reutiliza el wizard de alta.** Un wizard lineal es buena UX para
capturar datos por primera vez (guía paso a paso), pero mala UX para
corregir un expediente ya completo — obligaría a pasar por cada paso
para arreglar un solo campo. En su lugar, "Editar" abre una **página
completa de una sola vista**, con las mismas secciones del wizard
(Datos generales, Domicilio fiscal, Apoderados, Beneficiarios) todas
visibles y desplazables a la vez, sin pasos — mismo criterio que ya usa
el diálogo de editar Tarjetahabiente, solo que de página completa por el
volumen de campos KYB.

- La **empresa padre queda de solo lectura** — re-parentar sigue fuera
  de alcance (ver "Casos borde").
- Mismas validaciones de formato que el alta (ver "Validaciones").
- Disponible para Super Admin y Admin Cliente dentro de su propio
  alcance — mismo criterio que crear.
- Un Cliente **inactivo puede seguir editándose** por quien tiene
  alcance sobre él (para corregir datos antes de reactivar, por
  ejemplo) — editar no es una acción "operativa" en el sentido de
  `docs/business/desactivacion-de-clientes.md`, es administración del
  propio expediente.

## Flujo principal
1. Un Super Admin o Admin Cliente entra a "Clientes" y pulsa "+ Nuevo
   Cliente".
2. Elige bajo qué Cliente se crea (ver "Selector de dónde crear" arriba).
3. Completa el formulario KYB en sus pasos — puede avanzar/retroceder
   entre pasos sin perder lo ya capturado.
4. En la revisión, confirma. Se crea el Cliente con `is_active = true`,
   su `parentClientId` resuelto del paso 2, y su expediente KYB completo.
5. El nuevo Cliente aparece de inmediato en el listado de "Clientes" del
   creador (y de cualquier ancestro suyo, por herencia de jerarquía) —
   mismo comportamiento que ya existe para ver Clientes sembrados.

## Desactivar / reactivar un Cliente (nuevo, 2026-09-17)
Ver `docs/business/desactivacion-de-clientes.md` para el detalle
completo de las reglas de negocio (cascada, enforcement en dos capas,
qué pasa con operaciones pendientes) — aquí solo el flujo de UI.

1. Desde el detalle de un Cliente, un botón **"Desactivar"** (o
   "Reactivar" si ya está inactivo), visible solo si el rol tiene
   `canManageClients` **y** el Cliente está dentro de su propio alcance
   **y** no es su propia empresa (ver regla de negocio abajo).
2. Al desactivar, se pide una confirmación explícita (es una acción de
   alto impacto: bloquea login de todo el staff de esa empresa y de
   todas sus descendientes) — mismo criterio de "confirmar antes de una
   acción irreversible o de alto impacto" que ya aplica en el resto de
   la consola.
3. Al confirmar: el Cliente y **todos sus descendientes** quedan
   `is_active = false`. Cualquier operación de saldo `pending_approval`
   dentro de ese alcance queda congelada tal cual estaba — ni aprobar ni
   rechazar hasta reactivar.
4. El Cliente (y su subárbol) se sigue viendo en el listado —marcado
   visualmente como inactivo— para quien tenga alcance de lectura sobre
   él, pero ninguna acción operativa está disponible mientras esté
   inactivo.
5. **Reactivar** es simétrico a desactivar: revierte `is_active = true`
   para ese Cliente **y todos sus descendientes**, y libera las
   operaciones que quedaron congeladas (vuelven a poder
   aprobarse/rechazarse normalmente). Simplificación deliberada: no se
   distingue si un descendiente ya estaba inactivo *antes* de que su
   ancestro se desactivara (por una razón propia, independiente) —
   reactivar el ancestro reactiva todo el subárbol sin excepción. Si más
   adelante se necesita ese matiz, es una extensión futura (requeriría
   guardar el motivo/origen de cada inactivación, no solo el flag).

## Validaciones
- Razón social, RFC persona moral, domicilio fiscal completo: requeridos.
- Apoderado principal: requerido, con sus datos de identificación
  completos y su tipo de poder.
- Beneficiario controlador mayoritario: requerido, con su porcentaje de
  participación.
- Apoderados adicionales / beneficiarios minoritarios: opcionales, pero
  si se agrega uno, sus propios campos (identificación, tipo de poder o
  porcentaje según corresponda) sí son obligatorios para ESE registro.
- Sin validación de dígito verificador real de RFC/CURP en esta
  iteración (igual que KYC de Tarjetahabiente) — solo formato/longitud
  sugerida.

## Reglas de negocio
Ver `docs/business/kyb-cliente.md` (expediente),
`docs/business/roles-and-permissions.md` sección "Gestión de Clientes"
(quién puede crear/editar/desactivar y dónde), y
`docs/business/desactivacion-de-clientes.md` (cascada, enforcement,
operaciones congeladas) — no se repiten aquí.

## Casos borde / fuera de alcance
- **Eliminar un Cliente por completo** (borrado real, no solo
  inactivarlo): fuera de alcance, ver "Nota de alcance".
- Re-parentar un Cliente ya existente (moverlo a otro padre en la
  jerarquía): fuera de alcance — no se pidió y tiene implicaciones no
  triviales sobre `client_hierarchy` (la tabla de cierre transitivo, ver
  `backend/migrations/0001_init.sql`).
- Carga de documentos (acta, poderes, comprobante de domicilio): fuera de
  alcance, ver `docs/business/kyb-cliente.md`.
- Validar que el RFC de la nueva empresa no esté ya registrado en el
  sistema (deduplicación): no definido todavía — riesgo real (¿puede la
  misma empresa fiscal aparecer dos veces?) que vale la pena resolver
  antes de implementar, no se asume una respuesta aquí.
- Invalidar sesiones ya iniciadas del staff de un Cliente que se acaba de
  desactivar: fuera de alcance en esta iteración fake — no hay mecanismo
  de push de servidor a cliente para forzar un logout remoto; el bloqueo
  real ocurre en el *siguiente* intento de login o de una acción
  operativa (ver `docs/business/desactivacion-de-clientes.md`). Con
  backend real, esto se resolvería invalidando el token/sesión activa.
- Distinguir un descendiente que ya estaba inactivo antes de la cascada
  de su ancestro: fuera de alcance, ver "Desactivar / reactivar" arriba.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
