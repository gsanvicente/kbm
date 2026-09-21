# ADR-0017: Gestión de usuarios de staff, y RLS extendida a `users`

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
Hasta esta fecha, `users` (la identidad de staff — `admin/`) solo se
poblaba desde el seed de desarrollo; no existía ningún endpoint, puerto
ni pantalla para crear, editar, desactivar o restablecer la contraseña
de un usuario de staff. Se pidió agregarlo, con dos requisitos
explícitos del negocio: cada usuario está asociado a un rol y a una
empresa/cliente, y hace falta capturar sus "datos generales" para poder
configurar sus accesos.

Al analizar el pedido se identificaron varias decisiones que solo el
negocio podía resolver (no derivables de lo ya documentado, ver
`docs/business/roles-and-permissions.md`, que nunca cubrió esto): si
agregar un nombre real a `users` (no tenía ninguno), cómo se establece
la contraseña inicial sin infraestructura de correo, qué roles puede
asignar un Admin Cliente, y si construir solo alta o el paquete completo
de gestión. Resueltas explícitamente antes de implementar (ver
"Decisión").

Al diseñar el aislamiento por tenant de esta feature se encontró un
hueco real no relacionado con la pregunta original: `users` se había
quedado **fuera** de la lista de tablas con RLS desde
`migrations/0001_init.sql` — necesario en ese momento porque el login
debía poder leerla sin ninguna identidad de llamador todavía (ver
`docs/adr/0014-row-level-security-policies.md`). Sin corregir esto, un
Admin Cliente hubiera podido listar o crear usuarios de **cualquier**
empresa con solo cambiar el `client_id` en el request — nada a nivel de
base de datos lo hubiera impedido.

## Decisión

1. **`users` gana una columna `full_name` (NOT NULL)** —
   `migrations/0006_staff_user_management.sql`. El seed
   (`scripts/init-db/001_seed.sql`) se actualizó para proveerla
   directamente en su propio `INSERT` (la migración corre antes que el
   seed en una base nueva); la migración solo hace backfill para una
   base ya existente que se actualiza incrementalmente.
2. **`users` gana RLS**, con la misma política `tenant_isolation` (vía
   `app_client_accessible(client_id)`) que ya usan las otras 14 tablas
   por Cliente — la función ya maneja `client_id NULL` (Super Admin)
   correctamente sin cambios, ver ADR-0014. `StaffAuthStore.Login` se
   adaptó para correr con RLS bypaseado (mismo criterio que
   `Store.Login` de Tarjetahabiente) — a esa altura todavía no existe
   ninguna identidad de llamador que resolver.
3. **Contraseña inicial y restablecimiento: doble captura, escrita
   directamente por quien tiene alcance** (no un valor generado por el
   sistema) — decisión explícita del negocio, dado que no existe
   infraestructura de envío de correo para un flujo de activación por
   email. Validado en ambos lados (mínimo 8 caracteres, coincidencia de
   confirmación) — defensa en profundidad, mismo criterio que el resto
   del proyecto.
4. **Roles asignables: Admin Cliente, Operador, Auditor — nunca Super
   Admin**, decisión explícita del negocio. A diferencia de otras
   restricciones de este proyecto, esta NO depende del rol de quien crea
   — un Admin Cliente puede crear a otro Admin Cliente (decisión
   explícita), pero ni Super Admin ni Admin Cliente pueden crear un
   Super Admin. Esa cuenta sigue siendo exclusivamente de
   seed/aprovisionamiento manual.
5. **Paquete completo desde el inicio** (alta + edición + desactivar/
   reactivar + restablecer contraseña) — decisión explícita del
   negocio, para no dejar un hueco a medias como ya se evitó con
   Clientes y Tarjetahabientes.
6. **Auto-protección: nadie puede desactivarse a sí mismo** — no pedido
   explícitamente, pero se agregó por el mismo criterio de seguridad ya
   establecido para "un Admin Cliente no puede desactivar su propia
   empresa" (`docs/business/desactivacion-de-clientes.md`): evitar un
   bloqueo sin forma de revertirlo. Reforzado en la UI (la opción no
   aparece en la propia fila) y en el backend (rechaza con 400).
7. **Email y Cliente inmutables tras la creación** — mismo criterio que
   Tarjetahabientes: mover de Cliente y cambiar el identificador de
   login quedan fuera de alcance de "editar el perfil".
8. **UI anidada en la pestaña "Usuarios" del detalle de un Cliente**, no
   un directorio global — mismo patrón que Tarjetahabientes, coherente
   con la regla de UX del proyecto de no exponer directorios sueltos
   (cada capacidad vive en la pantalla del registro al que pertenece).
9. **Solo Postgres implementa esto** (`StaffManagementRepository`, nil
   en modo memoria) — mismo criterio que Clientes/Tesorería/Aprobaciones/
   Cardholders desde ADR-0012; el modo demo nunca tuvo la ambición de
   soportar gestión completa de todos los dominios.
10. **Cada acción se audita** (`staff_user_created`, `_updated`,
    `_deactivated`, `_reactivated`, `_password_reset`) vía el mismo
    `logCallerAudit` de ADR-0015/0016, dentro de la misma transacción de
    la escritura.

## Consecuencias
- Verificado en vivo contra Postgres real: un Admin Cliente de
  Subsidiaria A no puede ver ni un usuario real y existente de
  Subsidiaria B (RLS); Super Admin nunca es un rol asignable en el
  formulario (verificado tanto en `admin/` como intentándolo
  directamente por HTTP, rechazado con 400); crear con email duplicado
  responde 409 sin duplicar nada; un intento de auto-desactivación
  responde 400 con un mensaje claro; el flujo completo de
  crear→actualizar rol→restablecer contraseña→login con la nueva
  contraseña→desactivar funciona de punta a punta.
- `go build/vet/test` y `flutter analyze`/`flutter test` (113 tests,
  incluidos 5 nuevos para esta feature) en verde.
- El adaptador en memoria no ganó esta capacidad — sigue limitado a
  `Login`, sin cambios.
- `Session`/`StaffUser` (Dart) y `staff.User` (Go) ganaron `fullName` —
  ningún consumidor existente se rompió (el campo es aditivo).

## Alternativas consideradas
- **Generar una contraseña temporal aleatoria en vez de doble captura**:
  la opción presentada junto a la elegida; se descartó porque, sin
  infraestructura de correo para comunicarla, el admin hubiera tenido
  que leerla de la pantalla y transcribirla de todas formas — la doble
  captura logra lo mismo con menos pasos y sin mostrar una contraseña en
  texto plano en la UI más tiempo del necesario.
- **Permitir que Admin Cliente solo cree Operador/Auditor** (no Admin
  Cliente): la opción presentada junto a la elegida; se descartó a favor
  de permitir también Admin Cliente, decisión explícita del negocio.
- **Un directorio global de usuarios de staff** (como
  `global_cardholder_list_view.dart`): descartado por ahora — no fue
  pedido, y el caso de uso ("¿quién tiene acceso a esta empresa?") ya lo
  cubre la vista anidada; se reconsidera si se vuelve una necesidad real
  cruzando muchos Clientes a la vez.

## Ver también
- `docs/business/gestion-de-usuarios-staff.md`
- `docs/business/roles-and-permissions.md`
- `docs/adr/0014-row-level-security-policies.md`
- `docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`
- `docs/feature/gestion-de-usuarios-staff/README.md`
- `backend/migrations/0006_staff_user_management.sql`
