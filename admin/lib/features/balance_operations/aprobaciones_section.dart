import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/collector_deposit_status.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../core/models/spei_payment.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/confirm_dialog.dart';
import '../../shared_widgets/multi_select_filter_button.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import '../spei/spei_repository.dart';
import '../treasury/deposit_tile.dart';
import '../treasury/treasury_repository.dart';
import 'balance_operation_repository.dart';
import 'operaciones_de_saldo_section.dart';

/// Hub de todo lo relacionado a operaciones de saldo, con tres pestañas:
/// pendientes de aprobación, depósitos de Colectora pendientes de
/// conciliar, e historial completo (cualquier estado, con filtros —
/// antes una sección aparte, "Operaciones de saldo"; se fusionó aquí
/// 2026-09-17 porque tener dos ítems de menú separados sobre lo mismo no
/// aportaba, y ahora es un solo punto de entrada para todo lo de
/// operaciones/depósitos). Aprobar y conciliar son acciones de negocio
/// distintas a propósito (aprobar autoriza una ejecución; conciliar
/// confirma un hecho externo — ver docs/security/threat-model.md punto
/// 10), por eso viven en pestañas separadas y no en una sola lista
/// mezclada. Conciliar sigue disponible también desde la Tesorería de
/// cada Cliente — ver docs/feature/tesoreria-cliente/README.md, "Dos
/// entry points para conciliar". Ver
/// docs/feature/operacion-saldo-con-aprobacion/README.md.
class AprobacionesSection extends StatefulWidget {
  const AprobacionesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
    required this.treasuryRepository,
    required this.speiRepository,
    this.initialTabIndex = 0,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;
  final TreasuryRepository treasuryRepository;
  final SpeiRepository speiRepository;

  /// 0 = Pendientes de aprobación, 1 = Depósitos por conciliar, 2 =
  /// Historial completo, 3 = Pagos SPEI — usado por el hipervínculo de
  /// "Requiere tu atención" en el Panel directivo para abrir directo en
  /// la pestaña relevante (nunca apunta a la 2 ni a la 3, nada las
  /// enlaza todavía). Ver docs/feature/panel-directivo/README.md.
  final int initialTabIndex;

  @override
  State<AprobacionesSection> createState() => _AprobacionesSectionState();
}

class _AprobacionesSectionState extends State<AprobacionesSection> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: KoonsColors.navy,
            indicatorColor: KoonsColors.blue,
            tabs: const [
              Tab(text: 'Pendientes de aprobación'),
              Tab(text: 'Depósitos por conciliar'),
              Tab(text: 'Historial completo'),
              Tab(text: 'Pagos SPEI'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PendingOperationsTab(
                  session: widget.session,
                  clientRepository: widget.clientRepository,
                  cardholderRepository: widget.cardholderRepository,
                  cardRepository: widget.cardRepository,
                  ledgerRepository: widget.ledgerRepository,
                  balanceOperationRepository: widget.balanceOperationRepository,
                ),
                _PendingDepositsTab(
                  session: widget.session,
                  clientRepository: widget.clientRepository,
                  treasuryRepository: widget.treasuryRepository,
                ),
                _FullHistoryTab(
                  session: widget.session,
                  clientRepository: widget.clientRepository,
                  cardholderRepository: widget.cardholderRepository,
                  cardRepository: widget.cardRepository,
                  ledgerRepository: widget.ledgerRepository,
                  balanceOperationRepository: widget.balanceOperationRepository,
                ),
                _PendingSpeiPaymentsTab(
                  session: widget.session,
                  clientRepository: widget.clientRepository,
                  speiRepository: widget.speiRepository,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cola de operaciones `pending_approval` dentro del alcance del usuario.
/// Visible para todos (Auditor y Operador incluidos, de solo lectura),
/// pero solo Admin Cliente+ ve los botones de aprobar/rechazar. El
/// historial completo vive en OperacionesDeSaldoSection.
class _PendingOperationsTab extends StatefulWidget {
  const _PendingOperationsTab({
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;

  @override
  State<_PendingOperationsTab> createState() => _PendingOperationsTabState();
}

/// Compartida entre `_PendingOperationsTab` (solo pendientes) y
/// `_FullHistoryTab` (cualquier estado) — mismo shape, distinto método de
/// repositorio usado para poblar [operations].
class _ScopeData {
  _ScopeData(this.clients, this.cardholders, this.cards, this.ledgerAccounts, this.operations);
  final List<Client> clients;
  final List<Cardholder> cardholders;
  final List<PaymentCard> cards;
  final Map<String, LedgerAccount> ledgerAccounts;
  final List<BalanceOperation> operations;
}

class _PendingOperationsTabState extends State<_PendingOperationsTab> {
  late Future<_ScopeData> _future;
  bool _busyId(String id) => _busyOperationId == id;
  String? _busyOperationId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ScopeData> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final clientIds = clients.map((c) => c.id).toList();
    final cardholders = await widget.cardholderRepository.listByClients(clientIds);
    final cards = await widget.cardRepository.listByClients(clientIds);
    final ledgerAccounts = await widget.ledgerRepository.getByCards(cards.map((c) => c.id).toList());
    final pending = await widget.balanceOperationRepository.listPendingByClients(clientIds);
    return _ScopeData(clients, cardholders, cards, ledgerAccounts, pending);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _approve(
    BalanceOperation op, {
    required String clientName,
    required String currency,
    String? maskedPan,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Aprobar ${op.type.label.toLowerCase()}',
      message: '¿Deseas aprobar esta ${op.type.label} de ${formatCurrency(op.amount, currency)} '
          '${maskedPan != null ? 'a la tarjeta $maskedPan ' : ''}del Cliente $clientName? '
          'Se ejecutará de inmediato.',
    );
    if (!confirmed) return;

    setState(() => _busyOperationId = op.id);
    final result = await widget.balanceOperationRepository.approve(
      operationId: op.id,
      approvedByEmail: widget.session.email,
    );
    if (!mounted) return;
    setState(() => _busyOperationId = null);
    _reload();
    final message = result.status == OperationStatus.executed
        ? 'Operación aprobada y ejecutada.'
        : 'Operación fallida: ${result.resolutionNotes}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(BalanceOperation op) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busyOperationId = op.id);
    await widget.balanceOperationRepository.reject(
      operationId: op.id,
      rejectedByEmail: widget.session.email,
      reason: reason.trim(),
    );
    if (!mounted) return;
    setState(() => _busyOperationId = null);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operación rechazada.')));
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = widget.session.role.canApproveBalanceOperations;

    return FutureBuilder<_ScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar aprobaciones: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final clientNameById = {for (final c in data.clients) c.id: c.name};
        final cardById = {for (final c in data.cards) c.id: c};
        final cardholderNameById = {for (final c in data.cardholders) c.id: c.fullName};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canApprove)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Tu rol (${widget.session.role.label}) puede ver esta cola pero no aprobar ni rechazar.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: data.operations.isEmpty
                  ? Center(
                      child: Text(
                        'No hay operaciones pendientes de aprobación.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.operations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final op = data.operations[index];
                        final busy = _busyId(op.id);
                        return BalanceOperationTile(
                          operation: op,
                          card: cardById[op.cardId],
                          destinationCard: op.destinationCardId != null ? cardById[op.destinationCardId] : null,
                          cardholderName: cardById[op.cardId]?.cardholderId != null
                              ? cardholderNameById[cardById[op.cardId]!.cardholderId]
                              : null,
                          clientName: clientNameById[op.clientId] ?? '—',
                          currency: data.ledgerAccounts[op.cardId]?.currency ?? 'MXN',
                          trailing: canApprove
                              ? (busy
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Aprobar',
                                          icon: Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700),
                                          onPressed: () => _approve(
                                            op,
                                            clientName: clientNameById[op.clientId] ?? '—',
                                            currency: data.ledgerAccounts[op.cardId]?.currency ?? 'MXN',
                                            maskedPan: cardById[op.cardId]?.maskedPan,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Rechazar',
                                          icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                                          onPressed: () => _reject(op),
                                        ),
                                      ],
                                    ))
                              : null,
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

/// Historial de solo lectura de operaciones de saldo (cualquier estado)
/// dentro del alcance del usuario — crear una operación nueva se hace
/// desde la tarjeta específica (pestaña "Operaciones" de
/// CardDetailView), nunca desde aquí. Antes vivía en una sección aparte
/// ("Operaciones de saldo"); se fusionó a esta pestaña 2026-09-17, ver el
/// comentario de AprobacionesSection.
class _FullHistoryTab extends StatefulWidget {
  const _FullHistoryTab({
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;

  @override
  State<_FullHistoryTab> createState() => _FullHistoryTabState();
}

class _FullHistoryTabState extends State<_FullHistoryTab> {
  late Future<_ScopeData> _future;

  Set<OperationType> _typeFilter = {};
  Set<OperationStatus> _statusFilter = {};
  Set<String> _clientFilter = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ScopeData> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final clientIds = clients.map((c) => c.id).toList();
    final cardholders = await widget.cardholderRepository.listByClients(clientIds);
    final cards = await widget.cardRepository.listByClients(clientIds);
    final ledgerAccounts = await widget.ledgerRepository.getByCards(cards.map((c) => c.id).toList());
    final operations = await widget.balanceOperationRepository.listByClients(clientIds);
    return _ScopeData(clients, cardholders, cards, ledgerAccounts, operations);
  }

  bool get _hasActiveFilters => _typeFilter.isNotEmpty || _statusFilter.isNotEmpty || _clientFilter.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar operaciones: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final clientNameById = {for (final c in data.clients) c.id: c.name};
        final cardById = {for (final c in data.cards) c.id: c};
        final cardholderNameById = {for (final c in data.cardholders) c.id: c.fullName};

        final filtered = data.operations.where((op) {
          if (_typeFilter.isNotEmpty && !_typeFilter.contains(op.type)) return false;
          if (_statusFilter.isNotEmpty && !_statusFilter.contains(op.status)) return false;
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(op.clientId)) return false;
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MultiSelectFilterButton<OperationType>(
                    label: 'Tipo',
                    options: OperationType.values,
                    optionLabel: (t) => t.label,
                    selected: _typeFilter,
                    onChanged: (next) => setState(() => _typeFilter = next),
                  ),
                  MultiSelectFilterButton<OperationStatus>(
                    label: 'Estado',
                    options: OperationStatus.values,
                    optionLabel: (s) => s.label,
                    selected: _statusFilter,
                    onChanged: (next) => setState(() => _statusFilter = next),
                  ),
                  if (data.clients.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Empresa',
                      options: data.clients.map((c) => c.id).toList(),
                      optionLabel: (id) => clientNameById[id] ?? '—',
                      selected: _clientFilter,
                      onChanged: (next) => setState(() => _clientFilter = next),
                    ),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: () => setState(() {
                        _typeFilter = {};
                        _statusFilter = {};
                        _clientFilter = {};
                      }),
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        data.operations.isEmpty
                            ? 'Aún no hay operaciones de saldo. Se solicitan desde el detalle de cada tarjeta.'
                            : 'Ninguna operación coincide con los filtros',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final op = filtered[index];
                        return BalanceOperationTile(
                          operation: op,
                          card: cardById[op.cardId],
                          destinationCard: op.destinationCardId != null ? cardById[op.destinationCardId] : null,
                          cardholderName: cardById[op.cardId]?.cardholderId != null
                              ? cardholderNameById[cardById[op.cardId]!.cardholderId]
                              : null,
                          clientName: clientNameById[op.clientId] ?? '—',
                          currency: data.ledgerAccounts[op.cardId]?.currency ?? 'MXN',
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

class _PendingDepositsTab extends StatefulWidget {
  const _PendingDepositsTab({
    required this.session,
    required this.clientRepository,
    required this.treasuryRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final TreasuryRepository treasuryRepository;

  @override
  State<_PendingDepositsTab> createState() => _PendingDepositsTabState();
}

class _DepositsScopeData {
  _DepositsScopeData(this.clientNameById, this.pending);
  final Map<String, String> clientNameById;
  final List<CollectorDeposit> pending;
}

class _PendingDepositsTabState extends State<_PendingDepositsTab> {
  late Future<_DepositsScopeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DepositsScopeData> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final pending = <CollectorDeposit>[];
    for (final client in clients) {
      final deposits = await widget.treasuryRepository.listCollectorDeposits(client.id);
      pending.addAll(deposits.where((d) => d.status == CollectorDepositStatus.pending));
    }
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _DepositsScopeData({for (final c in clients) c.id: c.name}, pending);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _reconcile(CollectorDeposit deposit, {required String clientName, required String currency}) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Conciliar depósito',
      message: '¿Deseas conciliar el depósito de ${formatCurrency(deposit.amount, currency)} '
          'del Cliente $clientName? El saldo quedará disponible de inmediato en su Cuenta Concentradora.',
    );
    if (!confirmed) return;

    await widget.treasuryRepository.reconcileDeposit(
      depositId: deposit.id,
      reconciledByEmail: widget.session.email,
    );
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Depósito conciliado — saldo disponible en la Concentradora.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canReconcile = widget.session.role.canReconcileDeposits;

    return FutureBuilder<_DepositsScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar depósitos: ${snapshot.error}'));
        }
        final data = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canReconcile)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Tu rol (${widget.session.role.label}) puede ver esta cola pero no conciliar depósitos.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: data.pending.isEmpty
                  ? Center(
                      child: Text(
                        'No hay depósitos pendientes de conciliar.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final deposit = data.pending[index];
                        return DepositTile(
                          deposit: deposit,
                          currency: 'MXN',
                          clientName: data.clientNameById[deposit.clientId] ?? '—',
                          canReconcile: canReconcile,
                          onReconcile: () => _reconcile(
                            deposit,
                            clientName: data.clientNameById[deposit.clientId] ?? '—',
                            currency: 'MXN',
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

/// Cola de pagos SPEI `pending_approval` — mismo criterio de visibilidad
/// que _PendingOperationsTab (todo staff ve, solo manageRoles
/// aprueba/rechaza), pero sin origen desde una tarjeta: el alta la hace
/// el propio Tarjetahabiente desde `cardholder/`, ver
/// docs/adr/0021-conector-spei.md.
class _PendingSpeiPaymentsTab extends StatefulWidget {
  const _PendingSpeiPaymentsTab({
    required this.session,
    required this.clientRepository,
    required this.speiRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final SpeiRepository speiRepository;

  @override
  State<_PendingSpeiPaymentsTab> createState() => _PendingSpeiPaymentsTabState();
}

class _PendingSpeiPaymentsTabState extends State<_PendingSpeiPaymentsTab> {
  late Future<_SpeiScopeData> _future;
  String? _busyPaymentId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SpeiScopeData> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final clientIds = clients.map((c) => c.id).toList();
    final payments = await widget.speiRepository.listPendingByClients(clientIds);
    return _SpeiScopeData({for (final c in clients) c.id: c.name}, payments);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _approve(SpeiPayment payment, {required String clientName}) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Aprobar pago SPEI',
      message: '¿Deseas aprobar el pago de ${formatCurrency(payment.amount, 'MXN')} '
          'a ${payment.beneficiaryAlias} del Cliente $clientName? Se despacha al proveedor de inmediato.',
    );
    if (!confirmed) return;

    setState(() => _busyPaymentId = payment.id);
    final result = await widget.speiRepository.approve(paymentId: payment.id, approvedByEmail: widget.session.email);
    if (!mounted) return;
    setState(() => _busyPaymentId = null);
    _reload();
    final message = result.status == OperationStatus.executed
        ? 'Pago aprobado y enviado.'
        : 'Pago fallido: ${result.resolutionNotes}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(SpeiPayment payment) async {
    final reason = await showDialog<String>(context: context, builder: (context) => const _RejectDialog());
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busyPaymentId = payment.id);
    await widget.speiRepository.reject(paymentId: payment.id, rejectedByEmail: widget.session.email, reason: reason.trim());
    if (!mounted) return;
    setState(() => _busyPaymentId = null);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago rechazado.')));
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = widget.session.role.canApproveBalanceOperations;

    return FutureBuilder<_SpeiScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar pagos SPEI: ${snapshot.error}'));
        }
        final data = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canApprove)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Tu rol (${widget.session.role.label}) puede ver esta cola pero no aprobar ni rechazar.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: data.payments.isEmpty
                  ? Center(
                      child: Text(
                        'No hay pagos SPEI pendientes de aprobación.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.payments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final payment = data.payments[index];
                        final busy = _busyPaymentId == payment.id;
                        final clientName = data.clientNameById[payment.clientId] ?? '—';
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.send_rounded, size: 18)),
                          title: Text('${payment.requestedByFullName} → ${payment.beneficiaryAlias}'),
                          subtitle: Text('$clientName · ${payment.beneficiaryClabe}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatCurrency(payment.amount, 'MXN'),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: KoonsColors.navy),
                              ),
                              const SizedBox(width: 12),
                              if (canApprove)
                                busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Aprobar',
                                            icon: Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700),
                                            onPressed: () => _approve(payment, clientName: clientName),
                                          ),
                                          IconButton(
                                            tooltip: 'Rechazar',
                                            icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                                            onPressed: () => _reject(payment),
                                          ),
                                        ],
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

class _SpeiScopeData {
  _SpeiScopeData(this.clientNameById, this.payments);
  final Map<String, String> clientNameById;
  final List<SpeiPayment> payments;
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar operación'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _reasonController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo del rechazo', border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reasonController.text),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
