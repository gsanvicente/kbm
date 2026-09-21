import 'package:flutter/material.dart';

/// Diálogo dedicado para restablecer la contraseña de un usuario de
/// staff — StatefulWidget propio que posee y libera sus propios
/// controllers en su propio dispose(), en vez de crearlos en el método
/// que abre el diálogo (ver la lección de
/// _MaxActiveCardsDialog en client_detail_view.dart: un TextEditingController
/// creado fuera y liberado justo después de que showDialog() resuelve
/// puede seguir en uso mientras la ruta todavía está en su transición de
/// salida).
class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, required this.userEmail});

  final String userEmail;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  late final _passwordController = TextEditingController();
  late final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restablecer contraseña'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuario: ${widget.userEmail}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Restablecer')),
      ],
    );
  }
}
