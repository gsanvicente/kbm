# Modelo de amenazas — KBM

> Referencia viva. Última revisión: 2026-09-21 (ADR-0017). Este documento es punto de
> entrada para la auditoría de seguridad — ver también
> `docs/security/data-classification.md` y `docs/security/compliance-notes.md`,
> y el `SECURITY.md` operativo de cada componente.

Análisis por área crítica, no exhaustivo — se amplía a medida que cada
feature se implementa (cada feature doc en `docs/feature/` debe referenciar
las amenazas de esta lista que aplican).

## 1. Control de acceso / autorización rota
**Riesgo:** un endpoint nuevo olvida verificar rol/jerarquía y expone datos
o acciones cruzando tenants.
**Mitigación de diseño:** `AuthorizationPort` invocado por **todos** los
casos de uso (no solo por el handler HTTP) — ver
`backend/internal/application/ports/doc.go` — más Row-Level Security en
Postgres como segunda barrera (defensa en profundidad, ver ADR-0003).
**Estado (2026-09-21):** identidad verificada por request (JWT, ver
`docs/adr/0013-jwt-session-authentication.md`), Row-Level Security con
políticas reales (`docs/adr/0014-row-level-security-policies.md`), y
autorización por rol reforzada en el servidor
(`docs/adr/0015-server-side-role-authorization-and-login-audit-log.md`,
`middleware.RequireRole`) — verificado en vivo que un Auditor ya no
puede aprobar una operación de saldo ni un Operador conciliar un
depósito golpeando el endpoint directamente, aunque la UI de `admin/`
nunca les muestre ese botón. Sigue sin existir un `AuthorizationPort`
genérico invocado por una capa de casos de uso (este backend interino no
tiene esa capa todavía) — el equivalente hoy es `RequireRole` montado
explícitamente en `Routes()`, y los ownership-checks de "alcance mixto"
(Cards/Ledger/transferencias, ADR-0013 punto 4) se siguen resolviendo a
mano en el handler.

## 2. Fuga de datos entre tenants
**Riesgo:** un query mal filtrado devuelve datos de otro Cliente,
especialmente en la jerarquía padre/hija (bug de "ver de más" hacia
hermanas o hacia el padre).
**Mitigación de diseño:** `client_hierarchy` + GUC de sesión
`app.accessible_client_ids` fuerza el filtro a nivel de base de datos
incluso si la capa de aplicación tiene un bug.
**Estado (2026-09-21):** implementado y verificado en vivo (ver
`docs/adr/0014-row-level-security-policies.md`) — el backend ahora se
conecta como `kbm_app`, un rol sin privilegios de superusuario ni de
dueño de tabla (ninguno de los dos queda sujeto a RLS, sin excepción),
con una política `tenant_isolation` en las 14 tablas por Cliente. Un
Operador de una Subsidiaria confirmadamente no puede leer datos de una
Subsidiaria hermana (Concentradora, Cardholders, movimientos) ni por la
API ni con una query directa a la base de datos — la aplicación ya no es
la única barrera. **Actualización (2026-09-21):** `users` (identidad de
staff) se sumó a esta lista al construir
`docs/adr/0017-staff-user-management-and-rls-on-users.md` — se había
quedado fuera desde ADR-0014 porque el login necesitaba leerla sin
ninguna identidad de llamador todavía; sin este cierre, un Admin Cliente
hubiera podido listar o crear usuarios de staff de cualquier empresa con
solo cambiar el `client_id` en el request.

## 3. Integridad del ledger
**Riesgo:** un movimiento se edita o borra (por error de aplicación o
acceso directo a la base de datos con credenciales comprometidas),
rompiendo la trazabilidad del saldo.
**Mitigación de diseño:** `ledger_entries` es append-only a nivel de
trigger de base de datos (`forbid_mutation`) — ninguna corrección se hace
editando historial, solo con movimientos compensatorios nuevos.

## 4. Repudio de operaciones de aprobación
**Riesgo:** no queda registro claro de quién solicitó/aprobó/rechazó una
operación de saldo, dificultando la auditoría después de un incidente.
**Mitigación de diseño:** `balance_operations` guarda `requested_by`,
`approved_by`, y cada transición pasa por el patrón Outbox
(`outbox_events`) hacia `audit_log`.
**Estado (2026-09-21):** `requested_by`/`resolved_by` en
`balance_operations` ya existen y se pueblan (ver ADR-0012). `audit_log`
ya registra cada solicitud/aprobación/rechazo con el actor real, además
de crear/editar/desactivar Cliente y Tarjetahabiente, asignar/bloquear
tarjetas, reglas de aprobación, reclamos y depósitos — ver
`docs/adr/0016-business-action-audit-log-and-approval-race-fix.md`. La
implementación es síncrona y directa (mismo criterio que el login de
ADR-0015), no vía el patrón Outbox que este párrafo insinuaba
originalmente — `outbox_events` sigue sin ningún escritor, reservado
para si el proyecto construye esa infraestructura async por otra razón
(p. ej. integración real con un procesador de tarjetas). De paso se
corrigió una condición de carrera real en `Approve`/`Reject`
(`approval.go`): dos llamadas concurrentes sobre la misma operación
pendiente podían ejecutar el movimiento de saldo dos veces —
reproducida y verificada cerrada en vivo con 10 `Approve()` concurrentes.

## 5. Integración con el procesador de tarjetas externo
**Riesgo:** un webhook falso o repetido del procesador (spoofing, replay)
altera el ledger interno o dispara reconciliaciones incorrectas.
**Mitigación de diseño (pendiente de implementar):** todo webhook entrante
debe validar firma/autenticidad antes de procesarse —
`backend/internal/adapters/processor` debe implementar esa verificación
antes de aceptar cualquier callback como confiable.

## 6. Autoservicio del Tarjetahabiente (superficie móvil)
**Riesgo:** toma de cuenta (account takeover) vía dispositivo móvil
comprometido o credenciales débiles; superficie de ataque distinta a la
del staff administrativo.
**Mitigación de diseño:** plano de identidad separado (`cardholder_users`
vs. `users`), política de autenticación propia (ver
`docs/security/data-classification.md`, MFA pendiente para ambos planos,
ver nota en `docs/business/autoservicio-tarjetahabiente.md`). A
diferencia de lo que se pensaba originalmente, las transferencias de
autoservicio **no** pasan por `approval_rules` (el Tarjetahabiente opera
su propio saldo libremente) — ver
`docs/business/autoservicio-tarjetahabiente.md` para el porqué. Ver
también los puntos 11 y 12 (riesgos específicos de la transferencia C2C).

## 7. Secretos y credenciales
**Riesgo:** credenciales reales committeadas o reutilizadas entre entornos
(ej. credenciales del seed local usadas en staging/prod).
**Mitigación de diseño:** `.env` gitignored, `.env.example` solo con
placeholders, `backend/scripts/init-db/001_seed.sql` explícitamente
marcado como solo-local.

## 8. Dependencias de terceros en runtime (frontend)
**Riesgo:** un paquete de UI descarga recursos externos en tiempo de
ejecución (ej. `google_fonts` obtiene el archivo de la tipografía Inter
desde una CDN de Google en el primer arranque) — superficie de red
adicional, y un punto de falla si esa CDN no es alcanzable en el entorno
de despliegue.
**Mitigación de diseño (pendiente de implementar):** vendorizar las
fuentes como asset local antes de producción/auditoría — ver
`admin/docs/tdr/0001-google-fonts-typography.md` y
`docs/adr/0007-custom-design-system-koons-tokens.md`. No cerrar esta
auditoría de seguridad sin resolver este punto.

## 9. Sobre-exposición de datos sensibles vía directorios navegables en la UI
**Riesgo:** aunque el control de acceso (punto 1) esté correcto — el
usuario sí tiene alcance legítimo sobre ese Cliente — una pantalla que le
permite **buscar/listar libremente** tarjetas o tarjetahabientes ajenos
para completar un formulario (ej. elegir una "tarjeta destino" de un
directorio de toda la empresa) expone más que lo necesario para la tarea:
el operador ve PANs enmascarados y nombres de personas con las que no
tiene relación directa, solo para escribir un número. Distinto del punto
2 (fuga *entre* tenants): aquí el riesgo es sobre-exposición *dentro* del
mismo tenant, por diseño de UI, no por un bug de autorización.
**Mitigación de diseño:** cuando un formulario necesita referenciar un
registro ajeno (ej. la tarjeta destino de una transferencia), resolverlo
por un identificador que quien solicita ya debería tener (ej. los últimos
4 dígitos que le dio el propio tarjetahabiente), mostrando una
confirmación de una sola coincidencia — nunca un combo/lista navegable de
todos los registros del Cliente. Ver
`docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
"Captura de la tarjeta destino".

## 10. Confiar en un depósito declarado sin verificación independiente
**Riesgo:** quien registra un depósito en la Cuenta Colectora
(`docs/business/tesoreria-cliente.md`) puede declarar un monto que nunca
llegó realmente — si esa misma persona también pudiera conciliarlo hacia
la Concentradora, el dinero quedaría disponible para dispersar sin que
nadie más lo haya confirmado.
**Mitigación de diseño:** registrar y conciliar son pasos separados con
roles distintos (Operador+ registra, solo Admin Cliente+ concilia) — el
saldo de la Concentradora nunca cambia por el solo hecho de registrar un
depósito. Sigue siendo un control manual (no hay verificación bancaria
real en esta iteración, ver "Fuera de alcance" en
`docs/feature/tesoreria-cliente/README.md`), pero exige una segunda
persona antes de que el dinero sea utilizable. Desde 2026-09-19, esa
segunda persona también debe confirmar explícitamente antes de conciliar
— ver `docs/business/confirmaciones-de-accion.md` — para reducir el
riesgo de conciliar por error un depósito que todavía no debería
liberarse.

## 11. PAN completo en tránsito para transferencias C2C de Tarjetahabiente
**Riesgo:** desde `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`,
el PAN completo del destinatario viaja hasta el backend (nunca se
almacena) para resolver una transferencia C2C. Si algún componente
(logging, APM, manejo de errores, un `print`/log de depuración olvidado)
lo captura por accidente, el invariante central de esa ADR se rompe
silenciosamente — es el tipo de bug que no se nota hasta una auditoría o
un incidente.
**Mitigación de diseño:** el campo de PAN se trata como secreto en todo
el pipeline de logging/observabilidad (misma categoría que
`password_hash` en `data-classification.md`) — cualquier middleware de
logs, manejo de excepciones o tracing debe excluirlo explícitamente antes
de escribir cualquier salida. Code review de esta feature específica debe
verificar esto como criterio de aceptación, no como buena práctica
opcional.

## 12. Enumeración de tarjetas vía resolución de beneficiario (transferencias C2C)
**Riesgo:** a diferencia del punto 9 (donde quien resuelve un destino ya
tiene una relación legítima con el Cliente completo), aquí cualquier
Tarjetahabiente autenticado podría escribir números de tarjeta al azar
para descubrir cuáles existen y a nombre de quién, si el sistema confirma
"tarjeta válida, pertenece a Fulano de Tal" antes de enviar. Es un
oráculo de enumeración con datos personales de por medio.
**Mitigación de diseño:** (a) un solo mensaje de error genérico para
"formato inválido" y "no pertenece a nuestro universo" — nunca se
distingue cuál de los dos motivos fue (mismo principio que
`docs/feature/login-administrativo/README.md` con email/contraseña); (b)
límite de intentos fallidos por sesión/usuario con bloqueo temporal — sin
esto, (a) por sí solo no evita que alguien pruebe miles de números.
Ver `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.

## 13. Un Cliente desactivado que sigue siendo operable
**Riesgo:** desactivar un Cliente (`docs/business/desactivacion-de-clientes.md`)
solo bloquea el *siguiente* login de su propio staff si la verificación
vive únicamente ahí — alguien con una sesión ya iniciada antes de la
desactivación (ej. un Super Admin, o un Admin Cliente ancestro) podría
seguir registrando depósitos, aprobando operaciones o gestionando
tarjetas de una empresa que ya no debería poder operar en ningún nivel.
Es un riesgo de **enforcement incompleto**, no de autorización rota
(punto 1) — la sesión sí es legítima, la acción no debería serlo.
**Mitigación de diseño:** enforcement en dos capas, no una — (a) bloqueo
de login para el staff propio de un Cliente inactivo o de cualquiera de
sus ancestros (`docs/feature/login-administrativo/README.md`); (b)
verificación de `is_active` (Cliente + cadena de ancestros) directamente
en el repositorio, en cada acción que mueve dinero o cambia estado
(`BalanceOperationRepository.request/approve`,
`TreasuryRepository.registerDeposit/reconcileDeposit`, asignar/bloquear
Tarjetas, reclamos) — nunca solo en la UI, para cubrir a quien ya tenía
sesión abierta. La capa (b) es la que realmente cierra este riesgo; la
(a) por sí sola no basta.

## 14. Un Tarjetahabiente inactivo cuyas tarjetas siguen operables
**Riesgo:** análogo al punto 13, pero a nivel de persona en vez de
empresa — si desactivar a un Tarjetahabiente solo cambia un flag
cosmético sin afectar sus tarjetas, alguien que ya dejó de estar
autorizado (ex-empleado, relación terminada) podría seguir gastando o
alguien con sesión ya iniciada podría seguir asignándole tarjetas nuevas
o desbloqueando las que tiene. Es, otra vez, un riesgo de **enforcement
incompleto**, no de autorización rota.
**Mitigación de diseño:** al desactivar, sus tarjetas sin bloqueo previo
pasan de inmediato a `blocked` con `blocked_reason = cardholder_inactive`
(efecto inmediato, no depende de que nadie vuelva a iniciar sesión).
Además, verificación de `is_active` del Tarjetahabiente directamente en
el repositorio, en cada acción relevante — `CardRepository.assign` (no
se le puede asignar una tarjeta nueva) y `CardRepository.setBlocked` al
desbloquear (no se puede revertir ningún bloqueo, sea cual sea su
motivo, mientras siga inactivo) — nunca solo en la UI, para cubrir a
quien ya tenía sesión abierta. A diferencia del punto 13, esta cascada es
**deliberadamente asimétrica**: reactivar al Tarjetahabiente no
desbloquea sus tarjetas automáticamente, para que ese paso quede sujeto a
una revisión manual explícita — ver
`docs/business/desactivacion-de-tarjetahabientes.md`.

## 15. Backend compartido (memoria o Postgres) expuesto más allá de localhost, o con CORS abierto
**Riesgo:** `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`
(y, desde que Postgres pasó a ser el default,
`docs/adr/0011-processor-integration-architecture-and-postgres-default.md`)
introduce un proceso Go real (no solo repositorios fake dentro de cada
app Flutter) que recibe el PAN completo en claro
(`docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`) en el cuerpo de
`/v1/transfers/resolve`. Dos formas concretas de que esto salga mal: (a)
el servidor escucha en `0.0.0.0` en vez de `127.0.0.1` y queda alcanzable
desde otras máquinas en la misma red; (b) CORS configurado con `*` en vez
de una lista explícita de orígenes, lo que permitiría a JavaScript de
**cualquier sitio web** que un navegador tenga abierto hacerle peticiones
a este backend si alguna vez quedara accesible fuera de loopback.
**Mitigación de diseño:** el servidor solo escucha en `127.0.0.1` (nunca
`0.0.0.0`) — no está pensado para exponerse fuera de la máquina de
desarrollo. CORS restringido explícitamente a los dos orígenes de
desarrollo de Flutter web (`http://127.0.0.1:8765`, `http://127.0.0.1:8766`),
nunca un wildcard. Code review de `internal/adapters/http` debe verificar
ambos puntos como criterio de aceptación — ver
`backend/docs/tdr/0003-in-memory-repository-adapter.md`.

## 16. Enumeración/fuerza bruta en la activación de cuenta del Tarjetahabiente
**Riesgo:** `docs/adr/0019-cardholder-self-activation.md` prueba la
identidad del Tarjetahabiente con dos datos que el staff ya capturó
(email + número de identificación oficial) en vez de un canal de entrega
(correo/SMS). Un endpoint sin sesión previa que acepta esos dos datos y
deja elegir una contraseña es un blanco directo para (a) enumerar qué
emails corresponden a Tarjetahabientes reales, y (b) probar números de
documento al azar contra un email conocido/filtrado hasta acertar y tomar
control de la cuenta antes que su dueño real la active.
**Mitigación de diseño:** mensaje de error genérico — nunca distingue
"el email no existe" de "el documento no coincide" de "esa cuenta ya fue
activada" de "el Tarjetahabiente está inactivo" (mismo criterio que los
puntos 9 y 12). Bloqueo permanente tras 5 intentos fallidos consecutivos
por Tarjetahabiente, levantable solo por staff con `canManageCardholders`
— a diferencia del límite de la transferencia C2C (punto 12, se reinicia
solo con un nuevo login), aquí no hay sesión previa que reiniciar, así que
el contador persiste hasta una intervención manual.
