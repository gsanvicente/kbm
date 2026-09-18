# Confirmación antes de una acción de alto impacto

> Referencia viva. Última revisión: 2026-09-19.

## Por qué existe esto
Varias acciones de la consola mueven dinero real o cambian el estado
operativo de algo (una tarjeta, un tarjetahabiente, una empresa) de forma
inmediata y visible para otros roles. Ninguna de ellas debe poder
ejecutarse con un solo toque accidental — un clic de más en un ícono, o
un doble-tap sin querer, no debería aprobar una Dispersión de miles de
pesos ni bloquear la tarjeta de alguien. Esto es un control de **UX de
seguridad**, distinto (y complementario) del flujo de aprobación de
`docs/business/approval-policy.md`: una operación puede no requerir
`approval_rules` y aun así merecer un "¿estás seguro?" antes de
ejecutarse, porque el riesgo aquí es el error humano en el momento del
clic, no la falta de una segunda autorización.

## Patrón: `showConfirmDialog`
Un solo widget reutilizable (`admin/lib/shared_widgets/confirm_dialog.dart`)
en vez de un `AlertDialog` distinto por pantalla — título, mensaje con los
datos concretos de la operación (monto, tarjeta, Cliente, nombre), y dos
botones (Cancelar / Confirmar). `destructive: true` tiñe el botón de
confirmar en rojo, reservado para acciones que restringen algo (bloquear
una tarjeta, rechazar) en vez de habilitarlo.

El mensaje siempre incluye los datos concretos de lo que se va a hacer
(no un genérico "¿estás seguro?") — ej. "¿Deseas conciliar el depósito de
$10,000.00 del Cliente Koons Subsidiaria A? El saldo quedará disponible
de inmediato en su Cuenta Concentradora." — para que confirmar sea una
decisión informada, no un trámite que se aprieta sin leer.

## Inventario de acciones cubiertas
- **Aprobar** una operación de saldo pendiente (Dispersión/Deducción/
  Transferencia) — ver `docs/feature/operacion-saldo-con-aprobacion/README.md`.
  Se ejecuta de inmediato al aprobar.
- **Conciliar** un depósito de la Cuenta Colectora — ver
  `docs/feature/tesoreria-cliente/README.md`. Ambos entry points
  ("Tesorería" del Cliente y "Depósitos por conciliar" del hub de
  Aprobaciones) usan la misma confirmación.
- **Bloquear** y **desbloquear** una tarjeta — ver
  `docs/feature/bloqueo-de-tarjeta/README.md`. Ambas direcciones
  confirman (bloquear en rojo, desbloquear no).
- **Desactivar/reactivar** un Cliente — ver
  `docs/business/desactivacion-de-clientes.md` (ya implementado antes de
  este inventario).
- **Desactivar/reactivar** un Tarjetahabiente — ver
  `docs/business/desactivacion-de-tarjetahabientes.md` (ya implementado
  antes de este inventario).

## Deliberadamente sin confirmación adicional
- **Rechazar** una operación de saldo: ya exige escribir un motivo —
  esa fricción (un campo de texto obligatorio, no un solo tap) cumple el
  mismo propósito que un diálogo de confirmación.
- **Asignar** una tarjeta disponible: ya exige elegir explícitamente un
  Tarjetahabiente de una lista dentro de un diálogo modal y tocar
  "Asignar" — no es un botón suelto de una sola acción.
- **Registrar** un depósito, **presentar/resolver** un reclamo,
  **solicitar** una operación de saldo (Dispersión/Deducción/
  Transferencia): todas requieren llenar un formulario (monto,
  referencia, motivo) antes de un botón de envío — la captura de datos ya
  es la fricción deliberada, un segundo diálogo "¿estás seguro?" sería
  redundante.
- **Crear/editar** un Cliente o un Tarjetahabiente: alta o baja de datos,
  no mueven dinero ni cambian el estado operativo de nada — no aplica.

## Fuera de alcance
- No hay un mecanismo de "deshacer" después de confirmar — la
  confirmación previene el error, no lo revierte una vez ejecutado.
- No se registra (todavía) quién confirmó vs. quién solo abrió el
  diálogo y canceló — eso viviría en `audit_log` con backend real, ver
  `docs/security/threat-model.md` punto 4.

## Ver también
- `docs/business/approval-policy.md` — el otro control de "alguien más
  debe autorizar esto", con el que este patrón no debe confundirse.
- `docs/security/threat-model.md` punto 10.
