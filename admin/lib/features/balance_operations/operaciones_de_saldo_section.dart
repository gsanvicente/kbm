import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/multi_select_filter_button.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import 'balance_operation_repository.dart';

/// Historial de solo lectura de operaciones de saldo (cualquier estado)
/// dentro del alcance del usuario — crear una operación nueva se hace
/// desde la tarjeta específica (pestaña "Operaciones" de
/// CardDetailView), nunca desde aquí: evita necesitar un selector de
/// "tarjeta origen" que obligaría a listar todas las tarjetas del
/// Cliente. La cola de pendientes por aprobar vive aparte, en
/// AprobacionesSection. Ver
/// docs/feature/operacion-saldo-con-aprobacion/README.md.
class OperacionesDeSaldoSection extends StatefulWidget {
  const OperacionesDeSaldoSection({
    super.key,
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
  State<OperacionesDeSaldoSection> createState() => _OperacionesDeSaldoSectionState();
}

class _ScopeData {
  _ScopeData(this.clients, this.cardholders, this.cards, this.ledgerAccounts, this.operations);
  final List<Client> clients;
  final List<Cardholder> cardholders;
  final List<PaymentCard> cards;
  final Map<String, LedgerAccount> ledgerAccounts;
  final List<BalanceOperation> operations;
}

class _OperacionesDeSaldoSectionState extends State<OperacionesDeSaldoSection> {
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<_ScopeData>(
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
      ),
    );
  }
}

/// Fila reutilizada entre este historial global, la pestaña "Operaciones"
/// de una tarjeta, y "Aprobaciones" — misma información, distinta acción
/// al final (o ninguna).
class BalanceOperationTile extends StatelessWidget {
  const BalanceOperationTile({
    super.key,
    required this.operation,
    required this.card,
    required this.destinationCard,
    required this.cardholderName,
    required this.clientName,
    required this.currency,
    this.trailing,
  });

  final BalanceOperation operation;
  final PaymentCard? card;
  final PaymentCard? destinationCard;
  final String? cardholderName;
  final String clientName;
  final String currency;
  final Widget? trailing;

  IconData get _typeIcon {
    switch (operation.type) {
      case OperationType.load:
        return Icons.add_circle_outline_rounded;
      case OperationType.debit:
        return Icons.remove_circle_outline_rounded;
      case OperationType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardLabel = card?.maskedPan ?? '—';
    final title = operation.type == OperationType.transfer
        ? '${operation.type.label}: $cardLabel → ${destinationCard?.maskedPan ?? '—'}'
        : '${operation.type.label}: $cardLabel';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: KoonsColors.blue.withValues(alpha: 0.1),
        child: Icon(_typeIcon, color: KoonsColors.blue, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // clientName is blank when this tile is shown inside a single
            // card's own "Operaciones" tab — the company is already
            // implied by the screen, no need to repeat it per row.
            [
              cardholderName ?? '—',
              if (clientName.isNotEmpty) clientName,
              formatDateTime(operation.createdAt),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          Text(
            'Solicitado por ${operation.requestedByEmail}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          if (operation.resolutionNotes != null)
            Text(
              operation.resolutionNotes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
      isThreeLine: operation.resolutionNotes != null,
      trailing: trailing ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatCurrency(operation.amount, currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              _StatusBadge(status: operation.status),
            ],
          ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OperationStatus status;

  Color get _color {
    switch (status) {
      case OperationStatus.pendingApproval:
      case OperationStatus.approved:
        return Colors.orange.shade800;
      case OperationStatus.executed:
        return Colors.green.shade700;
      case OperationStatus.rejected:
      case OperationStatus.failed:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
