# Gestión de usuarios de staff

> Complementa `docs/business/roles-and-permissions.md` — ese documento
> define qué puede hacer cada rol; este define quién puede **crear,
> editar, desactivar y restablecer la contraseña** de las cuentas de
> staff en sí (`users`), distinto de gestionar Clientes o
> Tarjetahabientes.

## Contexto

Hasta 2026-09-21, los únicos usuarios de staff que existían venían del
seed de desarrollo (`backend/scripts/init-db/001_seed.sql`) — no existía
ninguna pantalla ni endpoint para dar de alta uno nuevo. Cada usuario de
staff pertenece a exactamente un Cliente (excepto Super Admin, de
alcance global) y tiene exactamente un rol
(`docs/business/roles-and-permissions.md`).

## Quién puede crear a quién

- **Super Admin** puede crear un usuario con rol Admin Cliente, Operador
  o Auditor, en cualquier Cliente del sistema.
- **Admin Cliente** puede crear un usuario con rol Admin Cliente,
  Operador o Auditor, dentro de **su propio Cliente o cualquiera de sus
  descendientes** — mismo alcance jerárquico que ya rige la gestión de
  Clientes y Tarjetahabientes.
- **Operador y Auditor no pueden** crear, editar ni desactivar usuarios
  de staff — es la misma línea que ya separa "operar el día a día" de
  "administrar la estructura", igual que con Clientes y Tarjetahabientes.
- **Super Admin nunca es un rol asignable desde esta pantalla**, sin
  importar quién lo pida — ni Super Admin puede crear otro Super Admin
  así. Esa cuenta sigue siendo exclusivamente de seed/aprovisionamiento
  manual, una decisión deliberada para no convertir "quién administra la
  plataforma completa" en un flujo de autoservicio.

## Qué se puede editar

- **Nombre completo y rol**: editables en cualquier momento por quien
  tiene alcance sobre ese usuario.
- **Email**: fijo desde la creación — es el identificador de login, no
  se reasigna.
- **Cliente**: fijo desde la creación — mover un usuario de una empresa
  a otra está fuera de alcance (igual que Tarjetahabientes, a diferencia
  de Cliente, que no tiene este concepto).
- **Contraseña**: se restablece por una acción separada y explícita
  ("Restablecer contraseña"), nunca como parte de editar el perfil — la
  misma separación de responsabilidades que ya usa "conciliar un
  depósito" frente a "registrar un depósito" (docs/business/tesoreria-cliente.md).

## Contraseña inicial y restablecimiento

No existe infraestructura de envío de correo en el proyecto todavía, así
que no hay un flujo de "activa tu cuenta por email". En su lugar:

- **Alta**: quien crea el usuario escribe la contraseña inicial
  directamente en el formulario, con un campo de confirmación (doble
  captura) para evitar errores de tecleo — la comunica al nuevo usuario
  por el canal que corresponda fuera de esta plataforma.
- **Restablecimiento**: mismo patrón — quien tiene alcance sobre el
  usuario escribe una contraseña nueva con su confirmación.
- **Longitud mínima**: 8 caracteres, validado tanto en `admin/` como en
  el backend (defensa en profundidad, mismo criterio que el resto del
  proyecto).
- Ninguna de las dos operaciones revela ni permite consultar la
  contraseña actual — solo se puede sobreescribir.

## Auto-protección: nadie puede desactivar su propia cuenta

Un usuario de staff nunca puede desactivarse a sí mismo, aunque tenga
alcance técnico para hacerlo (p. ej. un Admin Cliente sobre su propia
fila) — se quedaría sin acceso sin ninguna forma de revertirlo. Mismo
criterio exacto que "un Admin Cliente no puede desactivar su propia
empresa" (`docs/business/desactivacion-de-clientes.md`). Reforzado tanto
en la UI (la opción ni siquiera aparece en su propia fila) como en el
backend.

## Ver también

- `docs/business/roles-and-permissions.md`
- `docs/adr/0017-staff-user-management-and-rls-on-users.md`
- `docs/feature/gestion-de-usuarios-staff/README.md`
