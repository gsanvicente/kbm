import 'package:flutter/material.dart';

import '../../core/models/balance_operation.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import 'balance_operation_repository.dart';
import 'operaciones_de_saldo_section.dart';

/// Cola de operaciones `pending_approval` dentro del alcance del usuario.
/// Visible para todos (Auditor y Operador incluidos, de solo lectura),
/// pero solo Admin Cliente+ ve los botones de aprobar/rechazar. El
/// historial completo vive en OperacionesDeSaldoSection. Ver
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
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;

  @override
  State<AprobacionesSection> createState() => _AprobacionesSectionState();
}

class _ScopeData {
  _ScopeData(this.clients, this.cardholders, this.cards, this.ledgerAccounts, this.pending);
  final List<Client> clients;
  final List<Cardholder> cardholders;
  final List<PaymentCard> cards;
  final Map<String, LedgerAccount> ledgerAccounts;
  final List<BalanceOperation> pending;
}

class _AprobacionesSectionState extends State<AprobacionesSection> {
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

  Future<void> _approve(BalanceOperation op) async {
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<_ScopeData>(
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
              child: data.pending.isEmpty
                  ? Center(
                      child: Text(
                        'No hay operaciones pendientes de aprobación.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final op = data.pending[index];
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
                                          onPressed: () => _approve(op),
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
      ),
    );
  }
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
