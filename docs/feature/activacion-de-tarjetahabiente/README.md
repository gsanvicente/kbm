# Activación de cuenta del Tarjetahabiente

- Estado: **Implementado** (2026-09-21)
- ADR/TDR relacionados: `docs/adr/0002-flutter-web-mobile-two-apps.md`,
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`,
  `docs/adr/0019-cardholder-self-activation.md`
- Amenazas relevantes: `docs/security/threat-model.md` punto 16
- Roles/actores involucrados: Tarjetahabiente únicamente (nadie de staff
  participa en el flujo en sí — solo lo desbloquea manualmente si se
  agotan los intentos, ver "Seguridad")

## Objetivo
Que un Tarjetahabiente recién dado de alta por el staff pueda entrar por
primera vez a `cardholder/` y crear las credenciales con las que después
inicia sesión, sin que el staff tenga que hacer nada más que el alta que
ya hacía, y sin depender de ningún correo/SMS enviado por la plataforma.

## Contexto / motivación
Ver `docs/business/autoservicio-tarjetahabiente.md`, sección "Onboarding",
y `docs/adr/0019-cardholder-self-activation.md` para el porqué completo.
Resumen: `cardholder_users` (la tabla de login del Tarjetahabiente) existía
en el schema desde el principio pero nada la llenaba fuera del seed de
desarrollo — dar de alta a un Tarjetahabiente
(`docs/feature/alta-y-gestion-de-tarjetahabientes/`) nunca creó
credenciales de acceso.

## Nota de alcance de esta iteración
- Sin infraestructura de correo/SMS en el proyecto — la verificación de
  identidad usa datos que el staff **ya captura hoy** al dar de alta al
  Tarjetahabiente (email, número de identificación oficial), no un enlace
  ni un código enviado por la plataforma.
- El email de un Tarjetahabiente pasa de opcional a **requerido** en el
  alta (ver `docs/feature/alta-y-gestion-de-tarjetahabientes/README.md`) —
  sin él no hay identificador con el que activar ni con el que iniciar
  sesión después.
- Disponible en `cardholder/` tanto en web como en mobile — es el mismo
  código (ADR-0002), no hay una versión "solo app".
- Sin token ni código de un solo uso: la verificación es sin estado
  (compara contra `cardholders` directamente), salvo el contador de
  intentos fallidos (ver "Seguridad").

## Dónde vive en la UI
Un enlace **"¿Nuevo? Activa tu cuenta"** en la pantalla de login de
`cardholder/`, debajo del botón "Ingresar". Lleva a un formulario de una
sola pantalla, separado del login.

## Flujo principal
1. El Tarjetahabiente entra a `cardholder/` (web o mobile) y pulsa
   "¿Nuevo? Activa tu cuenta" desde el login.
2. Captura: email, número de identificación oficial (el mismo tipo que el
   staff registró — INE/pasaporte/cédula, sin necesidad de indicar cuál,
   el backend ya lo sabe por el Tarjetahabiente encontrado), nueva
   contraseña y su confirmación.
3. El backend busca un Tarjetahabiente **activo** (`is_active = true`)
   cuyo email coincida exactamente y cuyo número de identificación
   coincida, y que **todavía no tenga una fila en `cardholder_users`**
   (no se puede reactivar una cuenta ya activada por esta vía). Si
   cualquiera de esas condiciones falla, la respuesta es el mismo mensaje
   genérico en los cuatro casos: *"No pudimos verificar tus datos.
   Contacta a tu administrador."* — nunca se distingue cuál fue.
4. Si todo coincide: se crea la fila en `cardholder_users` con la
   contraseña elegida (hasheada con bcrypt) y se le regresa una sesión
   (mismo JWT que ya usa el login, ver
   `docs/adr/0013-jwt-session-authentication.md`) — entra directo a su
   cuenta, sin tener que volver a capturar sus credenciales en un login
   aparte.

## Seguridad
- **Mensaje de error genérico**, ver punto 3 arriba — nunca revela si el
  email existe, si el documento es el que no coincide, si la cuenta ya
  fue activada, o si el Tarjetahabiente está inactivo. Ver threat-model
  punto 16.
- **Límite de intentos fallidos: 5 por Tarjetahabiente, permanente.** A
  diferencia del límite de la transferencia C2C (5 **por sesión**, se
  reinicia con un nuevo login), aquí no existe ninguna sesión previa que
  reiniciar — el contador vive en `cardholders` y solo se reinicia con
  una acción manual del staff (ver "Desbloqueo" abajo). El contador se
  resetea a cero en cuanto una activación tiene éxito (deja de ser
  relevante, la cuenta ya existe).
- **Un Tarjetahabiente inactivo (`is_active = false`) no puede activar su
  cuenta** — mismo mensaje genérico, ver
  `docs/business/desactivacion-de-tarjetahabientes.md`, "Enforcement".
- **Contraseña**: mínimo 8 caracteres, validado en `cardholder/` y en el
  backend (defensa en profundidad, mismo criterio que el resto del
  proyecto) — mismo mínimo que ya rige para staff
  (`docs/business/gestion-de-usuarios-staff.md`).
- El endpoint de activación **no requiere sesión** (es, por definición,
  para quien todavía no tiene una) — es el único endpoint de
  `cardholder_users` sin `RequireAuth`.

## Desbloqueo tras 5 intentos fallidos
Un Admin Cliente o Super Admin (`canManageCardholders`, mismo grupo que ya
puede dar de alta/editar/desactivar Tarjetahabientes) ve, en el detalle
del Tarjetahabiente en `admin/`, un aviso si su activación está bloqueada,
con un botón **"Reiniciar intentos de activación"** — reinicia el
contador a cero sin revelar ni tocar ninguna contraseña (no existe
ninguna todavía, por definición, si la activación nunca tuvo éxito).

## Reglas de negocio
Ver `docs/business/autoservicio-tarjetahabiente.md`, sección "Onboarding",
y `docs/adr/0019-cardholder-self-activation.md` — no se repiten aquí.

## Casos borde / fuera de alcance
- Reenviar/recuperar si el Tarjetahabiente olvida la contraseña ya
  creada: fuera de alcance, ver
  `docs/business/gestion-de-usuarios-staff.md` (mismo hueco para ambos
  planos de identidad).
- Notificación automática (correo/SMS) de que ya puede activar su cuenta:
  fuera de alcance, no hay infraestructura de mensajería en el proyecto.
- Activar más de una vez / cambiar el email de login después de activada
  la cuenta: fuera de alcance, no solicitado.
- MFA durante la activación: fuera de alcance, ver
  `docs/business/autoservicio-tarjetahabiente.md`, "Segundo factor de
  autenticación".

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
