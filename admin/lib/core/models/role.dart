enum Role {
  superAdmin,
  clientAdmin,
  operator,
  auditor;

  String get label {
    switch (this) {
      case Role.superAdmin:
        return 'Super Admin';
      case Role.clientAdmin:
        return 'Admin Cliente';
      case Role.operator:
        return 'Operador';
      case Role.auditor:
        return 'Auditor';
    }
  }

  /// Editar/desactivar tarjetahabientes — ver
  /// docs/business/roles-and-permissions.md, sección "Gestión de
  /// Tarjetahabientes". Operador gestiona saldos (ver
  /// [canRequestBalanceOperations]), no el perfil del tarjetahabiente;
  /// Auditor es de solo lectura por definición.
  bool get canManageCardholders => this == Role.superAdmin || this == Role.clientAdmin;

  /// Bloquear/desbloquear una tarjeta ya asignada — ver
  /// docs/business/tarjetas-y-asignacion.md, sección "Quién puede
  /// bloquear / desbloquear". A diferencia de [canManageCardholders],
  /// Operador SÍ puede: es justamente el rol pensado para operar sobre
  /// tarjetas ya asignadas. Solo Auditor no puede.
  bool get canOperateCards => this != Role.auditor;

  /// Solicitar un reclamo sobre un movimiento — mismo grupo que
  /// [canOperateCards] (Operador es justo el rol operativo del día a
  /// día). Ver docs/business/reclamos-de-movimientos.md.
  bool get canFileClaims => canOperateCards;

  /// Resolver un reclamo (a favor o rechazado) — mismo grupo que
  /// [canManageCardholders]: separación de responsabilidades deliberada,
  /// quien opera el día a día no decide el resultado de una disputa. Ver
  /// docs/business/reclamos-de-movimientos.md.
  bool get canResolveClaims => canManageCardholders;

  /// Solicitar una Dispersión/Deducción/Transferencia — mismo grupo que
  /// [canOperateCards] (Operador de Saldos: es justo su enfoque, ver
  /// docs/business/roles-and-permissions.md). Solo Auditor no puede.
  /// Nota histórica: el 2026-09-19 se restringió por error a Admin
  /// Cliente+, contradiciendo esta regla ya documentada — se revirtió el
  /// mismo día. Ver docs/feature/operacion-saldo-con-aprobacion/.
  bool get canRequestBalanceOperations => canOperateCards;

  /// Aprobar/rechazar una operación de saldo pendiente — mismo grupo que
  /// [canManageCardholders]/[canResolveClaims]: separación deliberada
  /// entre quien opera y quien autoriza. Ver
  /// docs/business/approval-policy.md.
  bool get canApproveBalanceOperations => canManageCardholders;

  /// Registrar un depósito en la Cuenta Colectora — mismo grupo que
  /// [canRequestBalanceOperations] (misma naturaleza operativa). Ver
  /// docs/business/tesoreria-cliente.md.
  bool get canRegisterCollectorDeposits => canOperateCards;

  /// Conciliar un depósito (Colectora → Concentradora) — mismo grupo que
  /// [canApproveBalanceOperations]: separación deliberada, quien registra
  /// un depósito no necesariamente es quien confirma que ya está
  /// disponible para dispersar. Ver docs/business/tesoreria-cliente.md.
  bool get canReconcileDeposits => canManageCardholders;

  /// Ver el Panel directivo ("Inicio") — mismo grupo que
  /// [canManageCardholders]: es un resumen ejecutivo pensado para quien
  /// gestiona la estructura de la empresa, no para el uso operativo del
  /// día a día. Operador y Auditor siguen aterrizando en "Clientes". Ver
  /// docs/feature/panel-directivo/README.md.
  bool get canViewExecutiveDashboard => canManageCardholders;
}
