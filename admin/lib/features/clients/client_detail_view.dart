import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/concentrator_account.dart';
import '../../core/models/concentrator_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/session.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/confirm_dialog.dart';
import '../../shared_widgets/currency_field.dart';
import '../cardholders/cardholder_list_view.dart';
import '../cardholders/cardholder_repository.dart';
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
    required this.onSelectCardholder,
    required this.onEdit,
    required this.onClientUpdated,
  });

  final Client client;
  final Session session;
  final CardholderRepository cardholderRepository;
  final TreasuryRepository treasuryRepository;
  final ClientRepository clientRepository;
  final ValueChanged<Cardholder> onSelectCardholder;
  final VoidCallback onEdit;
  final ValueChanged<Client> onClientUpdated;

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _togglingActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [
            Tab(text: 'Tesorería'),
            Tab(text: 'Tarjetahabientes'),
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
