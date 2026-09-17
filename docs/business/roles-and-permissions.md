# Roles y permisos — KBM

> Referencia viva. Última revisión: 2026-09-15.

## Roles administrativos/staff

| Rol | Alcance | Puede hacer |
|---|---|---|
| Super Admin (Koons) | Global, todos los Clientes | Crear/gestionar Clientes, usuarios, configuración del sistema, ver todo |
| Admin Cliente | Su Cliente + descendientes (si tiene hijas) | Gestionar tarjetahabientes/tarjetas, asignar Operadores, aprobar operaciones |
| Operador de Saldos | Su Cliente + descendientes | Cargar, debitar, transferir saldo, bloquear/desbloquear tarjetas |
| Auditor | Su Cliente + descendientes (o global) | Ver saldos, movimientos y reportes — sin poder modificar nada |

## Herencia sobre la jerarquía padre/hija

Cuando un Cliente tiene empresas hijas (ver
`docs/adr/0003-multitenancy-rls-hierarchy.md`):

- La visibilidad es **unidireccional**: el padre ve/opera sobre sus
  descendientes; una hija nunca ve al padre ni a sus hermanas.
- **Todos** los roles del padre heredan ese alcance sobre las
  descendientes — no solo Admin Cliente. Un Operador de la empresa padre
  puede operar tarjetas de las hijas exactamente igual que si fueran de su
  propia empresa.
- Esta herencia se aplica en dos capas (defensa en profundidad): la
  autorización de aplicación (puerto `AuthorizationPort`, ver
  `backend/internal/application/ports/doc.go`) y Row-Level Security en
  Postgres.

## Gestión de Tarjetahabientes (editar / desactivar)

Distinto de "ver" (todos los roles de staff pueden ver tarjetahabientes
dentro de su alcance): **editar información** (nombre, documento,
contacto) o **desactivar/reactivar** un tarjetahabiente está limitado a:

- **Super Admin** y **Admin Cliente** — coherente con que Admin Cliente ya
  tiene "gestionar tarjetahabientes" en su alcance en la tabla de arriba.
- **Operador** y **Auditor NO pueden** — el Operador gestiona *saldos*
  (operaciones de tarjeta), no el perfil del tarjetahabiente; el Auditor
  es de solo lectura por definición.

Desactivar un tarjetahabiente **no** requiere aprobación (no es una
`balance_operation`, no mueve dinero) — es una acción directa sujeta solo
al chequeo de rol de arriba. Ver
`docs/feature/detalle-y-gestion-tarjetahabiente/`.

## Plano de autoservicio (Tarjetahabiente)

Identidad completamente separada de los roles de staff (`cardholder_users`
vs. `users`). Alcance MVP: consulta (saldo, movimientos, estado de
tarjeta) + acciones básicas (solicitar recarga, congelar/bloquear su
propia tarjeta), sujetas a las mismas reglas de aprobación que aplicarían
si un Operador hiciera la misma operación.
