import 'package:flutter/material.dart';

import '../core/http/kbm_backend_client.dart';
import '../core/models/cardholder.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/auth/http_auth_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/balance_operations/balance_operation_repository.dart';
import '../features/balance_operations/fake_balance_operation_repository.dart';
import '../features/balance_operations/http_balance_operation_repository.dart';
import '../features/cardholders/cardholder_repository.dart';
import '../features/cardholders/fake_cardholder_repository.dart';
import '../features/cardholders/http_cardholder_repository.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/fake_card_repository.dart';
import '../features/cards/http_card_repository.dart';
import '../features/clients/client_repository.dart';
import '../features/clients/fake_client_repository.dart';
import '../features/clients/http_client_repository.dart';
import '../features/dashboard/fake_dashboard_repository.dart';
import '../features/ledger/fake_ledger_repository.dart';
import '../features/ledger/http_ledger_repository.dart';
import '../features/ledger/ledger_repository.dart';
import '../features/spei/fake_spei_repository.dart';
import '../features/spei/http_spei_repository.dart';
import '../features/spei/spei_repository.dart';
import '../features/staff_users/fake_staff_user_repository.dart';
import '../features/staff_users/http_staff_user_repository.dart';
import '../features/staff_users/staff_user_repository.dart';
import '../features/treasury/fake_treasury_repository.dart';
import '../features/treasury/http_treasury_repository.dart';
import '../features/treasury/treasury_repository.dart';
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
  // Clientes, Tarjetahabientes (KYC), Tesorería, login administrativo,
  // Aprobaciones y Reclamos migraron a Postgres en
  // docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md
  // — cuando widget.backendClient es null (tests, ver KbmAdminApp), todo
  // sigue corriendo 100% en memoria vía Fake*Repository, exactamente
  // igual que antes de esa ADR.
  late final ClientRepository _clientRepository =
      widget.backendClient != null ? HttpClientRepository(client: widget.backendClient!) : FakeClientRepository();
  late final AuthRepository _authRepository = widget.backendClient != null
      ? HttpAuthRepository(client: widget.backendClient!)
      : FakeAuthRepository(clientRepository: _clientRepository);
  late final _authController = AuthController(_authRepository);
  // `_cardholderRepository` invoca `_cardRepository` en su callback de
  // desactivación, y `_cardRepository` recibe `_cardholderRepository` en
  // su constructor — referencia mutua resuelta con `late final`: el
  // closure de abajo no evalúa `_cardRepository` hasta que alguien
  // realmente desactiva a un Tarjetahabiente, momento en el que ambos ya
  // están construidos. Ver docs/business/desactivacion-de-tarjetahabientes.md.
  // El backend Postgres no dispara ese congelamiento por su cuenta (Cards
  // y Cardholders siguen siendo dominios desacoplados ahí también) — el
  // decorador de abajo replica el mismo hook para HttpCardholderRepository.
  late final CardholderRepository _cardholderRepository = widget.backendClient != null
      ? _CardholderRepositoryWithCardFreeze(
          inner: HttpCardholderRepository(client: widget.backendClient!),
          onDeactivated: (id) => _cardRepository.freezeAllForCardholder(id),
        )
      : FakeCardholderRepository(
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
  late final TreasuryRepository _treasuryRepository = widget.backendClient != null
      ? HttpTreasuryRepository(client: widget.backendClient!)
      : FakeTreasuryRepository(clientRepository: _clientRepository);
  late final BalanceOperationRepository _balanceOperationRepository = widget.backendClient != null
      ? HttpBalanceOperationRepository(client: widget.backendClient!)
      : FakeBalanceOperationRepository(
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
  late final StaffUserRepository _staffUserRepository =
      widget.backendClient != null ? HttpStaffUserRepository(client: widget.backendClient!) : FakeStaffUserRepository();
  late final SpeiRepository _speiRepository =
      widget.backendClient != null ? HttpSpeiRepository(client: widget.backendClient!) : FakeSpeiRepository();

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
            staffUserRepository: _staffUserRepository,
            speiRepository: _speiRepository,
            authController: _authController,
          );
        },
      ),
    );
  }
}

/// Envuelve cualquier `CardholderRepository` para disparar
/// [onDeactivated] justo después de un `setActive(id, false)` exitoso —
/// mismo hook que `FakeCardholderRepository` ya trae integrado
/// (`onDeactivated`), aquí como decorador porque
/// `HttpCardholderRepository` no lo necesita para nada más y no vale la
/// pena ensuciar su constructor solo por este caso de uso de `app.dart`.
/// Ver docs/business/desactivacion-de-tarjetahabientes.md.
class _CardholderRepositoryWithCardFreeze implements CardholderRepository {
  _CardholderRepositoryWithCardFreeze({required this.inner, required this.onDeactivated});

  final CardholderRepository inner;
  final Future<void> Function(String cardholderId) onDeactivated;

  @override
  Future<List<Cardholder>> listByClient(String clientId) => inner.listByClient(clientId);

  @override
  Future<List<Cardholder>> listByClients(List<String> clientIds) => inner.listByClients(clientIds);

  @override
  Future<Cardholder?> getById(String cardholderId) => inner.getById(cardholderId);

  @override
  Future<Cardholder> create(Cardholder draft) => inner.create(draft);

  @override
  Future<Cardholder> update(Cardholder cardholder) => inner.update(cardholder);

  @override
  Future<bool> isOperable(String cardholderId) => inner.isOperable(cardholderId);

  @override
  Future<Cardholder> setActive(String cardholderId, bool isActive) async {
    final updated = await inner.setActive(cardholderId, isActive);
    if (!isActive) await onDeactivated(cardholderId);
    return updated;
  }
}
