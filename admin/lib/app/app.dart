import 'package:flutter/material.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/clients/fake_client_repository.dart';
import 'admin_shell.dart';
import 'auth_controller.dart';
import 'theme.dart';

class KbmAdminApp extends StatefulWidget {
  const KbmAdminApp({super.key});

  @override
  State<KbmAdminApp> createState() => _KbmAdminAppState();
}

class _KbmAdminAppState extends State<KbmAdminApp> {
  // Fake in-memory implementations for this iteration — see
  // docs/feature/login-administrativo/README.md and
  // docs/feature/panel-principal-admin/README.md for the scope note on
  // swapping these for the real HTTP-backed repositories.
  late final _authController = AuthController(FakeAuthRepository());
  final _clientRepository = FakeClientRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBM Admin',
      debugShowCheckedModeBanner: false,
      theme: buildKbmAdminTheme(),
      home: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) {
          final session = _authController.session;
          if (session == null) {
            return LoginScreen(controller: _authController);
          }
          return AdminShell(
            session: session,
            clientRepository: _clientRepository,
            authController: _authController,
          );
        },
      ),
    );
  }
}
