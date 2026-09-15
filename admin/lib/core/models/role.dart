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
}
