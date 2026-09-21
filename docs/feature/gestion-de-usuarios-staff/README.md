# Gestión de usuarios de staff

- Estado: Implementada (2026-09-21) — Postgres únicamente, ver "Nota de alcance"
- ADR/TDR relacionados: `docs/adr/0013-jwt-session-authentication.md`, `docs/adr/0014-row-level-security-policies.md`, `docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`, `docs/adr/0017-staff-user-management-and-rls-on-users.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control de acceso), 2 (fuga de datos entre tenants) y 7 (secretos y credenciales)
- Roles/actores involucrados: Super Admin, Admin Cliente (pueden gestionar); Operador, Auditor (sin acceso a esta pantalla)

## Objetivo
Permitir que Super Admin y Admin Cliente den de alta, editen,
desactiven/reactiven y restablezcan la contraseña de las cuentas de
staff (`admin/`) dentro de su alcance — hasta ahora, la única forma de
crear un usuario de staff era el seed de desarrollo.

## Contexto / motivación
Ver `docs/business/gestion-de-usuarios-staff.md` para el detalle
completo de negocio. En resumen: cerrar el último hueco de
autoservicio en la gestión de la plataforma — Clientes y
Tarjetahabientes ya se pueden gestionar por completo desde `admin/`,
pero las cuentas de staff en sí seguían siendo un dato de solo-seed.

## Nota de alcance
Solo el adaptador Postgres implementa `StaffManagementRepository` — el
modo demo (`STORAGE_BACKEND=memory`) queda fuera, mismo criterio que
Clientes/Tesorería/Aprobaciones/Cardholders (ver ADR-0012):
`h.StaffManagement` queda `nil` en esa rama y `Routes()` no registra sus
rutas. `admin/`'s `FakeStaffUserRepository` (usado solo por
`flutter test`, que no puede hablar con un backend real) simula el mismo
contrato en memoria.

## Flujo principal
1. Desde el detalle de un Cliente, la pestaña "Usuarios" (visible solo
   para Super Admin/Admin Cliente) lista los usuarios de staff de ese
   Cliente — nunca incluye Super Admin.
2. "Nuevo usuario" abre un formulario: nombre completo, email, rol
   (Admin Cliente/Operador/Auditor — nunca Super Admin) y contraseña +
   confirmación.
3. Cada fila ofrece "Editar" (nombre y rol), "Restablecer contraseña"
   (contraseña nueva + confirmación) y "Desactivar"/"Reactivar" — esta
   última nunca aparece sobre la propia fila del usuario que la ve.
4. Todo intento fallido de validación (contraseñas que no coinciden,
   menos de 8 caracteres, email duplicado) se resuelve con un mensaje
   claro sin cerrar el formulario.
5. Cada alta/edición/desactivación/restablecimiento queda registrada en
   `audit_log` con el actor real que la hizo (ver
   `docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`).

## Reglas de negocio
Ver `docs/business/gestion-de-usuarios-staff.md` — quién puede crear a
quién, qué campos son editables, la política de contraseña, y la
auto-protección contra desactivarse a sí mismo.

## Casos borde / fuera de alcance
- Mover un usuario de un Cliente a otro: fuera de alcance (email y
  Cliente son inmutables desde la creación).
- Recuperación de contraseña por el propio usuario ("olvidé mi
  contraseña"): fuera de alcance — no existe infraestructura de envío de
  correo en el proyecto. Solo Super Admin/Admin Cliente pueden
  restablecerla por él.
- Crear o gestionar Super Admin desde esta pantalla: nunca — esa cuenta
  sigue siendo exclusivamente de seed/aprovisionamiento manual.
- MFA: mencionado en `docs/security/data-classification.md` como
  recomendado, no implementado en esta iteración.

## Criterios de aceptación
- Super Admin y Admin Cliente ven la pestaña "Usuarios"; Operador y
  Auditor no.
- El rol Super Admin nunca aparece como opción en el formulario de alta
  ni de edición, sin importar quién esté creando.
- Un Admin Cliente solo ve/gestiona usuarios de su propio Cliente y sus
  descendientes (Row-Level Security, ver ADR-0017) — verificado en vivo
  que un usuario real de otra empresa hermana es invisible.
- Crear un usuario con contraseñas que no coinciden, o de menos de 8
  caracteres, muestra el error sin crear nada.
- Crear un usuario con un email ya existente muestra un error claro
  (409) sin crear un duplicado.
- Ningún usuario ve la opción de desactivar su propia cuenta.
- Cada acción (alta, edición, desactivación, reactivación,
  restablecimiento de contraseña) genera una fila en `audit_log` con el
  actor correcto.
