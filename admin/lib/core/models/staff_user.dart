import 'role.dart';

/// Usuario de staff (admin/) — distinto de [Cardholder], que es la
/// identidad del portal de autoservicio. Ver
/// docs/feature/gestion-de-usuarios-staff/README.md.
class StaffUser {
  final String id;

  /// Null únicamente para [Role.superAdmin] (alcance global) — mismo
  /// criterio que [Session.clientId]. Super Admin nunca se crea desde
  /// esta pantalla (ver [Role]'s exclusión en el formulario de alta), así
  /// que en la práctica todo StaffUser que esta UI maneja trae un
  /// clientId no nulo.
  final String? clientId;
  final String email;
  final String fullName;
  final Role role;
  final bool isActive;

  const StaffUser({
    required this.id,
    this.clientId,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
  });

  StaffUser copyWith({String? fullName, Role? role, bool? isActive}) {
    return StaffUser(
      id: id,
      clientId: clientId,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}
