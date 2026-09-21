import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/approval_rule.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/concentrator_account.dart';
import '../../core/models/concentrator_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/session.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/confirm_dialog.dart';
import '../../shared_widgets/currency_field.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../cardholders/cardholder_list_view.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_repository.dart';
import '../staff_users/staff_user_list_view.dart';
import '../staff_users/staff_user_repository.dart';
import '../treasury/deposit_tile.dart';
import '../treasury/treasury_repository.dart';
import 'client_repository.dart';

/// Detalle de un Cliente: encabezado con acciones de gobernabilidad
/// (Editar / Desactivar / Reactivar — ver
/// docs/business/desactivacion-de-clientes.md), Tarjetahabientes (el
/// listado que ya existía) y Tesorería (Cuenta Concentradora / Cuenta
/// Colectora). Ver docs/feature/tesoreria-cliente/README.md.
class ClientDetailView extends StatefulWidget {
  const ClientDetailView({
    super.key,
    required this.client,
    required this.session,
    required this.cardholderRepository,
    required this.treasuryRepository,
    required this.clientRepository,
    required this.cardRepository,
    required this.balanceOperationRepository,
    required this.staffUserRepository,
    required this.onSelectCardholder,
    required this.onEdit,
    required this.onClientUpdated,
    this.onAddSubsidiary,
  });

  final Client client;
  final Session session;
  final CardholderRepository cardholderRepository;
  final TreasuryRepository treasuryRepository;
  final ClientRepository clientRepository;

  /// Para la pestaña "Configuración" (límite de tarjetas activas, reglas
  /// de aprobación) — ver docs/feature/configuracion-de-cliente/README.md.
  final CardRepository cardRepository;
  final BalanceOperationRepository balanceOperationRepository;

  /// Para la pestaña "Usuarios" — ver
  /// docs/feature/gestion-de-usuarios-staff/README.md.
  final StaffUserRepository staffUserRepository;
  final ValueChanged<Cardholder> onSelectCardholder;
  final VoidCallback onEdit;
  final ValueChanged<Client> onClientUpdated;

  /// Null cuando el rol de la sesión no puede crear Clientes — mismo
  /// criterio que el botón equivalente en ClientListView.
  final VoidCallback? onAddSubsidiary;

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _togglingActive = false;

  @override
  void initState() {
    super.initState();
    // "Configuración" y "Usuarios" solo para quien puede gestionar
    // Clientes — configuración operativa/de seguridad y alta de cuentas
    // de staff, no algo que Operador/Auditor necesiten ver.
    _tabController = TabController(length: widget.session.role.canManageClients ? 4 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmToggleActive() async {
    final client = widget.client;
    final activating = !client.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Reactivar empresa' : 'Desactivar empresa'),
        content: Text(
          activating
              ? '${client.name} y todas sus filiales volverán a poder operar (tarjetas, saldos, tesorería, tarjetahabientes).'
              : '${client.name} y todas sus filiales dejarán de poder operar en cualquier nivel. Su historial financiero se conserva y se puede seguir consultando; su expediente KYB se puede seguir editando.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: activating ? null : FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: Text(activating ? 'Reactivar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _togglingActive = true);
    final updated = await widget.clientRepository.setActive(client.id, activating);
    if (!mounted) return;
    setState(() => _togglingActive = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          activating
              ? '${client.name} y sus filiales fueron reactivadas.'
              : '${client.name} y sus filiales fueron desactivadas.',
        ),
      ),
    );
    widget.onClientUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final isOwnCompany = widget.session.clientId == client.id;
    final canManage = widget.session.role.canManageClients;
    final canToggleActive = canManage && !isOwnCompany;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        client.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!client.isActive) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Inactiva',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onAddSubsidiary != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onAddSubsidiary,
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('Agregar filial'),
                ),
                const SizedBox(width: 8),
              ],
              if (canManage) ...[
                OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 8),
              ],
              if (canToggleActive)
                OutlinedButton.icon(
                  onPressed: _togglingActive ? null : _confirmToggleActive,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: client.isActive ? Colors.red.shade700 : Colors.green.shade700,
                    side: BorderSide(color: client.isActive ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  icon: _togglingActive
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(client.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 18),
                  label: Text(client.isActive ? 'Desactivar' : 'Reactivar'),
                ),
            ],
          ),
        ),
        if (canManage && isOwnCompany)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'No puedes desactivar tu propia empresa.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ),
        TabBar(
          controller: _tabController,
          labelColor: KoonsColors.navy,
          indicatorColor: KoonsColors.blue,
          tabs: [
            const Tab(text: 'Tesorería'),
            const Tab(text: 'Tarjetahabientes'),
            if (canManage) const Tab(text: 'Configuración'),
            if (canManage) const Tab(text: 'Usuarios'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TreasuryTab(
                client: widget.client,
                session: widget.session,
                treasuryRepository: widget.treasuryRepository,
              ),
              CardholderListView(
                repository: widget.cardholderRepository,
                clientId: widget.client.id,
                session: widget.session,
                onSelect: widget.onSelectCardholder,
              ),
              if (canManage)
                _ConfigurationTab(
                  client: widget.client,
                  cardRepository: widget.cardRepository,
                  balanceOperationRepository: widget.balanceOperationRepository,
                ),
              if (canManage)
                StaffUserListView(
                  repository: widget.staffUserRepository,
                  clientId: widget.client.id,
                  session: widget.session,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TreasuryData {
  _TreasuryData(this.concentrator, this.entries, this.deposits);
  final ConcentratorAccount? concentrator;
  final List<ConcentratorEntry> entries;
  final List<CollectorDeposit> deposits;
}

class _TreasuryTab extends StatefulWidget {
  const _TreasuryTab({required this.client, required this.session, required this.treasuryRepository});

  final Client client;
  final Session session;
  final TreasuryRepository treasuryRepository;

  @override
  State<_TreasuryTab> createState() => _TreasuryTabState();
}

class _TreasuryTabState extends State<_TreasuryTab> {
  late Future<_TreasuryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TreasuryData> _load() async {
    final concentrator = await widget.treasuryRepository.getConcentratorAccount(widget.client.id);
    final entries =
        concentrator != null ? await widget.treasuryRepository.listConcentratorEntries(concentrator.id) : <ConcentratorEntry>[];
    final deposits = await widget.treasuryRepository.listCollectorDeposits(widget.client.id);
    return _TreasuryData(concentrator, entries, deposits);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openRegisterDepositDialog() async {
    final result = await showDialog<CollectorDeposit>(
      context: context,
      builder: (context) => _RegisterDepositDialog(
        clientId: widget.client.id,
        session: widget.session,
        repository: widget.treasuryRepository,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Depósito registrado, pendiente de conciliar.')),
    );
  }

  Future<void> _reconcile(CollectorDeposit deposit, {required String currency}) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Conciliar depósito',
      message: '¿Deseas conciliar el depósito de ${formatCurrency(deposit.amount, currency)} '
          'de ${widget.client.name}? El saldo quedará disponible de inmediato en su Cuenta Concentradora.',
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
    return FutureBuilder<_TreasuryData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final concentrator = data.concentrator;
        final canRegister = widget.session.role.canRegisterCollectorDeposits;
        final canReconcile = widget.session.role.canReconcileDeposits;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                    decoration: BoxDecoration(
                      color: KoonsColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KoonsColors.blue.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'SALDO CUENTA CONCENTRADORA',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          concentrator != null
                              ? formatCurrency(concentrator.balance, concentrator.currency)
                              : 'Sin Cuenta Concentradora',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: KoonsColors.navy),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Movimientos de la Concentradora', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aún no hay movimientos en la Concentradora.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final entry in data.entries) _ConcentratorEntryTile(entry: entry, currency: concentrator!.currency),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text('Cuenta Colectora', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (canRegister)
                    FilledButton.icon(
                      onPressed: _openRegisterDepositDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Registrar depósito'),
                    ),
                ],
              ),
              if (!canRegister) ...[
                const SizedBox(height: 4),
                Text(
                  'Tu rol (${widget.session.role.label}) puede ver los depósitos pero no registrar nuevos.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              if (data.deposits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aún no hay depósitos registrados.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final deposit in data.deposits)
                        DepositTile(
                          deposit: deposit,
                          currency: concentrator?.currency ?? 'MXN',
                          clientName: '',
                          canReconcile: canReconcile,
                          onReconcile: () => _reconcile(deposit, currency: concentrator?.currency ?? 'MXN'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConcentratorEntryTile extends StatelessWidget {
  const _ConcentratorEntryTile({required this.entry, required this.currency});

  final ConcentratorEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.type == LedgerEntryType.credit;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isCredit ? Colors.green : KoonsColors.navy).withValues(alpha: 0.1),
        child: Icon(
          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: isCredit ? Colors.green.shade700 : KoonsColors.navy,
          size: 20,
        ),
      ),
      title: Text(entry.description ?? entry.type.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatDateTime(entry.createdAt), style: TextStyle(color: Colors.grey.shade600)),
      trailing: Text(
        '${isCredit ? '+' : '-'}${formatCurrency(entry.amount, currency)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: isCredit ? Colors.green.shade700 : KoonsColors.navy),
      ),
    );
  }
}

class _RegisterDepositDialog extends StatefulWidget {
  const _RegisterDepositDialog({required this.clientId, required this.session, required this.repository});

  final String clientId;
  final Session session;
  final TreasuryRepository repository;

  @override
  State<_RegisterDepositDialog> createState() => _RegisterDepositDialogState();
}

class _RegisterDepositDialogState extends State<_RegisterDepositDialog> {
  double _amount = 0;
  final _referenceController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amount <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }
    if (_referenceController.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa una referencia o folio.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.registerDeposit(
      clientId: widget.clientId,
      amount: _amount,
      reference: _referenceController.text.trim(),
      registeredByEmail: widget.session.email,
    );
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar depósito'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencyField(onChanged: (value) => _amount = value, autofocus: true),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Referencia / folio bancario'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Registrar'),
        ),
      ],
    );
  }
}

/// "Configuración": límite de tarjetas activas por Tarjetahabiente y
/// reglas de aprobación por tipo de operación — antes solo eran datos
/// sembrados sin ninguna pantalla para editarlos. Ver
/// docs/feature/configuracion-de-cliente/README.md. Solo visible para
/// `Role.canManageClients` (ver el TabBar condicional en
/// _ClientDetailViewState).
class _ConfigurationData {
  _ConfigurationData(this.maxActiveCards, this.rules);
  final int? maxActiveCards;
  final List<ApprovalRule> rules;
}

class _ConfigurationTab extends StatefulWidget {
  const _ConfigurationTab({
    required this.client,
    required this.cardRepository,
    required this.balanceOperationRepository,
  });

  final Client client;
  final CardRepository cardRepository;
  final BalanceOperationRepository balanceOperationRepository;

  @override
  State<_ConfigurationTab> createState() => _ConfigurationTabState();
}

class _ConfigurationTabState extends State<_ConfigurationTab> {
  late Future<_ConfigurationData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ConfigurationData> _load() async {
    final max = await widget.cardRepository.maxActiveCardsPerCardholder(widget.client.id);
    final rules = await widget.balanceOperationRepository.listApprovalRules(widget.client.id);
    return _ConfigurationData(max, rules);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editMaxActiveCards(int? current) async {
    final result = await showDialog<_MaxActiveCardsResult>(
      context: context,
      builder: (context) => _MaxActiveCardsDialog(initial: current),
    );
    if (result == null) return;

    await widget.cardRepository.setMaxActiveCardsPerCardholder(widget.client.id, result.value);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Límite actualizado.')));
  }

  Future<void> _editRule(OperationType type, ApprovalRule? existing) async {
    final result = await showDialog<_RuleDialogResult>(
      context: context,
      builder: (context) => _ApprovalRuleDialog(type: type, existing: existing),
    );
    if (result == null) return;

    if (result.delete) {
      await widget.balanceOperationRepository.deleteApprovalRule(clientId: widget.client.id, type: type);
    } else {
      await widget.balanceOperationRepository.setApprovalRule(
        clientId: widget.client.id,
        type: type,
        requiresApproval: result.requiresApproval,
        minAmount: result.minAmount,
      );
    }
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.delete ? 'Regla eliminada.' : 'Regla actualizada.')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ConfigurationData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final rulesByType = {for (final r in data.rules) r.operationType: r};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Límite de tarjetas activas por Tarjetahabiente', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Cuántas tarjetas puede tener activas al mismo tiempo cada Tarjetahabiente de este Cliente — ver docs/business/tarjetas-y-asignacion.md.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    data.maxActiveCards != null
                        ? '${data.maxActiveCards} tarjeta${data.maxActiveCards == 1 ? '' : 's'} activa${data.maxActiveCards == 1 ? '' : 's'}'
                        : 'Sin límite configurado (usa el default: 1)',
                  ),
                  trailing: TextButton(
                    onPressed: () => _editMaxActiveCards(data.maxActiveCards),
                    child: const Text('Editar'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Reglas de aprobación', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Cuándo una Dispersión, Deducción o Transferencia necesita aprobación de un Admin Cliente o Super Admin antes de ejecutarse. Un tipo sin regla configurada siempre requiere aprobación — ver docs/business/approval-policy.md.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final type in OperationType.values)
                      _ApprovalRuleTile(
                        type: type,
                        rule: rulesByType[type],
                        onEdit: () => _editRule(type, rulesByType[type]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalRuleTile extends StatelessWidget {
  const _ApprovalRuleTile({required this.type, required this.rule, required this.onEdit});

  final OperationType type;
  final ApprovalRule? rule;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String subtitle;
    if (rule == null) {
      subtitle = 'Sin regla — requiere aprobación (default de seguridad)';
    } else if (!rule!.requiresApproval) {
      subtitle = 'No requiere aprobación — se ejecuta de inmediato';
    } else if (rule!.minAmount != null) {
      subtitle = 'Requiere aprobación para montos mayores a ${formatCurrency(rule!.minAmount!, 'MXN')}';
    } else {
      subtitle = 'Requiere aprobación para cualquier monto';
    }

    return ListTile(
      title: Text(type.label),
      subtitle: Text(subtitle),
      trailing: TextButton(onPressed: onEdit, child: const Text('Editar')),
    );
  }
}

class _RuleDialogResult {
  const _RuleDialogResult.save({required this.requiresApproval, this.minAmount}) : delete = false;
  const _RuleDialogResult.delete()
      : requiresApproval = true,
        minAmount = null,
        delete = true;

  final bool requiresApproval;
  final double? minAmount;
  final bool delete;
}

class _ApprovalRuleDialog extends StatefulWidget {
  const _ApprovalRuleDialog({required this.type, required this.existing});

  final OperationType type;
  final ApprovalRule? existing;

  @override
  State<_ApprovalRuleDialog> createState() => _ApprovalRuleDialogState();
}

class _ApprovalRuleDialogState extends State<_ApprovalRuleDialog> {
  late bool _requiresApproval = widget.existing?.requiresApproval ?? true;
  double? _minAmount;

  @override
  void initState() {
    super.initState();
    _minAmount = widget.existing?.minAmount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Regla de aprobación — ${widget.type.label}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere aprobación'),
              value: _requiresApproval,
              onChanged: (value) => setState(() => _requiresApproval = value),
            ),
            if (_requiresApproval) ...[
              const SizedBox(height: 8),
              CurrencyField(
                label: 'Monto mínimo (\$0.00 = cualquier monto)',
                initialValue: _minAmount ?? 0,
                onChanged: (value) => _minAmount = value == 0 ? null : value,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _RuleDialogResult.delete()),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Quitar regla'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _RuleDialogResult.save(requiresApproval: _requiresApproval, minAmount: _minAmount),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Envuelve el `int?` guardado — un `int?` solo no distinguiría "canceló
/// el diálogo" (showDialog devuelve null) de "guardó, quitando el límite
/// a propósito" (también sería null).
class _MaxActiveCardsResult {
  const _MaxActiveCardsResult(this.value);
  final int? value;
}

class _MaxActiveCardsDialog extends StatefulWidget {
  const _MaxActiveCardsDialog({required this.initial});

  final int? initial;

  @override
  State<_MaxActiveCardsDialog> createState() => _MaxActiveCardsDialogState();
}

class _MaxActiveCardsDialogState extends State<_MaxActiveCardsDialog> {
  // El controller es del diálogo, no de quien lo abre — se dispone en el
  // dispose() de este State, nunca justo después de que showDialog
  // resuelve (eso rompía con "TextEditingController used after being
  // disposed": el TextField todavía puede reconstruirse un frame más
  // mientras la ruta del diálogo termina su transición de salida).
  late final _controller = TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Límite de tarjetas activas'),
      content: SizedBox(
        width: 340,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Límite por Tarjetahabiente',
            helperText: 'Vacío = sin override, usa el default de la plataforma (1).',
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, _MaxActiveCardsResult(text.isEmpty ? null : int.tryParse(text)));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
