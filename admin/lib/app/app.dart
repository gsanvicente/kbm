import 'package:flutter/material.dart';

import '../features/auth/fake_auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/balance_operations/fake_balance_operation_repository.dart';
import '../features/cardholders/fake_cardholder_repository.dart';
import '../features/cards/fake_card_repository.dart';
import '../features/clients/fake_client_repository.dart';
import '../features/dashboard/fake_dashboard_repository.dart';
import '../features/ledger/fake_ledger_repository.dart';
import '../features/treasury/fake_treasury_repository.dart';
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
  late final FakeCardRepository _cardRepository = FakeCardRepository(
    clientRepository: _clientRepository,
    cardholderRepository: _cardholderRepository,
  );
  late final _ledgerRepository = FakeLedgerRepository(
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
