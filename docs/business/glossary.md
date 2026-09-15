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
- **Operación de saldo**: solicitud de carga, débito, transferencia,
  bloqueo o desbloqueo sobre una Tarjeta. Tiene un estado
  (`pending_approval → approved/rejected → executed/failed`).
- **Regla de aprobación**: configuración por Cliente que determina si un
  tipo de operación (y a partir de qué monto) requiere aprobación antes de
  ejecutarse.
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
