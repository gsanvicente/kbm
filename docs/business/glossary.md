# Glosario de dominio — KBM

> Referencia viva. Si un término cambia de significado en el negocio,
> actualiza esta página primero, antes que el código.

- **Cliente (empresa)**: organización que contrata KBM para gestionar los
  saldos de sus tarjetahabientes. Puede tener empresas hijas (ver
  Jerarquía).
- **Jerarquía padre/hija**: relación entre Clientes que forma grupos
  corporativos de profundidad arbitraria (holding → subsidiaria →
  sub-subsidiaria). Ver `docs/adr/0003-multitenancy-rls-hierarchy.md`.
- **Tarjetahabiente**: persona física asociada a un Cliente, dueña de una
  o más Tarjetas.
- **Tarjeta**: instrumento de pago asociado a un Tarjetahabiente, con un
  estado (`active`, `blocked`, `frozen`, `cancelled`) y un saldo.
- **Ledger (libro mayor)**: registro contable de doble entrada
  (`ledger_accounts` + `ledger_entries`) que es la fuente de verdad interna
  del saldo de cada Tarjeta. Es append-only — nunca se edita ni se borra un
  movimiento ya escrito.
- **Procesador de tarjetas**: sistema externo (ej. estilo
  Marqeta/Galileo) contra el que se reconcilia el saldo real. KBM mantiene
  un ledger propio y sincroniza con el procesador (modelo híbrido).
- **Operación de saldo**: solicitud de Dispersión, Deducción o
  Transferencia sobre una Tarjeta (nombres visibles de los tipos técnicos
  `load`/`debit`/`transfer` — ver
  `docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
  "Nomenclatura"; bloqueo/desbloqueo es una acción directa aparte, ver
  `docs/feature/bloqueo-de-tarjeta/`). Sin aprobación requerida pasa
  directo de `pending_approval` a `executed`/`failed`; con aprobación
  requerida, el Admin Cliente aprueba (→ `executed`/`failed`) o rechaza
  (→ `rejected`). `approved` existe en el esquema para un futuro flujo
  asíncrono, no se usa como estado visible todavía — ver
  `docs/business/approval-policy.md`.
- **Regla de aprobación**: configuración por Cliente que determina si un
  tipo de operación (y a partir de qué monto) requiere aprobación antes de
  ejecutarse.
- **Cuenta Concentradora**: pool de dinero real de un Cliente (1:1, uno
  por Cliente) — de ahí sale el dinero de cada Dispersión y ahí regresa
  el de cada Deducción. Ver `docs/business/tesoreria-cliente.md`.
- **Cuenta Colectora**: punto de entrada para depósitos externos de un
  Cliente, antes de conciliarse hacia la Concentradora — un depósito
  registrado ahí no está disponible para dispersar hasta conciliarse.
  Ver `docs/business/tesoreria-cliente.md`.
- **Panel directivo**: pantalla de inicio ("Inicio") con un resumen
  ejecutivo de saldos, pendientes y actividad, solo para Super Admin y
  Admin Cliente. Ver `docs/feature/panel-directivo/README.md`.
- **Portal de autoservicio**: la app web/móvil del Tarjetahabiente (no
  staff) para ver su saldo/estado de cuenta, transferir C2C y
  congelar/descongelar su propia tarjeta — independiente de la gestión de
  saldos del staff. Ver `docs/business/autoservicio-tarjetahabiente.md`.
- **Transferencia C2C**: transferencia de autoservicio entre la tarjeta
  del Tarjetahabiente y la de otro Tarjetahabiente del mismo Cliente,
  identificando el destino por su número de tarjeta completo (no por un
  directorio) — distinta de la Transferencia que solicita un Operador
  desde la consola administrativa (esa sí puede requerir aprobación; la
  C2C nunca). Ver `docs/feature/transferencia-c2c-tarjetahabiente/README.md`.
- **Hash de PAN**: huella criptográfica irreversible (HMAC) del número
  completo de una tarjeta, usada solo para resolver el destino de una
  Transferencia C2C — nunca permite recuperar el PAN original. Ver
  `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`.
- **Congelar vs. bloquear una tarjeta**: dos acciones distintas sobre el
  mismo campo de estado. "Congelar" lo hace el propio Tarjetahabiente
  (reversible por él mismo); "bloquear" lo hace el staff (Admin
  Cliente+) y siempre pesa más — el Tarjetahabiente no puede revertir un
  bloqueo del staff. Ver `docs/business/autoservicio-tarjetahabiente.md`.
- **Rol**: perfil de acceso de un usuario administrativo/staff (Super
  Admin, Admin Cliente, Operador, Auditor). No confundir con el acceso de
  autoservicio del Tarjetahabiente, que es un plano de identidad distinto.
- **Autoservicio**: acceso del Tarjetahabiente a su propia información
  (portal web + app móvil), separado del acceso administrativo.
- **Outbox (buzón de salida)**: patrón usado para publicar eventos de
  dominio (ej. "operación aprobada") de forma confiable, en la misma
  transacción que el cambio de estado que los origina.
- **RLS (Row-Level Security)**: mecanismo de Postgres usado para aislar
  datos entre Clientes en una base de datos compartida.
