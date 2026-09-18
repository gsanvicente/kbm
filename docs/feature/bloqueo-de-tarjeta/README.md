# Bloqueo / desbloqueo de Tarjeta

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake mutable)
- ADR/TDR relacionados: ninguno nuevo
- Amenazas relevantes: `docs/security/threat-model.md` punto 1 (control de acceso — bloquear sin verificar rol)
- Roles/actores involucrados: Super Admin, Admin Cliente, Operador (pueden operar); Auditor (solo ve)

## Objetivo
Primera funcionalidad real de "Operaciones de saldo": permitir bloquear
temporalmente una tarjeta ya asignada (y desbloquearla), desde su propia
pantalla de detalle.

## Contexto / motivación
Hasta ahora el estado `blocked` de una tarjeta solo existía como dato de
semilla (`**** **** **** 7890` de Carlos Ruiz) sin ninguna acción real que
lo produjera. Esta es la primera pieza de la sección "Operaciones de
saldo" del menú, aunque el control vive en `CardDetailView`, no en una
pantalla nueva.

## Nota de alcance de esta iteración
- Acción **directa** (como desactivar un Tarjetahabiente): no pasa por un
  flujo de aprobación todavía, aunque el modelo de negocio sí lo
  contempla — ver `docs/business/tarjetas-y-asignacion.md`, sección
  "Quién puede bloquear / desbloquear".
- Solo aplica a tarjetas **asignadas** (`activa` o `blocked`) — una
  tarjeta `disponible` no tiene sentido bloquearla (nadie la tiene), y
  `congelada`/`cancelada` quedan fuera de alcance (ver nota de negocio).
- `CardRepository` (fake) gana un método `setBlocked`, análogo a
  `CardholderRepository.setActive`.
- Desde `docs/feature/alta-y-gestion-de-tarjetahabientes/`, `setBlocked`
  también guarda **por qué** se bloqueó (`blocked_reason: manual` cuando
  es esta acción directa) y rechaza **desbloquear** si el Tarjetahabiente
  dueño de la tarjeta está inactivo — ver
  `docs/business/tarjetas-y-asignacion.md`, "Motivo de bloqueo".

## Flujo principal
1. En el detalle de una tarjeta asignada, si el rol lo permite, aparece
   un botón "Bloquear" (si está activa) o "Desbloquear" (si está
   bloqueada).
2. Al tocarlo, se pide confirmar explícitamente (2026-09-19, ver
   `docs/business/confirmaciones-de-accion.md`) — el mensaje incluye la
   terminación de la tarjeta y qué va a pasar. Al confirmar, el estado de
   la tarjeta cambia de inmediato — se refleja en el badge de la tarjeta
   grande y en cualquier listado que la muestre.
3. Si el rol no lo permite (Auditor), no ve el botón, igual que ya pasa
   con "Asignar" en `docs/feature/pool-y-asignacion-de-tarjetas/`.

## Reglas de negocio
Ver `docs/business/tarjetas-y-asignacion.md` — no se repite aquí. Punto
clave: **Operador sí puede** bloquear/desbloquear (a diferencia de la
gestión de Tarjetahabientes, donde Operador no tiene permiso) — es
justamente el rol pensado para operar sobre tarjetas ya asignadas.

## Casos borde / fuera de alcance
- Congelar/cancelar: fuera de alcance, ver
  `docs/feature/operacion-saldo-con-aprobacion/`.
- Flujo de aprobación real (cola de "Aprobaciones"): fuera de alcance de
  esta iteración — ver nota de negocio.
- Notificar al Tarjetahabiente cuando su tarjeta se bloquea: fuera de
  alcance, no solicitado.

## Criterios de aceptación
Ver `acceptance.feature`.
