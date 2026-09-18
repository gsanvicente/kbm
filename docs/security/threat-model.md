# Modelo de amenazas — KBM

> Referencia viva. Última revisión: 2026-09-15. Este documento es punto de
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

## 2. Fuga de datos entre tenants
**Riesgo:** un query mal filtrado devuelve datos de otro Cliente,
especialmente en la jerarquía padre/hija (bug de "ver de más" hacia
hermanas o hacia el padre).
**Mitigación de diseño:** `client_hierarchy` + GUC de sesión
`app.accessible_client_ids` fuerza el filtro a nivel de base de datos
incluso si la capa de aplicación tiene un bug.

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
`docs/security/data-classification.md`), y las mismas reglas de
aprobación que aplicarían a un Operador cuando el Tarjetahabiente solicita
una acción vía autoservicio.

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
persona antes de que el dinero sea utilizable.
