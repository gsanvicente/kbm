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
}
