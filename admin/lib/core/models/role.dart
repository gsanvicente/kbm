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
  /// Tarjetahabientes". Operador gestiona saldos, no el perfil; Auditor es
  /// de solo lectura por definición.
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
}
