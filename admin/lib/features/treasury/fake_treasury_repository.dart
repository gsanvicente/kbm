import '../../core/models/collector_deposit.dart';
import '../../core/models/collector_deposit_status.dart';
import '../../core/models/concentrator_account.dart';
import '../../core/models/concentrator_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../clients/client_repository.dart';
import 'treasury_repository.dart';

/// In-memory stand-in for the Concentradora/Colectora endpoints — same
/// seed data as backend/scripts/init-db/001_seed.sql.
class FakeTreasuryRepository implements TreasuryRepository {
  FakeTreasuryRepository({required this.clientRepository});

  /// Para verificar, en `registerDeposit`/`reconcileDeposit`, que el
  /// Cliente pueda operar — ver
  /// docs/business/desactivacion-de-clientes.md, "Capa 2".
  final ClientRepository clientRepository;

  final _concentratorByClient = {
    '00000000-0000-0000-0000-000000000002': const ConcentratorAccount(
      id: '90000000-0000-0000-0000-000000000001',
      clientId: '00000000-0000-0000-0000-000000000002',
      currency: 'MXN',
      balance: 10000.00,
    ),
    '00000000-0000-0000-0000-000000000003': const ConcentratorAccount(
      id: '90000000-0000-0000-0000-000000000002',
      clientId: '00000000-0000-0000-0000-000000000003',
      currency: 'MXN',
      balance: 10000.00,
    ),
  };

  final List<ConcentratorEntry> _entries = [
    ConcentratorEntry(
      id: '91000000-0000-0000-0000-000000000001',
      concentratorAccountId: '90000000-0000-0000-0000-000000000001',
      type: LedgerEntryType.credit,
      amount: 10000.00,
      balanceAfter: 10000.00,
      description: 'Saldo inicial de demo',
      createdAt: DateTime(2026, 1, 5, 9, 0),
    ),
    ConcentratorEntry(
      id: '91000000-0000-0000-0000-000000000002',
      concentratorAccountId: '90000000-0000-0000-0000-000000000002',
      type: LedgerEntryType.credit,
      amount: 10000.00,
      balanceAfter: 10000.00,
      description: 'Saldo inicial de demo',
      createdAt: DateTime(2026, 1, 5, 9, 0),
    ),
  ];

  // Demo: a deposit still pending reconciliation in Subsidiaria A's
  // Colectora, so "Tesorería" has something to show on first load.
  final List<CollectorDeposit> _deposits = [
    CollectorDeposit(
      id: '92000000-0000-0000-0000-000000000001',
      clientId: '00000000-0000-0000-0000-000000000002',
      amount: 5000.00,
      reference: 'SPEI-DEMO-001',
      status: CollectorDepositStatus.pending,
      registeredByEmail: 'operador.subA@koons.test',
      createdAt: DateTime(2026, 1, 22, 10, 0),
    ),
  ];

  @override
  Future<ConcentratorAccount?> getConcentratorAccount(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _concentratorByClient[clientId];
  }

  @override
  Future<List<ConcentratorEntry>> listConcentratorEntries(String concentratorAccountId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final entries = _entries.where((e) => e.concentratorAccountId == concentratorAccountId).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<ConcentratorEntry> postConcentratorEntry({
    required String concentratorAccountId,
    required LedgerEntryType type,
    required double amount,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final clientId = _concentratorByClient.entries
        .firstWhere((e) => e.value.id == concentratorAccountId,
            orElse: () => throw NotFoundException('Cuenta Concentradora $concentratorAccountId no encontrada'))
        .key;
    final account = _concentratorByClient[clientId]!;

    final newBalance = type == LedgerEntryType.credit ? account.balance + amount : account.balance - amount;
    if (newBalance < 0) {
      throw InsufficientFundsException(currentBalance: account.balance, requestedAmount: amount);
    }

    final entry = ConcentratorEntry(
      id: 'centry-${DateTime.now().microsecondsSinceEpoch}',
      concentratorAccountId: concentratorAccountId,
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      description: description,
      createdAt: DateTime.now(),
    );
    _entries.add(entry);
    _concentratorByClient[clientId] = account.copyWith(balance: newBalance);
    return entry;
  }

  @override
  Future<List<CollectorDeposit>> listCollectorDeposits(String clientId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final deposits = _deposits.where((d) => d.clientId == clientId).toList();
    deposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deposits;
  }

  @override
  Future<CollectorDeposit> registerDeposit({
    required String clientId,
    required double amount,
    required String reference,
    required String registeredByEmail,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!await clientRepository.isOperable(clientId)) {
      throw const ClientInactiveException();
    }
    final deposit = CollectorDeposit(
      id: 'deposit-${DateTime.now().microsecondsSinceEpoch}',
      clientId: clientId,
      amount: amount,
      reference: reference,
      status: CollectorDepositStatus.pending,
      registeredByEmail: registeredByEmail,
      createdAt: DateTime.now(),
    );
    _deposits.add(deposit);
    return deposit;
  }

  @override
  Future<CollectorDeposit> reconcileDeposit({
    required String depositId,
    required String reconciledByEmail,
  }) async {
    final index = _deposits.indexWhere((d) => d.id == depositId);
    if (index == -1) throw NotFoundException('Depósito $depositId no encontrado');
    final deposit = _deposits[index];
    if (!await clientRepository.isOperable(deposit.clientId)) {
      throw const ClientInactiveException();
    }
    if (deposit.status == CollectorDepositStatus.reconciled) {
      throw StateError('Este depósito ya fue conciliado.');
    }

    final account = _concentratorByClient[deposit.clientId];
    if (account == null) throw NotFoundException('El Cliente ${deposit.clientId} no tiene Cuenta Concentradora');
    await postConcentratorEntry(
      concentratorAccountId: account.id,
      type: LedgerEntryType.credit,
      amount: deposit.amount,
      description: 'Conciliación de depósito ${deposit.reference}',
    );

    final reconciled = deposit.copyWith(
      status: CollectorDepositStatus.reconciled,
      reconciledByEmail: reconciledByEmail,
      reconciledAt: DateTime.now(),
    );
    _deposits[index] = reconciled;
    return reconciled;
  }
}
