# Modelo de amenazas — KBM

> Referencia viva. Última revisión: 2026-09-24 (puntos 17 y 18, ADR-0021 y ADR-0022). Este documento es punto de
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

## 17. Fraude/PLD en pagos SPEI a un Beneficiario externo
**Riesgo:** `docs/adr/0021-conector-spei.md` permite que un Tarjetahabiente
mande dinero real a **cualquier CLABE externa** que él mismo registre como
Beneficiario de Pago — a diferencia de la Transferencia C2C (punto 12,
acotada al mismo Cliente, sin salir nunca del ecosistema KBM), aquí el
dinero sale de verdad hacia un banco externo. Una cuenta comprometida
(credenciales robadas) podría registrar un Beneficiario propio del
atacante y vaciar el saldo de la Cuenta Individual de la víctima.
**Mitigación de diseño:** validación de CLABE por dígito verificador y
catálogo de bancos (rechaza destinos mal formados antes de intentar
nada), confirmación explícita del beneficiario antes de pagar, bloqueo
tras intentos fallidos al registrar un Beneficiario, periodo de
enfriamiento para Beneficiarios recién agregados (no reciben montos
grandes de inmediato), y un umbral de monto configurable por Cliente
(`approval_rules`) por encima del cual el pago requiere aprobación del
staff — mismo mecanismo que ya usan Dispersión/Deducción, con el mismo
default fail-safe (sin regla configurada, requiere aprobación siempre).
**Lo que esto NO resuelve, marcado explícitamente como pendiente**:
verificación real contra listas de PLD/OFAC/SAT de un Beneficiario
requiere un proveedor SPEI elegido — ninguno de los candados de arriba la
sustituye. Validar con quien lleve el tema legal/compliance en Koons
antes de mover dinero real; no es una decisión que ADR-0021 resuelva por
sí solo.

## 18. Exposición agregada de Beneficiarios de Pago a staff, y la bandera de CLABE compartida entre tenants
**Riesgo:** `docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md`
le da a staff (cualquier rol, incluido Auditor) visibilidad de lectura
sobre los Beneficiarios de Pago de sus Tarjetahabientes — antes 100%
privados (punto 17). Dos riesgos nuevos, distintos entre sí:
1. **Exposición masiva**: a diferencia de ver un Beneficiario a la vez en
   la ficha de un Tarjetahabiente, el directorio agregado
   (`GET /v1/spei-beneficiaries`) puede traer cientos de filas de un
   jalón — un objetivo más atractivo para raspar/exportar CLABEs reales
   que cualquier pantalla individual del sistema.
2. **Fuga deliberada, mínima, entre tenants**: la bandera
   `sharedByMultipleCardholders` (misma CLABE registrada por
   Tarjetahabientes de Clientes distintos) se calcula **sin** respetar el
   alcance normal de RLS — es la única consulta de todo el proyecto que
   cruza el aislamiento entre tenants a propósito. Un Admin Cliente puede
   así inferir "existe otro registro de esta CLABE en algún lado que no
   puedo ver", aunque nunca se le muestre cuál Cliente ni cuál
   Tarjetahabiente es.
3. **Mismo riesgo del punto 1, en el reporte "Pagos SPEI"**: `GET
   /v1/spei-payments` (historial completo cross-cliente) reutiliza el
   campo `beneficiaryClabe` de `speipayment.Payment` — el mismo campo que
   la cola de aprobaciones (`GET /v1/spei-payments/pending`) sí necesita
   sin enmascarar, porque ahí staff verifica la CLABE real contra el
   banco antes de aprobar/rechazar un pago puntual. Corregido: el
   handler del reporte usa `dto.FromSPEIPaymentForReport` (enmascara),
   nunca `dto.FromSPEIPayment` (real) — dos funciones de mapeo separadas
   a propósito, para que un cambio futuro en una no enmascare por
   accidente la otra.

**Mitigación de diseño:**
- El directorio agregado de Beneficiarios y el reporte "Pagos SPEI"
  muestran la CLABE **enmascarada por default** (`••••1234`); verla
  completa (solo en Beneficiarios, vía "Revelar CLABE completa") exige
  una acción explícita restringida a `canManageCardholders` (Admin
  Cliente + Super Admin), y esa acción queda auditada
  (`audit_log`, `spei_beneficiary_clabe_revealed`) — a diferencia de la
  ficha individual de un Tarjetahabiente, donde la CLABE se muestra
  completa sin fricción adicional (mismo criterio que ya aplica ahí a
  RFC/CURP/domicilio).
- La bandera de CLABE compartida nunca expone el otro registro (Cliente,
  Tarjetahabiente, alias, banco) — es estrictamente un booleano. El
  resto de cada fila del directorio sigue estrictamente acotado al
  alcance normal de quien consulta.
- Auditoría completa de cada revelación de CLABE, para que el uso de
  este permiso sea en sí mismo revisable.

**Lo que esto NO resuelve, marcado explícitamente como pendiente**: esto
ayuda a un revisor humano a encontrar patrones, no sustituye una
verificación automática contra listas de PLD/OFAC/SAT (sigue pendiente,
ver punto 17) ni un scoring de riesgo real — la única señal automática es
la bandera booleana de CLABE compartida, sin ningún umbral configurable
de monto o frecuencia en esta iteración.
