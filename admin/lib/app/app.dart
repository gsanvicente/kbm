import 'package:flutter/material.dart';

import '../core/http/kbm_backend_client.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/balance_operations/fake_balance_operation_repository.dart';
import '../features/cardholders/fake_cardholder_repository.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/fake_card_repository.dart';
import '../features/cards/http_card_repository.dart';
import '../features/clients/fake_client_repository.dart';
import '../features/dashboard/fake_dashboard_repository.dart';
import '../features/ledger/fake_ledger_repository.dart';
import '../features/ledger/http_ledger_repository.dart';
import '../features/ledger/ledger_repository.dart';
import '../features/treasury/fake_treasury_repository.dart';
import 'admin_shell.dart';
import 'auth_controller.dart';
import 'theme.dart';

class KbmAdminApp extends StatefulWidget {
  const KbmAdminApp({super.key, this.backendClient});

  /// Cuando es null (usado por los widget tests), Cards/Ledger corren
  /// 100% en memoria vía Fake*Repository, igual que el resto de los
  /// dominios — necesario porque `flutter test` intercepta todo
  /// `HttpClient` y siempre responde 400, por diseño de
  /// TestWidgetsFlutterBinding: un backend real es imposible de ejercer
  /// ahí. Cuando no es null (ver `main.dart`), Cards/Ledger se conectan
  /// al backend compartido con `cardholder/` — ver
  /// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
  final KbmBackendClient? backendClient;

  @override
  State<KbmAdminApp> createState() => _KbmAdminAppState();
}

class _KbmAdminAppState extends State<KbmAdminApp> {
  // Cliente y Tarjetahabiente (jerarquía, KYC, Tesorería, aprobaciones,
  // reclamos) se quedan 100% fake en esta iteración — fuera de alcance de
  // docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
  final _clientRepository = FakeClientRepository();
  late final _authController = AuthController(FakeAuthRepository(clientRepository: _clientRepository));
  // `_cardholderRepository` invoca `_cardRepository` en su callback de
  // desactivación, y `_cardRepository` recibe `_cardholderRepository` en
  // su constructor — referencia mutua resuelta con `late final`: el
  // closure de abajo no evalúa `_cardRepository` hasta que alguien
  // realmente desactiva a un Tarjetahabiente, momento en el que ambos ya
  // están construidos. Ver docs/business/desactivacion-de-tarjetahabientes.md.
  late final FakeCardholderRepository _cardholderRepository = FakeCardholderRepository(
    onDeactivated: (id) => _cardRepository.freezeAllForCardholder(id),
  );
  late final CardRepository _cardRepository = widget.backendClient != null
      ? HttpCardRepository(
          client: widget.backendClient!,
          clientRepository: _clientRepository,
          cardholderRepository: _cardholderRepository,
        )
      : FakeCardRepository(
          clientRepository: _clientRepository,
          cardholderRepository: _cardholderRepository,
        );
  late final LedgerRepository _ledgerRepository = widget.backendClient != null
      ? HttpLedgerRepository(
          client: widget.backendClient!,
          cardRepository: _cardRepository,
          clientRepository: _clientRepository,
        )
      : FakeLedgerRepository(
          cardRepository: _cardRepository,
          clientRepository: _clientRepository,
        );
  late final _treasuryRepository = FakeTreasuryRepository(clientRepository: _clientRepository);
  late final _balanceOperationRepository = FakeBalanceOperationRepository(
    ledgerRepository: _ledgerRepository,
    treasuryRepository: _treasuryRepository,
    clientRepository: _clientRepository,
  );
  late final _dashboardRepository = FakeDashboardRepository(
    clientRepository: _clientRepository,
    cardRepository: _cardRepository,
    ledgerRepository: _ledgerRepository,
    treasuryRepository: _treasuryRepository,
    balanceOperationRepository: _balanceOperationRepository,
  );

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
            cardholderRepository: _cardholderRepository,
            cardRepository: _cardRepository,
            ledgerRepository: _ledgerRepository,
            balanceOperationRepository: _balanceOperationRepository,
            treasuryRepository: _treasuryRepository,
            dashboardRepository: _dashboardRepository,
            authController: _authController,
          );
        },
      ),
    );
  }
}
