import '../../core/models/card_status.dart';
import '../../core/models/client_dashboard_row.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/collector_deposit_status.dart';
import '../../core/models/dashboard_summary.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/session.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import '../treasury/treasury_repository.dart';
import 'dashboard_repository.dart';

/// Compone los repositorios fake ya existentes — no tiene datos propios.
/// Ver docs/feature/panel-directivo/README.md.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({
    required this.clientRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.treasuryRepository,
    required this.balanceOperationRepository,
  });

  final ClientRepository clientRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final TreasuryRepository treasuryRepository;
  final BalanceOperationRepository balanceOperationRepository;

  static const _attentionLimit = 5;

  @override
  Future<DashboardSummary> getSummary(Session session) async {
    final clients = await clientRepository.listAccessibleClients(session);
    final clientIds = clients.map((c) => c.id).toList();

    final cards = await cardRepository.listByClients(clientIds);
    final ledgerAccounts = await ledgerRepository.getByCards(cards.map((c) => c.id).toList());
    final operations = await balanceOperationRepository.listByClients(clientIds);
    final weeklyTrend = await balanceOperationRepository.getWeeklyTrend(clientIds);

    var concentratorTotal = 0.0;
    final concentratorByClient = <String, double>{};
    for (final clientId in clientIds) {
      final account = await treasuryRepository.getConcentratorAccount(clientId);
      if (account != null) {
        concentratorTotal += account.balance;
        concentratorByClient[clientId] = account.balance;
      }
    }

    final cardBalanceTotal = ledgerAccounts.values.fold(0.0, (sum, a) => sum + a.balance);

    var pendingDepositsCount = 0;
    var pendingDepositsAmount = 0.0;
    final pendingDepositsByClient = <String, int>{};
    final allPendingDeposits = <CollectorDeposit>[];
    for (final clientId in clientIds) {
      final deposits = await treasuryRepository.listCollectorDeposits(clientId);
      final pending = deposits.where((d) => d.status == CollectorDepositStatus.pending).toList();
      pendingDepositsByClient[clientId] = pending.length;
      pendingDepositsCount += pending.length;
      for (final deposit in pending) {
        pendingDepositsAmount += deposit.amount;
        allPendingDeposits.add(deposit);
      }
    }
    allPendingDeposits.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // `operations` ya viene ordenada más reciente primero (contrato de
    // BalanceOperationRepository.listByClients), así que estos filtros
    // conservan ese orden sin necesidad de re-ordenar.
    final pendingOps = operations.where((op) => op.status == OperationStatus.pendingApproval).toList();
    final pendingOperationsAmount = pendingOps.fold(0.0, (sum, op) => sum + op.amount);
    final pendingOperationsByClient = <String, int>{};
    for (final op in pendingOps) {
      pendingOperationsByClient[op.clientId] = (pendingOperationsByClient[op.clientId] ?? 0) + 1;
    }

    var executedDispersionTotal = 0.0;
    var executedDeduccionTotal = 0.0;
    var executedTransferenciaTotal = 0.0;
    for (final op in operations) {
      if (op.status != OperationStatus.executed) continue;
      switch (op.type) {
        case OperationType.load:
          executedDispersionTotal += op.amount;
        case OperationType.debit:
          executedDeduccionTotal += op.amount;
        case OperationType.transfer:
          executedTransferenciaTotal += op.amount;
      }
    }

    var activeCardsCount = 0;
    var availableCardsCount = 0;
    var blockedOrFrozenCardsCount = 0;
    final activeCardsByClient = <String, int>{};
    for (final card in cards) {
      switch (card.status) {
        case CardStatus.active:
          activeCardsCount++;
          activeCardsByClient[card.clientId] = (activeCardsByClient[card.clientId] ?? 0) + 1;
        case CardStatus.unassigned:
          availableCardsCount++;
        case CardStatus.blocked:
        case CardStatus.frozen:
          blockedOrFrozenCardsCount++;
        case CardStatus.cancelled:
          break;
      }
    }

    // Reclamos abiertos: tarjeta -> cuenta -> movimientos -> reclamo. No
    // hay un "listClaimsByClients" dedicado — se recorre con lo que ya
    // expone LedgerRepository en vez de agregar un método nuevo solo para
    // este conteo.
    var openClaimsCount = 0;
    for (final account in ledgerAccounts.values) {
      final entries = await ledgerRepository.listEntries(account.id);
      final claims = await ledgerRepository.getClaims(entries.map((e) => e.id).toList());
      openClaimsCount += claims.values.where((c) => !c.status.isResolved).length;
    }

    final clientBreakdown = clientIds.length > 1
        ? clients
            .map((c) => ClientDashboardRow(
                  clientId: c.id,
                  clientName: c.name,
                  concentratorBalance: concentratorByClient[c.id] ?? 0,
                  activeCardsCount: activeCardsByClient[c.id] ?? 0,
                  pendingOperationsCount: pendingOperationsByClient[c.id] ?? 0,
                  pendingDepositsCount: pendingDepositsByClient[c.id] ?? 0,
                ))
            .toList()
        : const <ClientDashboardRow>[];

    return DashboardSummary(
      currency: 'MXN',
      concentratorBalanceTotal: concentratorTotal,
      cardBalanceTotal: cardBalanceTotal,
      pendingDepositsCount: pendingDepositsCount,
      pendingDepositsAmount: pendingDepositsAmount,
      pendingOperationsCount: pendingOps.length,
      pendingOperationsAmount: pendingOperationsAmount,
      openClaimsCount: openClaimsCount,
      activeCardsCount: activeCardsCount,
      availableCardsCount: availableCardsCount,
      blockedOrFrozenCardsCount: blockedOrFrozenCardsCount,
      executedDispersionTotal: executedDispersionTotal,
      executedDeduccionTotal: executedDeduccionTotal,
      executedTransferenciaTotal: executedTransferenciaTotal,
      clientBreakdown: clientBreakdown,
      attentionPendingOperations: pendingOps.take(_attentionLimit).toList(),
      attentionPendingDeposits: allPendingDeposits.take(_attentionLimit).toList(),
      weeklyTrend: weeklyTrend,
    );
  }
}
