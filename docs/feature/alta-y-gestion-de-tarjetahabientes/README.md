# Alta, edición y desactivación de Tarjetahabientes

- Estado: **Implementado** (diseñado y ampliado 2026-09-18 sobre lo que
  antes era "Detalle y gestión de Tarjetahabiente" — ver "Historial"
  abajo — implementado el mismo día) — dependía del CRUD de Clientes
  (`docs/feature/alta-y-gestion-de-clientes/`), ya construido. El email
  pasó de opcional a requerido el 2026-09-21 al construirse
  `docs/feature/activacion-de-tarjetahabiente/README.md`.
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control
  de acceso roto — editar/desactivar/asignar sin verificar rol), 4
  (trazabilidad de cambios), 14 (Tarjetahabiente inactivo cuyas tarjetas
  siguen operables) y 16 (el email capturado aquí, ahora requerido, es la
  puerta de entrada de la activación de cuenta)
- Roles/actores involucrados: Super Admin, Admin Cliente (pueden dar de
  alta, editar y desactivar); Operador, Auditor (solo ven)

## Historial
Esta feature nace como "Detalle y gestión de Tarjetahabiente" (solo
editar/desactivar sobre un tarjetahabiente ya sembrado). Se renombra y
amplía en 2026-09-18 para incluir el **alta** (crear uno desde cero, que
antes no existía en absoluto — ni el método `create` en
`CardholderRepository`) y para endurecer las reglas de **desactivación**,
que antes no tenían ningún efecto real sobre las tarjetas del
tarjetahabiente. Se llega aquí tanto desde
`docs/feature/tarjetahabientes-por-cliente/` como desde
`docs/feature/listado-global-tarjetahabientes/`.

## Objetivo
Permitir que Super Admin o Admin Cliente den de alta, editen y
desactiven/reactiven un Tarjetahabiente (persona física) dentro de su
propio alcance, con el mismo nivel de rigor de captura y de gobernabilidad
que ya se construyó para Clientes.

## Contexto / motivación
Hasta ahora todos los tarjetahabientes de la demo eran datos de semilla —
no había ninguna forma de registrar a una persona nueva. Además,
"desactivar" a un tarjetahabiente era cosmético: no impedía asignarle
tarjetas nuevas ni afectaba en nada a las que ya tenía, lo cual es un
hueco de gobernabilidad real (si alguien deja de trabajar para el
Cliente, sus tarjetas deberían dejar de poder usarse).

## Nota de alcance de esta iteración
- Repositorio fake, mismo patrón que el resto del proyecto — sin backend
  real. `CardholderRepository` gana `create`, `getById` e `isOperable`
  (antes solo tenía `listByClient(s)`, `update` y `setActive`).
- **Solo datos estructurados** — sin carga de documentos (identificación
  oficial, comprobante de domicilio escaneados). Mismo criterio que
  `docs/business/kyb-cliente.md`.
- Un Tarjetahabiente es una persona física con un conjunto de campos
  plano (ver `docs/business/kyc-tarjetahabiente.md`) — a diferencia del
  expediente KYB de un Cliente (que sí justifica un wizard de varios
  pasos por su volumen y sus sub-entidades), aquí **un solo diálogo/
  formulario de una pantalla** es suficiente tanto para crear como para
  editar.

## Dónde vive esto en la UI
Un botón **"+ Nuevo Tarjetahabiente"**, visible solo si el rol tiene
`canManageCardholders`, **únicamente dentro de la pestaña de
Tarjetahabientes de un Cliente específico**
(`docs/feature/tarjetahabientes-por-cliente/`) — no existe ese botón en
el listado global (`docs/feature/listado-global-tarjetahabientes/`). El
`clientId` queda implícito por el contexto en el que se está parado, sin
necesidad de un selector de empresa aparte (a diferencia de Cliente, que
sí necesita elegir bajo qué padre se crea porque puede crearse desde
cualquier nivel de la jerarquía).

## Alta

### Formulario (una sola pantalla, no wizard)
Mismas secciones que ya existían en el diálogo de edición: Identificación,
Domicilio, Contacto, Cumplimiento. Ver "Validaciones" abajo para el
detalle de cada campo.

## Flujo principal (alta)
1. Un Super Admin o Admin Cliente entra al Cliente correspondiente, a su
   pestaña de Tarjetahabientes, y pulsa "+ Nuevo Tarjetahabiente".
2. Completa el formulario (una sola pantalla).
3. Al guardar, se crea el Tarjetahabiente con `is_active = true`, ligado
   al Cliente desde el que se creó.
4. Aparece de inmediato en el listado de ese Cliente y en el listado
   global.

## Editar un Tarjetahabiente existente
Reutiliza el mismo diálogo que ya existe hoy (`_EditCardholderDialog`),
con dos cambios:
- **Validaciones de formato** aplicadas a los campos que hoy son texto
  libre (ver "Validaciones").
- **Deshabilitado por completo si el Tarjetahabiente está inactivo** — a
  diferencia de Cliente (donde sí se puede seguir editando el expediente
  mientras está inactivo), aquí la decisión de negocio es la contraria:
  **no se permite ningún cambio a un Tarjetahabiente inactivo**, para no
  generar modificaciones sobre un registro que podría ser evidencia de
  cara a una auditoría (ej. por qué se le dio de baja, qué datos tenía en
  ese momento). El botón "Editar" no aparece (no solo se deshabilita) y
  la acción también se verifica en el repositorio, no solo en la UI.

## Desactivar / reactivar un Tarjetahabiente
Ver `docs/business/desactivacion-de-tarjetahabientes.md` para el detalle
completo de las reglas de negocio — aquí solo el flujo de UI.

1. Desde el detalle de un Tarjetahabiente, un botón **"Desactivar"** (o
   "Reactivar" si ya está inactivo), visible solo si el rol tiene
   `canManageCardholders`.
2. Al desactivar, se pide una **confirmación explícita** (acción de alto
   impacto: bloquea todas sus tarjetas activas y le impide recibir
   tarjetas nuevas) — mismo criterio que ya se usa para desactivar un
   Cliente.
3. Al confirmar: el Tarjetahabiente queda `is_active = false`, y **todas
   sus tarjetas actualmente sin bloquear pasan a `blocked`** con
   `blocked_reason = cardholder_inactive` (ver la sección "Motivo de
   bloqueo" en `docs/business/tarjetas-y-asignacion.md`). Una tarjeta que
   ya estaba bloqueada manualmente (`blocked_reason = manual`, ej. por
   robo/fraude) conserva su motivo original — no se sobrescribe.
4. Mientras esté inactivo: no se le puede asignar ninguna tarjeta nueva, y
   ninguna de sus tarjetas (bloqueada por el motivo que sea) puede
   desbloquearse — el chequeo de "¿puede operar?" vive en el repositorio,
   cubre a cualquiera que lo intente sin importar su rol.
5. **Reactivar no desbloquea las tarjetas automáticamente** — decisión de
   negocio explícita, distinta de la cascada de Cliente (que sí es
   simétrica). Reactivar solo permite: (a) volver a asignarle tarjetas
   nuevas, y (b) que un admin pueda, a partir de ese momento, desbloquear
   cada tarjeta congelada **una por una, manualmente**, como una acción
   deliberada aparte. No hay un botón "desbloquear todas".

## Validaciones
- **Nombre completo, tipo y número de identificación oficial**:
  requeridos.
- **CURP**: 18 caracteres, alfanumérico, mayúsculas forzadas —
  **requerido solo si la nacionalidad es "Mexicana"**, opcional para
  cualquier otra nacionalidad (un extranjero no tiene CURP).
- **RFC**: 13 caracteres (persona física — distinto de los 12 de Cliente,
  que es persona moral), alfanumérico, mayúsculas forzadas, opcional
  siempre (relevante solo si el Tarjetahabiente requiere facturación).
- **Nacionalidad**: combo/dropdown, no texto libre — ver "Catálogo de
  nacionalidades" abajo. Determina si CURP es requerido.
- **Código postal**: solo dígitos, 5 caracteres.
- **Teléfono**: solo dígitos, 10 caracteres.
- **Email**: **requerido** desde 2026-09-21 (antes opcional, solo
  validación de formato) — es el identificador con el que el
  Tarjetahabiente activa y luego inicia sesión en `cardholder/`, ver
  `docs/feature/activacion-de-tarjetahabiente/README.md`. Sigue sin
  verificarse que la cuenta de correo exista de verdad, solo formato
  (contiene `@` y un dominio con punto).
- **Domicilio (calle, colonia, ciudad, estado), fecha de nacimiento**:
  opcionales, sin formato especial más allá de texto libre.
- Sin validación de dígito verificador real de CURP/RFC en esta
  iteración (igual que Cliente) — solo formato/longitud.

### Catálogo de nacionalidades
Combo con una lista curada, no las ~195 nacionalidades del mundo — la
base de clientes de Koons es mayoritariamente mexicana:
"Mexicana" (default), "Estadounidense", "Canadiense", "Española",
"Colombiana", "Argentina", "Otra". Elegir "Otra" no habilita un campo de
texto libre en esta iteración (fuera de alcance) — es un catch-all
explícito, no una nacionalidad real capturada.

## Reglas de negocio
Ver `docs/business/roles-and-permissions.md` sección "Gestión de
Tarjetahabientes" (quién puede crear/editar/desactivar), y
`docs/business/desactivacion-de-tarjetahabientes.md` (congelamiento de
tarjetas, enforcement, motivo de bloqueo) — no se repiten aquí. Punto
clave: crear/editar/desactivar **no** requiere aprobación (no son
`balance_operation`).

## Casos borde / fuera de alcance
- Validación real de CURP/RFC (dígito verificador): campos de texto
  formateado, no validado a nivel de checksum — ver
  `docs/business/kyc-tarjetahabiente.md`.
- Cambiar el Cliente al que pertenece un Tarjetahabiente ("mover" entre
  empresas): fuera de alcance, no solicitado.
- Historial de cambios (quién editó qué y cuándo): fuera de alcance de
  esta iteración — cuando exista backend real, debe ir a `audit_log` (ver
  `docs/security/threat-model.md` punto 4).
- Crear un Tarjetahabiente desde el listado global (con selector de
  Empresa): fuera de alcance — decisión de negocio explícita, ver "Dónde
  vive esto en la UI".
- Desbloquear en lote todas las tarjetas congeladas de un Tarjetahabiente
  reactivado: fuera de alcance, ver "Desactivar / reactivar" arriba —
  cada una se desbloquea por separado, a mano.
- Nacionalidades fuera del catálogo curado: ver "Catálogo de
  nacionalidades" arriba.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
