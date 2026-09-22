import 'package:flutter/material.dart';

import '../../app/auth_controller.dart';

/// Ver docs/adr/0019-cardholder-self-activation.md y
/// docs/feature/activacion-de-tarjetahabiente/README.md. Disponible en
/// web y mobile por igual — es el mismo código Flutter (ADR-0002).
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key, required this.controller});

  final CardholderAuthController controller;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _idDocumentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _idDocumentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.activate(
      email: _emailController.text.trim(),
      idDocumentNumber: _idDocumentController.text.trim(),
      password: _passwordController.text,
    );
    // Activar deja una sesión igual que login — cierra esta pantalla para
    // que se vea el HomeShell que app.dart ya reconstruyó debajo, ver
    // app/app.dart.
    if (widget.controller.session != null && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text('Activar cuenta'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Activa tu cuenta',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa los mismos datos que ya registró tu administrador '
                          'y elige tu propia contraseña.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _idDocumentController,
                          decoration: const InputDecoration(
                            labelText: 'Número de identificación oficial',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value == null || value.isEmpty) ? 'Ingresa tu número de identificación' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder()),
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Elige una contraseña';
                            if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirma tu contraseña',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (value) =>
                              value != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (widget.controller.error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.controller.error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: widget.controller.isLoading ? null : _submit,
                          child: widget.controller.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Activar cuenta'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            widget.controller.clearError();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Volver a iniciar sesión'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
