import 'role.dart';

class Session {
  final String userId;
  final String email;
  final Role role;
  final String? clientId; // null only for Role.superAdmin

  const Session({
    required this.userId,
    required this.email,
    required this.role,
    this.clientId,
  });
}
