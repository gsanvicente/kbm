import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary_directory_entry.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';
import '../../core/models/treasury_statement.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/cardholder_search_field.dart';
import '../../shared_widgets/multi_select_filter_button.dart';
import '../../shared_widgets/pdf_download.dart';
import '../../shared_widgets/pdf_statement.dart';
import '../../shared_widgets/period_filter.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import '../spei/spei_repository.dart';
import '../treasury/treasury_repository.dart';

/// Hub de reportes de staff — historial completo de Pagos SPEI,
/// Depósitos SPEI, y el directorio de Beneficiarios de Pago. Separado
/// del hub "Aprobaciones" (que sigue siendo "requiere tu acción") —
/// "Reportes" es "consultas históricas", mismo lenguaje que usa el
/// documento de referencia original ("Reportes y consultas"). Ver
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md y
/// docs/feature/reportes-admin/README.md.
class ReportesSection extends StatefulWidget {
  const ReportesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.speiRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.treasuryRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final SpeiRepository speiRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final TreasuryRepository treasuryRepository;

  @override
  State<ReportesSection> createState() => _ReportesSectionState();
}

class _ReportesSectionState extends State<ReportesSection> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
              Tab(text: 'Pagos SPEI'),
              Tab(text: 'Depósitos SPEI'),
              Tab(text: 'Beneficiarios'),
              Tab(text: 'Movimientos'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PagosSpeiTab(clientRepository: widget.clientRepository, speiRepository: widget.speiRepository, session: widget.session),
                _DepositosSpeiTab(clientRepository: widget.clientRepository, speiRepository: widget.speiRepository, session: widget.session),
                _BeneficiariosTab(
                  clientRepository: widget.clientRepository,
                  speiRepository: widget.speiRepository,
                  session: widget.session,
                ),
                _MovimientosTab(
                  session: widget.session,
                  clientRepository: widget.clientRepository,
                  cardholderRepository: widget.cardholderRepository,
                  cardRepository: widget.cardRepository,
                  ledgerRepository: widget.ledgerRepository,
                  treasuryRepository: widget.treasuryRepository,
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

class _PagosSpeiTab extends StatefulWidget {
  const _PagosSpeiTab({required this.clientRepository, required this.speiRepository, required this.session});
  final ClientRepository clientRepository;
  final SpeiRepository speiRepository;
  final Session session;

  @override
  State<_PagosSpeiTab> createState() => _PagosSpeiTabState();
}

class _PagosSpeiTabState extends State<_PagosSpeiTab> {
  late Future<(List<Client>, List<SpeiPayment>)> _future;
  Set<OperationStatus> _statusFilter = {};
  Set<String> _clientFilter = {};
  PeriodFilter _period = PeriodFilter.all;
  final _minAmountController = TextEditingController();
  final _beneficiarySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _beneficiarySearchController.dispose();
    super.dispose();
  }

  Future<(List<Client>, List<SpeiPayment>)> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final payments = await widget.speiRepository.listAllByClients(clients.map((c) => c.id).toList());
    return (clients, payments);
  }

  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty ||
      _clientFilter.isNotEmpty ||
      _period != PeriodFilter.all ||
      _minAmountController.text.trim().isNotEmpty ||
      _beneficiarySearchController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _statusFilter = {};
      _clientFilter = {};
      _period = PeriodFilter.all;
      _minAmountController.clear();
      _beneficiarySearchController.clear();
    });
  }

  String _activeFiltersLabel(Map<String, String> clientNameById) {
    final parts = <String>[];
    if (_clientFilter.isNotEmpty) parts.add('Cliente: ${_clientFilter.map((id) => clientNameById[id] ?? '—').join(', ')}');
    if (_statusFilter.isNotEmpty) parts.add('Estatus: ${_statusFilter.map((s) => s.label).join(', ')}');
    if (_period != PeriodFilter.all) parts.add('Periodo: ${_period.label}');
    if (_minAmountController.text.trim().isNotEmpty) parts.add('Monto mínimo: ${_minAmountController.text.trim()}');
    if (_beneficiarySearchController.text.trim().isNotEmpty) {
      parts.add('Beneficiario: "${_beneficiarySearchController.text.trim()}"');
    }
    return parts.isEmpty ? 'Ninguno' : parts.join(' · ');
  }

  Future<void> _download(List<SpeiPayment> rows, Map<String, String> clientNameById) async {
    final bytes = await buildReportPdf(
      title: 'Reporte de Pagos SPEI',
      infoFields: [
        MapEntry('Generado por', widget.session.email),
        MapEntry('Filtros activos', _activeFiltersLabel(clientNameById)),
      ],
      columns: const ['Fecha', 'Tarjetahabiente', 'Cliente', 'Beneficiario', 'CLABE', 'Monto', 'Estatus'],
      rows: [
        for (final p in rows)
          [
            formatDateTime(p.createdAt),
            p.requestedByFullName,
            clientNameById[p.clientId] ?? '—',
            p.beneficiaryAlias,
            p.beneficiaryClabe,
            formatCurrency(p.amount, 'MXN'),
            p.status.label,
          ],
      ],
      rightAlignedColumns: const {5},
    );
    if (!mounted) return;
    try {
      downloadPdf('pagos-spei-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Client>, List<SpeiPayment>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar pagos SPEI: ${snapshot.error}'));
        }
        final (clients, all) = snapshot.data!;
        final clientNameById = {for (final c in clients) c.id: c.name};
        final now = DateTime.now();
        final minAmount = double.tryParse(_minAmountController.text.trim()) ?? 0;
        final beneficiarySearch = _beneficiarySearchController.text.trim().toLowerCase();

        final filtered = all.where((p) {
          if (_statusFilter.isNotEmpty && !_statusFilter.contains(p.status)) return false;
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(p.clientId)) return false;
          if (!_period.includes(p.createdAt, now)) return false;
          if (minAmount > 0 && p.amount < minAmount) return false;
          if (beneficiarySearch.isNotEmpty && !p.beneficiaryAlias.toLowerCase().contains(beneficiarySearch)) return false;
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
                  if (clients.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Cliente',
                      options: clients.map((c) => c.id).toList(),
                      optionLabel: (id) => clientNameById[id] ?? '—',
                      selected: _clientFilter,
                      onChanged: (next) => setState(() => _clientFilter = next),
                    ),
                  MultiSelectFilterButton<OperationStatus>(
                    label: 'Estatus',
                    options: OperationStatus.values,
                    optionLabel: (s) => s.label,
                    selected: _statusFilter,
                    onChanged: (next) => setState(() => _statusFilter = next),
                  ),
                  PeriodDropdown(value: _period, onChanged: (next) => setState(() => _period = next)),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _minAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto mínimo', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _beneficiarySearchController,
                      decoration: const InputDecoration(labelText: 'Buscar beneficiario', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_hasActiveFilters) TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _download(filtered, clientNameById),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Descargar'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? 'Aún no hay pagos SPEI.' : 'Ningún pago coincide con los filtros.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: _statusColor(p.status).withValues(alpha: 0.12), child: Icon(Icons.send_rounded, color: _statusColor(p.status), size: 18)),
                          title: Text('${p.requestedByFullName} → ${p.beneficiaryAlias} (${p.beneficiaryClabe})'),
                          subtitle: Text(
                            '${clientNameById[p.clientId] ?? '—'} · ${formatDateTime(p.createdAt)} · ${p.status.label}'
                            '${p.resolutionNotes != null ? ' · ${p.resolutionNotes}' : ''}',
                          ),
                          trailing: Text(
                            formatCurrency(p.amount, 'MXN'),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: KoonsColors.navy),
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

  Color _statusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.executed:
        return KoonsColors.green;
      case OperationStatus.pendingApproval:
      case OperationStatus.approved:
        return Colors.orange.shade800;
      case OperationStatus.rejected:
      case OperationStatus.failed:
        return Colors.red.shade700;
    }
  }
}

class _DepositosSpeiTab extends StatefulWidget {
  const _DepositosSpeiTab({required this.clientRepository, required this.speiRepository, required this.session});
  final ClientRepository clientRepository;
  final SpeiRepository speiRepository;
  final Session session;

  @override
  State<_DepositosSpeiTab> createState() => _DepositosSpeiTabState();
}

class _DepositosSpeiTabState extends State<_DepositosSpeiTab> {
  late Future<(List<Client>, List<SpeiDeposit>)> _future;
  Set<String> _clientFilter = {};
  PeriodFilter _period = PeriodFilter.all;
  final _minAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    super.dispose();
  }

  Future<(List<Client>, List<SpeiDeposit>)> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final deposits = await widget.speiRepository.listDepositsByClients(clients.map((c) => c.id).toList());
    return (clients, deposits);
  }

  bool get _hasActiveFilters =>
      _clientFilter.isNotEmpty || _period != PeriodFilter.all || _minAmountController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _clientFilter = {};
      _period = PeriodFilter.all;
      _minAmountController.clear();
    });
  }

  String _activeFiltersLabel(Map<String, String> clientNameById) {
    final parts = <String>[];
    if (_clientFilter.isNotEmpty) parts.add('Cliente: ${_clientFilter.map((id) => clientNameById[id] ?? '—').join(', ')}');
    if (_period != PeriodFilter.all) parts.add('Periodo: ${_period.label}');
    if (_minAmountController.text.trim().isNotEmpty) parts.add('Monto mínimo: ${_minAmountController.text.trim()}');
    return parts.isEmpty ? 'Ninguno' : parts.join(' · ');
  }

  Future<void> _download(List<SpeiDeposit> rows, Map<String, String> clientNameById) async {
    final bytes = await buildReportPdf(
      title: 'Reporte de Depósitos SPEI',
      infoFields: [
        MapEntry('Generado por', widget.session.email),
        MapEntry('Filtros activos', _activeFiltersLabel(clientNameById)),
      ],
      columns: const ['Fecha', 'Tarjetahabiente', 'Cliente', 'Monto', 'Referencia'],
      rows: [
        for (final d in rows)
          [formatDateTime(d.createdAt), d.cardholderFullName, clientNameById[d.clientId] ?? '—', formatCurrency(d.amount, 'MXN'), d.providerReference],
      ],
      rightAlignedColumns: const {3},
    );
    if (!mounted) return;
    try {
      downloadPdf('depositos-spei-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Client>, List<SpeiDeposit>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar depósitos SPEI: ${snapshot.error}'));
        }
        final (clients, all) = snapshot.data!;
        final clientNameById = {for (final c in clients) c.id: c.name};
        final now = DateTime.now();
        final minAmount = double.tryParse(_minAmountController.text.trim()) ?? 0;

        final filtered = all.where((d) {
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(d.clientId)) return false;
          if (!_period.includes(d.createdAt, now)) return false;
          if (minAmount > 0 && d.amount < minAmount) return false;
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
                  if (clients.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Cliente',
                      options: clients.map((c) => c.id).toList(),
                      optionLabel: (id) => clientNameById[id] ?? '—',
                      selected: _clientFilter,
                      onChanged: (next) => setState(() => _clientFilter = next),
                    ),
                  PeriodDropdown(value: _period, onChanged: (next) => setState(() => _period = next)),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _minAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto mínimo', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_hasActiveFilters) TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _download(filtered, clientNameById),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Descargar'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? 'Aún no hay depósitos SPEI.' : 'Ningún depósito coincide con los filtros.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: KoonsColors.surface, child: Icon(Icons.arrow_downward_rounded, color: KoonsColors.green, size: 18)),
                          title: Text(d.cardholderFullName),
                          subtitle: Text('${clientNameById[d.clientId] ?? '—'} · ${formatDateTime(d.createdAt)} · ${d.providerReference}'),
                          trailing: Text(
                            '+${formatCurrency(d.amount, 'MXN')}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: KoonsColors.green),
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

class _BeneficiariosTab extends StatefulWidget {
  const _BeneficiariosTab({required this.clientRepository, required this.speiRepository, required this.session});
  final ClientRepository clientRepository;
  final SpeiRepository speiRepository;
  final Session session;

  @override
  State<_BeneficiariosTab> createState() => _BeneficiariosTabState();
}

class _BeneficiariosTabState extends State<_BeneficiariosTab> {
  late Future<(List<Client>, List<BeneficiaryDirectoryEntry>)> _future;
  String? _revealedId;
  String? _revealedClabe;
  bool _revealing = false;

  Set<String> _clientFilter = {};
  Set<String> _bankFilter = {};
  bool _onlyAlerted = false;
  final _cardholderSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _cardholderSearchController.dispose();
    super.dispose();
  }

  Future<(List<Client>, List<BeneficiaryDirectoryEntry>)> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final entries = await widget.speiRepository.listBeneficiaryDirectory(clients.map((c) => c.id).toList());
    return (clients, entries);
  }

  bool get _hasActiveFilters =>
      _clientFilter.isNotEmpty || _bankFilter.isNotEmpty || _onlyAlerted || _cardholderSearchController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _clientFilter = {};
      _bankFilter = {};
      _onlyAlerted = false;
      _cardholderSearchController.clear();
    });
  }

  String _activeFiltersLabel(Map<String, String> clientNameById) {
    final parts = <String>[];
    if (_clientFilter.isNotEmpty) parts.add('Cliente: ${_clientFilter.map((id) => clientNameById[id] ?? '—').join(', ')}');
    if (_bankFilter.isNotEmpty) parts.add('Banco: ${_bankFilter.join(', ')}');
    if (_onlyAlerted) parts.add('Solo con alerta activa');
    if (_cardholderSearchController.text.trim().isNotEmpty) {
      parts.add('Tarjetahabiente: "${_cardholderSearchController.text.trim()}"');
    }
    return parts.isEmpty ? 'Ninguno' : parts.join(' · ');
  }

  /// La CLABE exportada respeta exactamente lo que la fila muestra en
  /// pantalla en ese momento (enmascarada por default, completa solo si
  /// ya se reveló esa fila) — mismo criterio "el PDF exporta lo que ya
  /// está en pantalla" que el resto de ADR-0023, nunca revela de más.
  Future<void> _download(List<BeneficiaryDirectoryEntry> rows, Map<String, String> clientNameById) async {
    final bytes = await buildReportPdf(
      title: 'Reporte de Beneficiarios de Pago',
      infoFields: [
        MapEntry('Generado por', widget.session.email),
        MapEntry('Filtros activos', _activeFiltersLabel(clientNameById)),
      ],
      columns: const ['Alias', 'Tarjetahabiente', 'Cliente', 'Banco', 'CLABE', 'Pagos', 'Total', 'Alerta'],
      rows: [
        for (final b in rows)
          [
            b.alias,
            b.cardholderFullName,
            clientNameById[b.clientId] ?? '—',
            b.bankName,
            _revealedId == b.id ? (_revealedClabe ?? b.maskedClabe) : b.maskedClabe,
            '${b.paymentCount}',
            formatCurrency(b.totalAmountPaid, 'MXN'),
            b.sharedByMultipleCardholders ? 'Sí' : 'No',
          ],
      ],
      rightAlignedColumns: const {5, 6},
    );
    if (!mounted) return;
    try {
      downloadPdf('beneficiarios-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  Future<void> _reveal(BeneficiaryDirectoryEntry entry) async {
    setState(() {
      _revealing = true;
      _revealedId = entry.id;
    });
    try {
      final clabe = await widget.speiRepository.revealClabe(entry.id);
      if (!mounted) return;
      setState(() {
        _revealedClabe = clabe;
        _revealing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _revealing = false;
        _revealedId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo revelar la CLABE.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReveal = widget.session.role.canManageCardholders;

    return FutureBuilder<(List<Client>, List<BeneficiaryDirectoryEntry>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar Beneficiarios: ${snapshot.error}'));
        }
        final (clients, all) = snapshot.data!;
        final clientNameById = {for (final c in clients) c.id: c.name};
        final banks = all.map((b) => b.bankName).toSet().toList()..sort();
        final search = _cardholderSearchController.text.trim().toLowerCase();

        final filtered = all.where((b) {
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(b.clientId)) return false;
          if (_bankFilter.isNotEmpty && !_bankFilter.contains(b.bankName)) return false;
          if (_onlyAlerted && !b.sharedByMultipleCardholders) return false;
          if (search.isNotEmpty && !b.cardholderFullName.toLowerCase().contains(search)) return false;
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
                  if (clients.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Cliente',
                      options: clients.map((c) => c.id).toList(),
                      optionLabel: (id) => clientNameById[id] ?? '—',
                      selected: _clientFilter,
                      onChanged: (next) => setState(() => _clientFilter = next),
                    ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _cardholderSearchController,
                      decoration: const InputDecoration(labelText: 'Buscar Tarjetahabiente', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (banks.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Banco',
                      options: banks,
                      optionLabel: (b) => b,
                      selected: _bankFilter,
                      onChanged: (next) => setState(() => _bankFilter = next),
                    ),
                  FilterChip(
                    label: const Text('Solo con alerta activa'),
                    selected: _onlyAlerted,
                    onSelected: (value) => setState(() => _onlyAlerted = value),
                  ),
                  if (_hasActiveFilters) TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _download(filtered, clientNameById),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Descargar'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? 'Aún no hay Beneficiarios de Pago registrados.' : 'Ningún Beneficiario coincide con los filtros.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final b = filtered[index];
                        final showingClabe = _revealedId == b.id ? _revealedClabe : null;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: KoonsColors.blue.withValues(alpha: 0.1),
                            child: Text(b.alias.isNotEmpty ? b.alias[0].toUpperCase() : '?', style: const TextStyle(color: KoonsColors.blue, fontWeight: FontWeight.w700)),
                          ),
                          title: Row(
                            children: [
                              Text(b.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (b.sharedByMultipleCardholders) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Esta CLABE también está registrada por otro Tarjetahabiente — revisar posible duplicidad.',
                                  child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${b.cardholderFullName} · ${clientNameById[b.clientId] ?? '—'} · ${b.bankName} · ${showingClabe ?? b.maskedClabe}\n'
                            '${b.paymentCount} pago(s) enviados · ${formatCurrency(b.totalAmountPaid, 'MXN')} total'
                            '${b.isCooling ? ' · en periodo de enfriamiento' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: canReveal
                              ? (_revealing && _revealedId == b.id
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : TextButton(
                                      onPressed: showingClabe != null ? null : () => _reveal(b),
                                      child: Text(showingClabe != null ? 'Revelada' : 'Revelar CLABE'),
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

/// "Movimientos" — cuarta pestaña de Reportes, agregada por pedido
/// explícito del negocio (2026-09-25): las descargas de estado de cuenta
/// ya existían dispersas en el detalle de cada Cliente (Tesorería),
/// Tarjetahabiente (Cuenta Individual) y Tarjeta (Movimientos) — se
/// mantienen ahí tal cual, pero ahora también se puede buscar y
/// descargar cualquiera de las tres **sin salir de Reportes**. A
/// diferencia de esas pantallas (que ya saben de qué entidad se trata,
/// porque el staff llegó navegando hasta ahí), aquí primero hay que
/// elegir qué se quiere ver.
enum _MovementScope { tarjetahabiente, cliente }

class _MovimientosTab extends StatefulWidget {
  const _MovimientosTab({
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.treasuryRepository,
    required this.speiRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final TreasuryRepository treasuryRepository;
  final SpeiRepository speiRepository;

  @override
  State<_MovimientosTab> createState() => _MovimientosTabState();
}

class _MovimientosTabState extends State<_MovimientosTab> {
  _MovementScope _scope = _MovementScope.tarjetahabiente;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Buscar por', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey.shade700)),
              const SizedBox(width: 12),
              SegmentedButton<_MovementScope>(
                segments: const [
                  ButtonSegment(
                    value: _MovementScope.tarjetahabiente,
                    label: Text('Tarjetahabiente'),
                    icon: Icon(Icons.person_outline_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: _MovementScope.cliente,
                    label: Text('Cliente (Concentradora)'),
                    icon: Icon(Icons.account_balance_outlined, size: 16),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (next) => setState(() => _scope = next.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_scope) {
            _MovementScope.tarjetahabiente => _TarjetahabienteMovementsPanel(
                key: const ValueKey('tarjetahabiente'),
                session: widget.session,
                clientRepository: widget.clientRepository,
                cardholderRepository: widget.cardholderRepository,
                cardRepository: widget.cardRepository,
                ledgerRepository: widget.ledgerRepository,
                speiRepository: widget.speiRepository,
              ),
            _MovementScope.cliente => _ClienteMovementsPanel(
                key: const ValueKey('cliente'),
                session: widget.session,
                clientRepository: widget.clientRepository,
                treasuryRepository: widget.treasuryRepository,
              ),
          },
        ),
      ],
    );
  }
}

/// Fila genérica de movimiento — misma forma que `PdfStatementRow`, para
/// pintar en pantalla el mismo dato que luego se descarga.
class _MovementRow {
  const _MovementRow({required this.date, required this.isCredit, required this.description, required this.amount, required this.balanceAfter});
  final String date;
  final bool isCredit;
  final String description;
  final double amount;
  final double balanceAfter;
}

class _MovementsListView extends StatelessWidget {
  const _MovementsListView({required this.rows, required this.currency});
  final List<_MovementRow> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Sin movimientos.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))),
      );
    }
    return Column(
      children: [
        for (final r in rows) ...[
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: (r.isCredit ? KoonsColors.green : KoonsColors.navy).withValues(alpha: 0.1),
              child: Icon(
                r.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: r.isCredit ? KoonsColors.green : KoonsColors.navy,
                size: 16,
              ),
            ),
            title: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(r.date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            trailing: Text(
              '${r.isCredit ? '+' : '-'}${formatCurrency(r.amount, currency)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: r.isCredit ? KoonsColors.green : KoonsColors.navy),
            ),
          ),
          const Divider(height: 1, indent: 56),
        ],
      ],
    );
  }
}

/// Rama "Cliente (Concentradora)" — busca un Cliente dentro del alcance
/// de la sesión y muestra/descarga su Estado de cuenta, mismo dato que
/// ya ofrece la pestaña "Tesorería" de ese Cliente
/// (`_ExecutiveStatementSection` en `client_detail_view.dart`), pero sin
/// tener que navegar hasta ahí primero.
class _ClienteMovementsPanel extends StatefulWidget {
  const _ClienteMovementsPanel({super.key, required this.session, required this.clientRepository, required this.treasuryRepository});
  final Session session;
  final ClientRepository clientRepository;
  final TreasuryRepository treasuryRepository;

  @override
  State<_ClienteMovementsPanel> createState() => _ClienteMovementsPanelState();
}

class _ClienteMovementsPanelState extends State<_ClienteMovementsPanel> {
  late Future<List<Client>> _clientsFuture;
  Client? _selected;
  Future<TreasuryStatement?>? _statementFuture;
  PeriodFilter _period = PeriodFilter.all;

  @override
  void initState() {
    super.initState();
    _clientsFuture = widget.clientRepository.listAccessibleClients(widget.session);
  }

  void _select(Client? client) {
    setState(() {
      _selected = client;
      _statementFuture = client == null ? null : widget.treasuryRepository.getStatement(client.id);
    });
  }

  Future<void> _download(TreasuryStatement statement, List<_MovementRow> rows) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Concentradora',
      infoFields: [
        MapEntry('Cliente', _selected!.name),
        MapEntry('Generado por', widget.session.email),
      ],
      balance: statement.concentratorBalance,
      currency: statement.currency,
      periodLabel: _period.label,
      rows: [for (final r in rows) PdfStatementRow(date: r.date, isCredit: r.isCredit, description: r.description, amount: r.amount, balanceAfter: r.balanceAfter)],
    );
    if (!mounted) return;
    try {
      downloadPdf('estado-de-cuenta-${_selected!.id}-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Client>>(
      future: _clientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final clients = snapshot.data ?? const [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: Autocomplete<Client>(
                  displayStringForOption: (c) => c.name,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) return const Iterable<Client>.empty();
                    return clients.where((c) => c.name.toLowerCase().contains(query));
                  },
                  onSelected: _select,
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar Cliente...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selected == null)
                Expanded(
                  child: Center(
                    child: Text('Busca un Cliente para ver su Estado de cuenta.', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                )
              else
                Expanded(
                  child: FutureBuilder<TreasuryStatement?>(
                    future: _statementFuture,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final statement = snap.data;
                      if (statement == null) {
                        return Center(child: Text('${_selected!.name} no tiene Cuenta Concentradora.', style: TextStyle(color: Colors.grey.shade500)));
                      }
                      final now = DateTime.now();
                      final rows = [
                        for (final e in statement.entries)
                          if (_period.includes(e.createdAt, now))
                            _MovementRow(
                              date: formatDateTime(e.createdAt),
                              isCredit: e.type == LedgerEntryType.credit,
                              description: e.description ?? e.type.label,
                              amount: e.amount,
                              balanceAfter: e.balanceAfter,
                            ),
                      ];
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SALDO ACTUAL', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                    Text(
                                      formatCurrency(statement.concentratorBalance, statement.currency),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KoonsColors.navy),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    PeriodDropdown(value: _period, onChanged: (next) => setState(() => _period = next)),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _download(statement, rows),
                                      icon: const Icon(Icons.download_rounded, size: 16),
                                      label: const Text('Descargar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _MovementsListView(rows: rows, currency: statement.currency),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Rama "Tarjetahabiente" — busca un Tarjetahabiente dentro del alcance
/// de la sesión y muestra/descarga su Cuenta Individual completa (mismo
/// dato que la sección "Cuenta Individual" de `CardholderDetailView`), y
/// además permite bajar a una de sus tarjetas puntuales (mismo dato que
/// la pestaña "Movimientos" de `CardDetailView`) sin salir de Reportes.
class _TarjetahabienteMovementsPanel extends StatefulWidget {
  const _TarjetahabienteMovementsPanel({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.speiRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final SpeiRepository speiRepository;

  @override
  State<_TarjetahabienteMovementsPanel> createState() => _TarjetahabienteMovementsPanelState();
}

class _TarjetahabienteMovementsPanelState extends State<_TarjetahabienteMovementsPanel> {
  late Future<List<Cardholder>> _cardholdersFuture;
  Cardholder? _selected;
  Future<AccountLedger>? _ledgerFuture;
  Future<List<PaymentCard>>? _cardsFuture;
  String? _expandedCardId;
  final Map<String, Future<LedgerAccount?>> _cardLedgerFutures = {};

  @override
  void initState() {
    super.initState();
    _cardholdersFuture = _loadCardholders();
  }

  Future<List<Cardholder>> _loadCardholders() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    return widget.cardholderRepository.listByClients(clients.map((c) => c.id).toList());
  }

  void _select(Cardholder? cardholder) {
    setState(() {
      _selected = cardholder;
      _expandedCardId = null;
      _cardLedgerFutures.clear();
      _ledgerFuture = cardholder == null ? null : widget.speiRepository.getAccountLedger(cardholder.id);
      _cardsFuture = cardholder == null ? null : widget.cardRepository.listByCardholder(cardholder.id);
    });
  }

  Future<void> _downloadCuentaIndividual(AccountLedger ledger) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Individual',
      infoFields: [
        MapEntry('Titular', _selected!.fullName),
        MapEntry('Identificación', '${_selected!.idDocumentType.label} ${_selected!.idDocumentNumber}'),
        MapEntry('Generado por', widget.session.email),
      ],
      balance: ledger.balance,
      currency: ledger.currency,
      periodLabel: 'Historial completo',
      rows: [
        for (final e in ledger.entries)
          PdfStatementRow(
            date: formatDateTime(e.createdAt),
            isCredit: e.type == LedgerEntryType.credit,
            description: e.description ?? e.type.label,
            amount: e.amount,
            balanceAfter: e.balanceAfter,
          ),
      ],
    );
    if (!mounted) return;
    try {
      downloadPdf('estado-de-cuenta-${_selected!.id}-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  Future<void> _downloadTarjeta(PaymentCard card, LedgerAccount ledgerAccount, List<LedgerEntry> entries) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Movimientos de Tarjeta ${card.maskedPan}',
      infoFields: [
        MapEntry('Titular', _selected!.fullName),
        MapEntry('Tarjeta', card.maskedPan),
        MapEntry('Generado por', widget.session.email),
      ],
      balance: ledgerAccount.balance,
      currency: ledgerAccount.currency,
      periodLabel: 'Historial completo',
      rows: [
        for (final e in entries)
          PdfStatementRow(
            date: formatDateTime(e.createdAt),
            isCredit: e.type == LedgerEntryType.credit,
            description: e.description ?? e.type.label,
            amount: e.amount,
            balanceAfter: e.balanceAfter,
          ),
      ],
    );
    if (!mounted) return;
    try {
      downloadPdf('movimientos-${card.id}-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cardholder>>(
      future: _cardholdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final cardholders = snapshot.data ?? const [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardholderSearchField(candidates: cardholders, onChanged: _select),
              const SizedBox(height: 16),
              if (_selected == null)
                Expanded(
                  child: Center(
                    child: Text('Busca un Tarjetahabiente para ver su Cuenta Individual.', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                )
              else
                Expanded(
                  child: FutureBuilder<AccountLedger>(
                    future: _ledgerFuture,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final ledger = snap.data!;
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selected!.fullName, style: Theme.of(context).textTheme.titleMedium),
                                    Text(
                                      formatCurrency(ledger.balance, ledger.currency),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KoonsColors.navy),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => _downloadCuentaIndividual(ledger),
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Descargar Cuenta Individual'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Movimientos de la Cuenta Individual (todas sus tarjetas)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 8),
                            _MovementsListView(
                              currency: ledger.currency,
                              rows: [
                                for (final e in ledger.entries)
                                  _MovementRow(
                                    date: formatDateTime(e.createdAt),
                                    isCredit: e.type == LedgerEntryType.credit,
                                    description: e.description ?? e.type.label,
                                    amount: e.amount,
                                    balanceAfter: e.balanceAfter,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text('Ver por tarjeta', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            FutureBuilder<List<PaymentCard>>(
                              future: _cardsFuture,
                              builder: (context, cardsSnap) {
                                if (cardsSnap.connectionState != ConnectionState.done) {
                                  return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
                                }
                                final cards = cardsSnap.data ?? const [];
                                if (cards.isEmpty) {
                                  return Text('Sin tarjetas asignadas.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic));
                                }
                                return Column(
                                  children: [
                                    for (final card in cards)
                                      _CardMovementsExpansion(
                                        card: card,
                                        expanded: _expandedCardId == card.id,
                                        onToggle: () => setState(() {
                                          _expandedCardId = _expandedCardId == card.id ? null : card.id;
                                          _cardLedgerFutures.putIfAbsent(card.id, () => widget.ledgerRepository.getByCard(card.id));
                                        }),
                                        ledgerFuture: _cardLedgerFutures[card.id],
                                        ledgerRepository: widget.ledgerRepository,
                                        onDownload: _downloadTarjeta,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CardMovementsExpansion extends StatelessWidget {
  const _CardMovementsExpansion({
    required this.card,
    required this.expanded,
    required this.onToggle,
    required this.ledgerFuture,
    required this.ledgerRepository,
    required this.onDownload,
  });

  final PaymentCard card;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<LedgerAccount?>? ledgerFuture;
  final LedgerRepository ledgerRepository;
  final Future<void> Function(PaymentCard card, LedgerAccount ledgerAccount, List<LedgerEntry> entries) onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            leading: const Icon(Icons.credit_card_rounded, color: KoonsColors.blue),
            title: Text(card.maskedPan),
            trailing: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.grey.shade500),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FutureBuilder<LedgerAccount?>(
                future: ledgerFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()));
                  }
                  final account = snap.data;
                  if (account == null) {
                    return Text('Esta tarjeta no tiene cuenta de saldo.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic));
                  }
                  return FutureBuilder<List<LedgerEntry>>(
                    future: ledgerRepository.listEntries(account.id),
                    builder: (context, entriesSnap) {
                      if (entriesSnap.connectionState != ConnectionState.done) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()));
                      }
                      final entries = entriesSnap.data ?? const [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => onDownload(card, account, entries),
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Descargar'),
                            ),
                          ),
                          _MovementsListView(
                            currency: account.currency,
                            rows: [
                              for (final e in entries)
                                _MovementRow(
                                  date: formatDateTime(e.createdAt),
                                  isCredit: e.type == LedgerEntryType.credit,
                                  description: e.description ?? e.type.label,
                                  amount: e.amount,
                                  balanceAfter: e.balanceAfter,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
