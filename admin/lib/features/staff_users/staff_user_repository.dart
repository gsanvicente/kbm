import '../../core/models/role.dart';
import '../../core/models/staff_user.dart';

class EmailAlreadyExistsException implements Exception {
  const EmailAlreadyExistsException();
  @override
  String toString() => 'Ese email ya está en uso.';
}

abstract class StaffUserRepository {
  /// Usuarios de staff de un único Cliente — nunca incluye Super Admin.
  /// Ver docs/feature/gestion-de-usuarios-staff/README.md.
  Future<List<StaffUser>> listByClient(String clientId);

  /// Da de alta un nuevo usuario de staff. [role] nunca puede ser
  /// [Role.superAdmin] — ese rol no es asignable desde esta pantalla, ver
  /// docs/business/gestion-de-usuarios-staff.md, "Quién puede crear a
  /// quién". [password] ya viene validado (coincide con su
  /// confirmación, longitud mínima) por el formulario que llama esto.
  /// Lanza [EmailAlreadyExistsException] si el email ya está en uso.
  Future<StaffUser> create({
    required String clientId,
    required String email,
    required String fullName,
    required Role role,
    required String password,
  });

  /// Actualiza nombre y rol de un usuario existente — email y clientId
  /// quedan fijos desde la creación (ver [StaffUser]). [updated.role]
  /// nunca puede ser [Role.superAdmin].
  Future<StaffUser> update(StaffUser updated);

  Future<StaffUser> setActive(String userId, bool isActive);

  /// Restablece la contraseña de un usuario existente — [password] ya
  /// viene validado por el formulario que llama esto.
  Future<void> resetPassword(String userId, String password);
}
