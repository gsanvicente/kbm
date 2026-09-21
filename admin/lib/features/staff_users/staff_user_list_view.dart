import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/session.dart';
import '../../core/models/staff_user.dart';
import '../../shared_widgets/confirm_dialog.dart';
import 'reset_password_dialog.dart';
import 'staff_user_form_dialog.dart';
import 'staff_user_repository.dart';

/// Listado de usuarios de staff de un único Cliente, con alta/edición/
/// desactivación — ver docs/feature/gestion-de-usuarios-staff/README.md.
/// Mismo criterio de alcance que Tarjetahabientes: embebido en la
/// pestaña "Usuarios" del detalle de un Cliente, nunca un directorio
/// global (ver la regla de UX del proyecto sobre no exponer
/// directorios sueltos).
class StaffUserListView extends StatefulWidget {
  const StaffUserListView({super.key, required this.repository, required this.clientId, required this.session});

  final StaffUserRepository repository;
  final String clientId;
  final Session session;

  @override
  State<StaffUserListView> createState() => _StaffUserListViewState();
}

class _StaffUserListViewState extends State<StaffUserListView> {
  late Future<List<StaffUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listByClient(widget.clientId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.listByClient(widget.clientId);
    });
  }

  Future<void> _createStaffUser() async {
    final result = await showDialog<StaffUserFormResult>(
      context: context,
      builder: (context) => const StaffUserFormDialog(),
    );
    if (result == null) return;

    try {
      await widget.repository.create(
        clientId: widget.clientId,
        email: result.email,
        fullName: result.fullName,
        role: result.role,
        password: result.password!,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado.')));
    } on EmailAlreadyExistsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editStaffUser(StaffUser user) async {
    final result = await showDialog<StaffUserFormResult>(
      context: context,
      builder: (context) => StaffUserFormDialog(staffUser: user),
    );
    if (result == null) return;

    await widget.repository.update(user.copyWith(fullName: result.fullName, role: result.role));
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado.')));
  }

  Future<void> _resetPassword(StaffUser user) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => ResetPasswordDialog(userEmail: user.email),
    );
    if (password == null) return;

    await widget.repository.resetPassword(user.id, password);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña restablecida.')));
  }

  Future<void> _toggleActive(StaffUser user) async {
    final activating = !user.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activating ? 'Reactivar usuario' : 'Desactivar usuario',
      message: activating
          ? '${user.fullName} podrá volver a iniciar sesión.'
          : '${user.fullName} ya no podrá iniciar sesión.',
      confirmLabel: activating ? 'Reactivar' : 'Desactivar',
      destructive: !activating,
    );
    if (!confirmed) return;

    await widget.repository.setActive(user.id, activating);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StaffUser>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar usuarios: ${snapshot.error}'));
        }

        final users = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _createStaffUser,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Nuevo usuario'),
                ),
              ),
            ),
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Este cliente no tiene usuarios de staff propios',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isSelf = user.id == widget.session.userId;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KoonsColors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded, color: KoonsColors.blue, size: 20),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (!user.isActive) ...[
                                const SizedBox(width: 8),
                                _Chip(label: 'Inactivo', color: Colors.red.shade700, background: Colors.red.shade50),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${user.email} · ${user.role.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _editStaffUser(user);
                                case 'reset-password':
                                  _resetPassword(user);
                                case 'toggle-active':
                                  _toggleActive(user);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                              const PopupMenuItem(value: 'reset-password', child: Text('Restablecer contraseña')),
                              // Nunca permitir que alguien se desactive a
                              // sí mismo desde su propia lista — mismo
                              // criterio que el backend ya exige
                              // (docs/feature/gestion-de-usuarios-staff/README.md).
                              if (!isSelf)
                                PopupMenuItem(
                                  value: 'toggle-active',
                                  child: Text(user.isActive ? 'Desactivar' : 'Reactivar'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
