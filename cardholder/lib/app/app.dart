import 'package:flutter/material.dart';

import '../core/fake_backend.dart';
import '../core/http/kbm_backend_client.dart';
import '../core/http_backend.dart';
import '../features/auth/cardholder_auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/cards/card_repository.dart';
import '../features/spei/spei_repository.dart';
import '../features/transfer/transfer_repository.dart';
import 'auth_controller.dart';
import 'home_shell.dart';
import 'theme.dart';

class KbmCardholderApp extends StatefulWidget {
  const KbmCardholderApp({super.key, this.backendClient});

  /// Cuando es null (usado por los widget tests), corre 100% en memoria
  /// vía `FakeCardholderBackend` — necesario porque `flutter test`
  /// intercepta todo `HttpClient` y siempre responde 400, por diseño de
  /// TestWidgetsFlutterBinding: un backend real es imposible de ejercer
  /// ahí. Cuando no es null (ver `main.dart`), se conecta al backend
  /// compartido con `admin/` — ver
  /// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
  final KbmBackendClient? backendClient;

  @override
  State<KbmCardholderApp> createState() => _KbmCardholderAppState();
}

class _KbmCardholderAppState extends State<KbmCardholderApp> {
  // Universo de datos propio, sin relación en tiempo de ejecución con
  // `admin/` más allá del backend compartido (ADR-0002).
  late final CardholderAuthRepository _authRepository;
  late final CardRepository _cardRepository;
  late final TransferRepository _transferRepository;
  late final SpeiRepository _speiRepository;
  late final _authController = CardholderAuthController(_authRepository);

  @override
  void initState() {
    super.initState();
    final backendClient = widget.backendClient;
    if (backendClient != null) {
      final backend = HttpCardholderBackend(backendClient);
      _authRepository = backend;
      _cardRepository = backend;
      _transferRepository = backend;
      _speiRepository = backend;
    } else {
      final backend = FakeCardholderBackend();
      _authRepository = backend;
      _cardRepository = backend;
      _transferRepository = backend;
      _speiRepository = backend;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBM',
      debugShowCheckedModeBanner: false,
      theme: buildKbmCardholderTheme(),
      home: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) {
          final session = _authController.session;
          if (session == null) {
            return LoginScreen(controller: _authController);
          }
          return HomeShell(
            session: session,
            cardRepository: _cardRepository,
            transferRepository: _transferRepository,
            speiRepository: _speiRepository,
            onLogout: _authController.logout,
          );
        },
      ),
    );
  }
}
