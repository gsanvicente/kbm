import 'package:flutter/material.dart';

import '../../core/models/role.dart';
import '../../core/models/staff_user.dart';

/// Roles asignables desde esta pantalla — Super Admin nunca aparece
/// aquí, sin importar quién esté creando (Super Admin o Admin Cliente):
/// no es un rol que se dé de alta por autoservicio. Ver
/// docs/business/gestion-de-usuarios-staff.md, "Quién puede crear a
/// quién".
const _assignableRoles = [Role.clientAdmin, Role.operator, Role.auditor];

/// Resultado de [StaffUserFormDialog] — [password] es null al editar
/// (la contraseña se cambia por separado, ver ResetPasswordDialog).
class StaffUserFormResult {
  const StaffUserFormResult({required this.email, required this.fullName, required this.role, this.password});
  final String email;
  final String fullName;
  final Role role;
  final String? password;
}

/// Diálogo de alta/edición de un usuario de staff — ver
/// docs/feature/gestion-de-usuarios-staff/README.md. [staffUser] `null`
/// significa alta; no-`null` significa edición (email queda fijo, sin
/// campo de contraseña).
class StaffUserFormDialog extends StatefulWidget {
  const StaffUserFormDialog({super.key, this.staffUser});

  final StaffUser? staffUser;

  @override
  State<StaffUserFormDialog> createState() => _StaffUserFormDialogState();
}

class _StaffUserFormDialogState extends State<StaffUserFormDialog> {
  StaffUser? get _seed => widget.staffUser;
  bool get _isEditing => _seed != null;

  late final _emailController = TextEditingController(text: _seed?.email ?? '');
  late final _fullNameController = TextEditingController(text: _seed?.fullName ?? '');
  late final _passwordController = TextEditingController();
  late final _confirmPasswordController = TextEditingController();

  late Role _role = _seed?.role ?? Role.operator;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validate() {
    if (_fullNameController.text.trim().isEmpty) {
      return 'El nombre completo es obligatorio.';
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'El email no tiene un formato válido.';
    }
    if (!_isEditing) {
      final password = _passwordController.text;
      if (password.length < 8) {
        return 'La contraseña debe tener al menos 8 caracteres.';
      }
      if (password != _confirmPasswordController.text) {
        return 'Las contraseñas no coinciden.';
      }
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      StaffUserFormResult(
        email: _emailController.text.trim(),
        fullName: _fullNameController.text.trim(),
        role: _role,
        password: _isEditing ? null : _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                enabled: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: _isEditing ? 'El email no se puede cambiar' : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Role>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: [
                  for (final role in _assignableRoles) DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(_isEditing ? 'Guardar' : 'Crear')),
      ],
    );
  }
}
