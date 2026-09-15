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
