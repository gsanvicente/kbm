# ADR-0019: Activación de cuenta del Tarjetahabiente sin infraestructura de mensajería

- Estado: Aceptada
- Fecha: 2026-09-21

## Contexto
`docs/business/autoservicio-tarjetahabiente.md` dejaba el onboarding como
nota especulativa desde el inicio: *"el Tarjetahabiente descarga la app...
y se registra/activa, validando contra los datos que el staff ya
capturó"* — sin decir cómo. Al mismo tiempo, `cardholder_users` (la tabla
de login del Tarjetahabiente) existe en el schema desde el principio pero
ningún código de la aplicación escribe en ella — solo se llena hoy vía
seed SQL manual. El alta de un Tarjetahabiente
(`docs/feature/alta-y-gestion-de-tarjetahabientes/`) crea su expediente
KYC pero nunca ha tocado `cardholder_users`.

El proyecto ya resolvió un problema estructuralmente parecido para el otro
plano de identidad: `docs/business/gestion-de-usuarios-staff.md`, sección
"Contraseña inicial y restablecimiento" — sin infraestructura de correo/SMS
en el proyecto, ahí la decisión fue que **quien crea al usuario escribe la
contraseña inicial directamente** y la comunica fuera de la plataforma.
Pero el verbo reflexivo del doc de autoservicio ("se registra/activa")
sugería lo contrario para el Tarjetahabiente: que el propio Tarjetahabiente
elige su contraseña, no el staff. Esta ADR resuelve esa tensión.

## Decisión
1. **Autoservicio real, no contraseña asignada por staff.** El
   Tarjetahabiente activa su propia cuenta desde `cardholder/` (misma app
   web+mobile, ver ADR-0002) sin que el staff realice ninguna acción
   nueva. Se aprovecha que dos datos ya existen siempre en `cardholders`
   antes de esta feature — número de identificación oficial (siempre
   obligatorio) y email (que esta ADR vuelve obligatorio, ver punto 2) —
   como prueba de identidad, en vez de construir un canal de entrega
   (correo/SMS) o un token de un solo uso que requeriría estado nuevo.
2. **`cardholders.email` pasa a ser obligatorio** (antes `citext` sin
   `NOT NULL`) — sin él no hay ningún identificador con el que activar ni
   con el que iniciar sesión después. Los 4 Tarjetahabientes de seed ya
   tienen email, la migración no requiere backfill.
3. **Verificación sin estado**: el endpoint de activación no crea ni
   consume ningún token — compara email + número de identificación
   ingresados contra `cardholders`, y falla igual (mensaje genérico) tanto
   si el email no existe como si el documento no coincide como si la
   cuenta ya fue activada — mismo criterio de "nunca revelar" que ya usan
   `getLedger`/`getClaim` y la resolución de destino de transferencias C2C
   (threat-model puntos 9 y 12).
4. **Contraseña**: la elige el Tarjetahabiente en el mismo formulario,
   mínimo 8 caracteres — mismo mínimo que ya rige para staff — hasheada
   con bcrypt (`golang.org/x/crypto/bcrypt`, mismo paquete que
   `staff_management.go`, compatible con los hashes ya sembrados vía
   pgcrypto's `crypt(..., gen_salt('bf'))`).
5. **Antifuerza bruta**: 5 intentos fallidos consecutivos (email+documento
   que no resuelve a una cuenta activable) bloquean permanentemente la
   activación de ese Tarjetahabiente — se levanta solo con una acción
   manual del staff (`canManageCardholders`), mismo criterio que ya existe
   para restablecer una contraseña de staff (una persona con alcance
   administrativo interviene, no hay autoservicio de desbloqueo). A
   diferencia del límite de la transferencia C2C (5 por sesión, se
   reinicia al volver a iniciar sesión), aquí no existe sesión previa —
   el contador vive en `cardholders`, no se reinicia solo.
6. **Disponible en `cardholder/` web y mobile por igual** — se descarta la
   restricción "solo mobile" que tenía la nota original: technicamente es
   el mismo código (ADR-0002), y no hay ninguna razón de negocio para que
   alguien no pueda activar su cuenta desde una computadora si así lo
   prefiere. `docs/business/autoservicio-tarjetahabiente.md` se actualiza
   para reflejar este cambio de alcance.
7. **Un Tarjetahabiente inactivo (`is_active = false`) no puede activar su
   cuenta** — mismo mensaje genérico que un dato que no coincide, mismo
   criterio que ya aplica al login (`docs/business/desactivacion-de-tarjetahabientes.md`,
   "Enforcement", Capa 1 — antes marcada "autoservicio futuro", ahora real).

## Consecuencias
- Cero infraestructura nueva de mensajería, cero tabla/columna de tokens
  — la única columna nueva es un contador de intentos fallidos en
  `cardholders`.
- El staff no conoce ni maneja la contraseña de ningún Tarjetahabiente, a
  diferencia del patrón de staff — mejor postura de seguridad para el
  plano de mayor volumen (potencialmente miles de Tarjetahabientes vs.
  decenas de usuarios de staff).
- `docs/feature/alta-y-gestion-de-tarjetahabientes/README.md` cambia:
  email pasa de "validación básica de formato" a **requerido**.
- Si más adelante se integra un proveedor real de correo/SMS, este diseño
  no se descarta — se le puede sumar un aviso automático ("ya puedes
  activar tu cuenta") sin cambiar el mecanismo de verificación en sí.

## Alternativas consideradas
- **Staff escribe la contraseña inicial** (mismo patrón que
  `gestion-de-usuarios-staff.md`): descartado — el propio doc de
  autoservicio ya describía un flujo reflexivo/self-service, y sumar a
  potencialmente miles de Tarjetahabientes a la misma exposición que hoy
  tienen decenas de usuarios de staff (el staff conoce su contraseña) es
  una postura de seguridad peor a esa escala, no solo una preferencia de
  producto.
- **Código de un solo uso generado por staff y compartido fuera de
  banda**: descartado por ahora — requeriría una pantalla nueva en
  `admin/` para generar/mostrar el código y una tabla/columna de estado
  para el token (con expiración), sin ninguna ganancia real sobre validar
  contra datos que el staff ya capturó, dado que ambos mecanismos dependen
  igual de un canal fuera de la plataforma para que el Tarjetahabiente se
  entere de que existe la activación en primer lugar.
- **Restringir la activación a mobile únicamente** (como sugería la nota
  original): descartado — hubiera sido el primer `Platform.isX`/`kIsWeb`
  de todo el proyecto (ver ADR-0002, cero ramificación por plataforma
  hasta ahora) para una restricción sin justificación de negocio real.

## Ver también
- `docs/business/autoservicio-tarjetahabiente.md`
- `docs/feature/activacion-de-tarjetahabiente/README.md`
- `docs/business/gestion-de-usuarios-staff.md` — el patrón equivalente
  para staff, y en qué difiere.
- `docs/feature/alta-y-gestion-de-tarjetahabientes/README.md`
- `docs/business/desactivacion-de-tarjetahabientes.md`
- `docs/security/threat-model.md` punto 16.
