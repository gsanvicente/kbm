import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/card_status.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/claim_status.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../core/models/shared/card_limit_exceeded_exception.dart';
import '../../core/models/shared/cardholder_inactive_exception.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/card_destination_field.dart';
import '../../shared_widgets/confirm_dialog.dart';
import '../../shared_widgets/currency_field.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../balance_operations/operaciones_de_saldo_section.dart' show BalanceOperationTile;
import '../cardholders/cardholder_repository.dart';
import '../ledger/ledger_repository.dart';
import 'card_repository.dart';
import 'payment_card_visual.dart';

class CardDetailView extends StatefulWidget {
  const CardDetailView({
    super.key,
    required this.card,
    this.cardholderName,
    required this.cardRepository,
    required this.cardholderRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
    required this.session,
    required this.onChanged,
  });

  final PaymentCard card;
  final String? cardholderName;
  final CardRepository cardRepository;
  final CardholderRepository cardholderRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;
  final Session session;

  /// Called after a successful assignment — see
  /// CardholderDetailView.onChanged for why this is needed with fake
  /// repositories (already-fetched Futures elsewhere won't auto-refresh).
  final ValueChanged<PaymentCard> onChanged;

  @override
  State<CardDetailView> createState() => _CardDetailViewState();
}

class _CardDetailViewState extends State<CardDetailView> with SingleTickerProviderStateMixin {
  late PaymentCard _card = widget.card;
  String? _cardholderName;
  bool _busy = false;
  late Future<LedgerAccount?> _ledgerFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _cardholderName = widget.cardholderName;
    _ledgerFuture = widget.ledgerRepository.getByCard(_card.id);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canManage => widget.session.role.canManageCardholders;
  bool get _canOperate => widget.session.role.canOperateCards;

  /// Called by the "Operaciones" tab after any intento de operación de
  /// saldo, sin importar el resultado — no solo cuando ejecuta. La
  /// versión original solo refrescaba en "executed" (pending_approval/
  /// failed nunca tocan el ledger *por esta operación*), pero eso
  /// asumía que el ledger solo cambia por acciones que esta misma
  /// pantalla dispara. Con `cardholder/` compartiendo el mismo backend
  /// (docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md),
  /// un "failed" por fondos insuficientes casi siempre significa que
  /// alguien más (el propio Tarjetahabiente, típicamente) ya movió el
  /// saldo — vale la pena refrescar la pantalla también en ese caso.
  /// Re-fetching feeds the same _ledgerFuture that both "Resumen" and
  /// "Movimientos" already key their FutureBuilder off of, so both
  /// refresh — not just the balance number. See
  /// docs/feature/operacion-saldo-con-aprobacion/README.md, "Refresco
  /// del saldo mostrado".
  void _refreshLedger() {
    setState(() {
      _ledgerFuture = widget.ledgerRepository.getByCard(_card.id);
    });
  }

  // Incluye `frozen` (autocongelamiento del propio Tarjetahabiente) —
  // un bloqueo de staff siempre pesa más y puede aplicarse sobre una
  // tarjeta congelada, no solo sobre una activa. Ver
  // docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
  // bloquear una tarjeta".
  bool get _canToggleBlock =>
      _card.cardholderId != null &&
      (_card.status == CardStatus.active || _card.status == CardStatus.blocked || _card.status == CardStatus.frozen);

  Future<void> _toggleBlocked() async {
    final blocking = _card.status != CardStatus.blocked;
    final confirmed = await showConfirmDialog(
      context,
      title: blocking ? 'Bloquear tarjeta' : 'Desbloquear tarjeta',
      message: blocking
          ? '¿Deseas bloquear la tarjeta ${_card.maskedPan}? Dejará de poder usarse hasta que la desbloquees.'
          : '¿Deseas desbloquear la tarjeta ${_card.maskedPan}? Podrá volver a usarse de inmediato.',
      destructive: blocking,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final updated = await widget.cardRepository.setBlocked(_card.id, _card.status != CardStatus.blocked);
      if (!mounted) return;
      setState(() {
        _card = updated;
        _busy = false;
      });
      widget.onChanged(updated);
    } on CardholderInactiveException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    // Un Tarjetahabiente inactivo no puede recibir tarjetas nuevas — ver
    // docs/business/desactivacion-de-tarjetahabientes.md. Uno que ya
    // alcanzó su límite de tarjetas activas tampoco — ver
    // docs/business/tarjetas-y-asignacion.md, "Límite de tarjetas activas
    // por Tarjetahabiente". Ambos se filtran aquí (no solo se confía en
    // el chequeo del repositorio) para no ofrecer una opción que de
    // todas formas se va a rechazar.
    final max = await widget.cardRepository.maxActiveCardsPerCardholder(_card.clientId);
    final clientCards = max != null ? await widget.cardRepository.listByClients([_card.clientId]) : const <PaymentCard>[];
    final activeCountByCardholder = <String, int>{};
    for (final c in clientCards) {
      if (c.cardholderId != null && c.status == CardStatus.active) {
        activeCountByCardholder[c.cardholderId!] = (activeCountByCardholder[c.cardholderId!] ?? 0) + 1;
      }
    }
    final candidates = (await widget.cardholderRepository.listByClient(_card.clientId))
        .where((c) => c.isActive)
        .where((c) => max == null || (activeCountByCardholder[c.id] ?? 0) < max)
        .toList();
    if (!mounted) return;
    setState(() => _busy = false);

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este Cliente no tiene tarjetahabientes activos para asignar esta tarjeta.')),
      );
      return;
    }

    final selected = await showDialog<Cardholder>(
      context: context,
      builder: (context) => _AssignCardDialog(candidates: candidates),
    );
    if (selected == null) return;

    setState(() => _busy = true);
    try {
      final updated = await widget.cardRepository.assign(cardId: _card.id, cardholderId: selected.id);
      setState(() {
        _card = updated;
        _cardholderName = selected.fullName;
        _ledgerFuture = widget.ledgerRepository.getByCard(updated.id);
        _busy = false;
      });
      widget.onChanged(updated);
    } on CardLimitExceededException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on CardholderInactiveException catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: KoonsColors.navy,
          indicatorColor: KoonsColors.blue,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Movimientos'),
            Tab(text: 'Operaciones'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResumenTab(),
              FutureBuilder<LedgerAccount?>(
                future: _ledgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _MovementsTab(
                    ledger: snapshot.data,
                    ledgerRepository: widget.ledgerRepository,
                    session: widget.session,
                  );
                },
              ),
              FutureBuilder<LedgerAccount?>(
                future: _ledgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _OperationsTab(
                    card: _card,
                    cardholderName: _cardholderName,
                    ledger: snapshot.data,
                    cardRepository: widget.cardRepository,
                    cardholderRepository: widget.cardholderRepository,
                    ledgerRepository: widget.ledgerRepository,
                    balanceOperationRepository: widget.balanceOperationRepository,
                    session: widget.session,
                    onOperationAttempted: _refreshLedger,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenTab() {
    final card = _card;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large hero card — replaces Cliente/Red/Vigencia/Estado as plain
          // rows, since those are now real data drawn on the card itself.
          // Centered (the status badge lives on the card's own corner now
          // that the asset is cropped to its real bounds, no more floating
          // disconnected above it).
          SizedBox(
            width: double.infinity,
            child: Center(child: PaymentCardVisual(card: card, cardholderName: _cardholderName, width: 440)),
          ),
          const SizedBox(height: 20),
          // Saldo — el dato central de la aplicación, mostrado aparte de
          // la tarjeta (una tarjeta física real nunca imprime el saldo).
          // Ver docs/business/saldo-y-ledger.md.
          SizedBox(
            width: double.infinity,
            child: Center(
              child: FutureBuilder<LedgerAccount?>(
                future: _ledgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final ledger = snapshot.data;
                  return _BalanceCard(card: card, ledger: ledger);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (_canManage && !_busy && card.isAvailable)
                  FilledButton.icon(
                    onPressed: _assign,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Asignar'),
                  ),
                if (_canOperate && !_busy && _canToggleBlock)
                  OutlinedButton.icon(
                    onPressed: _toggleBlocked,
                    icon: Icon(
                      card.status == CardStatus.blocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    label: Text(card.status == CardStatus.blocked ? 'Desbloquear' : 'Bloquear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          card.status == CardStatus.blocked ? null : Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          if (!_canManage && card.isAvailable) ...[
            const SizedBox(height: 16),
            Text(
              'Tu rol (${widget.session.role.label}) puede ver esta tarjeta pero no asignarla.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ],
          if (!_canOperate && _canToggleBlock) ...[
            const SizedBox(height: 16),
            Text(
              'Tu rol (${widget.session.role.label}) puede ver esta tarjeta pero no bloquearla ni desbloquearla.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.card, required this.ledger});

  final PaymentCard card;
  final LedgerAccount? ledger;

  @override
  Widget build(BuildContext context) {
    // Disponible (unassigned) never has a ledger_account — distinct from
    // an assigned card whose account happens to be at zero. See
    // docs/business/saldo-y-ledger.md.
    final noAccount = card.isAvailable || ledger == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: noAccount ? Colors.grey.shade100 : KoonsColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: noAccount ? Colors.grey.shade300 : KoonsColors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'SALDO ACTUAL',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noAccount ? 'Sin cuenta de saldo' : formatCurrency(ledger!.balance, ledger!.currency),
            style: TextStyle(
              fontSize: noAccount ? 16 : 28,
              fontWeight: FontWeight.w700,
              color: noAccount ? Colors.grey.shade500 : KoonsColors.navy,
              fontStyle: noAccount ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (card.isAvailable) ...[
            const SizedBox(height: 4),
            Text(
              'Se crea automáticamente al asignar la tarjeta',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _AssignCardDialog extends StatefulWidget {
  const _AssignCardDialog({required this.candidates});

  final List<Cardholder> candidates;

  @override
  State<_AssignCardDialog> createState() => _AssignCardDialogState();
}

class _AssignCardDialogState extends State<_AssignCardDialog> {
  Cardholder? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar tarjeta'),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<Cardholder>(
          key: const Key('assign-dropdown'),
          initialValue: _selected,
          decoration: const InputDecoration(labelText: 'Tarjetahabiente'),
          items: [
            for (final cardholder in widget.candidates)
              DropdownMenuItem(value: cardholder, child: Text(cardholder.fullName)),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
          child: const Text('Asignar'),
        ),
      ],
    );
  }
}

/// Historial de movimientos de una tarjeta ya asignada, con acceso al
/// detalle de reclamos. Ver docs/feature/reclamos-de-movimientos/.
class _MovementsTab extends StatefulWidget {
  const _MovementsTab({required this.ledger, required this.ledgerRepository, required this.session});

  final LedgerAccount? ledger;
  final LedgerRepository ledgerRepository;
  final Session session;

  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab> {
  List<LedgerEntry> _entries = [];
  Map<String, MovementClaim> _claims = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.ledger != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final ledger = widget.ledger!;
    final entries = await widget.ledgerRepository.listEntries(ledger.id);
    final claims = await widget.ledgerRepository.getClaims(entries.map((e) => e.id).toList());
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _claims = claims;
      _loading = false;
    });
  }

  void _onClaimChanged(String ledgerEntryId, MovementClaim claim) {
    setState(() => _claims = {..._claims, ledgerEntryId: claim});
  }

  Future<void> _openEntry(LedgerEntry entry) async {
    await showDialog(
      context: context,
      builder: (context) => _MovementDetailDialog(
        entry: entry,
        cardId: widget.ledger!.cardId,
        currency: widget.ledger!.currency,
        claim: _claims[entry.id],
        ledgerRepository: widget.ledgerRepository,
        session: widget.session,
        onClaimChanged: (claim) => _onClaimChanged(entry.id, claim),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ledger == null) {
      return Center(
        child: Text(
          'Sin cuenta de saldo — no hay movimientos.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay movimientos en esta cuenta.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    final currency = widget.ledger!.currency;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final claim = _claims[entry.id];
        final isCredit = entry.type == LedgerEntryType.credit;
        return ListTile(
          onTap: () => _openEntry(entry),
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
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${formatCurrency(entry.amount, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isCredit ? Colors.green.shade700 : KoonsColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              if (claim != null) _ClaimBadge(status: claim.status) else const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

class _ClaimBadge extends StatelessWidget {
  const _ClaimBadge({required this.status});

  final ClaimStatus status;

  Color get _color {
    switch (status) {
      case ClaimStatus.open:
      case ClaimStatus.inReview:
        return Colors.orange.shade800;
      case ClaimStatus.resolvedFavor:
        return Colors.green.shade700;
      case ClaimStatus.rejected:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Detalle de un movimiento y su reclamo, si existe. Vive en un diálogo,
/// no en un nuevo nivel de breadcrumb — ver
/// docs/business/reclamos-de-movimientos.md, sección "Dónde vive esto en
/// la UI".
class _MovementDetailDialog extends StatefulWidget {
  const _MovementDetailDialog({
    required this.entry,
    required this.cardId,
    required this.currency,
    required this.claim,
    required this.ledgerRepository,
    required this.session,
    required this.onClaimChanged,
  });

  final LedgerEntry entry;
  final String cardId;
  final String currency;
  final MovementClaim? claim;
  final LedgerRepository ledgerRepository;
  final Session session;
  final ValueChanged<MovementClaim> onClaimChanged;

  @override
  State<_MovementDetailDialog> createState() => _MovementDetailDialogState();
}

class _MovementDetailDialogState extends State<_MovementDetailDialog> {
  late MovementClaim? _claim = widget.claim;
  bool _filing = false;
  bool _resolving = false;
  bool _resolvingFavor = true;
  bool _busy = false;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canFile => widget.session.role.canFileClaims;
  bool get _canResolve => widget.session.role.canResolveClaims;

  Future<void> _submitClaim() async {
    if (_reasonController.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final claim = await widget.ledgerRepository.fileClaim(
      ledgerEntryId: widget.entry.id,
      cardId: widget.cardId,
      reason: _reasonController.text.trim(),
      requestedByEmail: widget.session.email,
    );
    if (!mounted) return;
    setState(() {
      _claim = claim;
      _filing = false;
      _busy = false;
    });
    widget.onClaimChanged(claim);
  }

  Future<void> _submitResolution() async {
    if (_notesController.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final claim = await widget.ledgerRepository.resolveClaim(
      claimId: _claim!.id,
      cardId: widget.cardId,
      inFavor: _resolvingFavor,
      resolutionNotes: _notesController.text.trim(),
      resolvedByEmail: widget.session.email,
    );
    if (!mounted) return;
    setState(() {
      _claim = claim;
      _resolving = false;
      _busy = false;
    });
    widget.onClaimChanged(claim);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isCredit = entry.type == LedgerEntryType.credit;

    return AlertDialog(
      title: const Text('Detalle del movimiento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(label: 'Descripción', value: entry.description ?? entry.type.label),
              _InfoRow(
                label: 'Monto',
                value: '${isCredit ? '+' : '-'}${formatCurrency(entry.amount, widget.currency)}',
              ),
              _InfoRow(label: 'Saldo resultante', value: formatCurrency(entry.balanceAfter, widget.currency)),
              _InfoRow(label: 'Fecha', value: formatDateTime(entry.createdAt)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Reclamo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _buildClaimSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }

  Widget _buildClaimSection() {
    final claim = _claim;

    if (claim == null) {
      if (_filing) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Motivo del reclamo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _filing = false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _submitClaim,
                  child: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar reclamo'),
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No se ha reclamado este movimiento.', style: TextStyle(color: Colors.grey.shade600)),
          if (_canFile) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(() => _filing = true),
              icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
              label: const Text('Reclamar este movimiento'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Tu rol (${widget.session.role.label}) no puede solicitar reclamos.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [_ClaimBadge(status: claim.status), const SizedBox(width: 8), Expanded(child: Text(claim.reason))]),
        const SizedBox(height: 10),
        _InfoRow(label: 'Solicitado por', value: claim.requestedByEmail),
        _InfoRow(label: 'Fecha de solicitud', value: formatDateTime(claim.createdAt)),
        if (claim.status.isResolved) ...[
          _InfoRow(label: 'Resuelto por', value: claim.resolvedByEmail ?? '—'),
          _InfoRow(label: 'Fecha de resolución', value: claim.resolvedAt != null ? formatDateTime(claim.resolvedAt!) : '—'),
          _InfoRow(label: 'Notas de resolución', value: claim.resolutionNotes ?? '—'),
        ] else if (_resolving) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _resolvingFavor ? 'Notas de resolución (a favor)' : 'Motivo del rechazo',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _resolving = false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _submitResolution,
                style: FilledButton.styleFrom(
                  backgroundColor: _resolvingFavor ? Colors.green.shade700 : Colors.red.shade700,
                ),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_resolvingFavor ? 'Confirmar a favor' : 'Confirmar rechazo'),
              ),
            ],
          ),
        ] else if (_canResolve) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _resolving = true;
                  _resolvingFavor = true;
                }),
                icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.green.shade700),
                label: const Text('Resolver a favor'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _resolving = true;
                  _resolvingFavor = false;
                }),
                icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade700),
                label: const Text('Rechazar'),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Tu rol (${widget.session.role.label}) no puede resolver reclamos.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}

/// Historial de operaciones de saldo de esta tarjeta, con las acciones
/// para solicitar una nueva — la tarjeta origen nunca se pregunta, es
/// implícitamente la que ya se está viendo. Ver
/// docs/feature/operacion-saldo-con-aprobacion/README.md.
class _OperationsTab extends StatefulWidget {
  const _OperationsTab({
    required this.card,
    required this.cardholderName,
    required this.ledger,
    required this.cardRepository,
    required this.cardholderRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
    required this.session,
    required this.onOperationAttempted,
  });

  final PaymentCard card;
  final String? cardholderName;
  final LedgerAccount? ledger;
  final CardRepository cardRepository;
  final CardholderRepository cardholderRepository;

  /// Solo para releer el saldo justo antes de abrir el diálogo de una
  /// nueva operación (ver `_openOperationDialog`) — `widget.ledger` es
  /// una foto tomada cuando se abrió esta pestaña, que puede llevar rato
  /// desactualizada si `cardholder/` movió saldo de esta misma tarjeta
  /// mientras tanto (comparten backend, ver
  /// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md).
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;
  final Session session;

  /// Called after any intento de operación de saldo — ver
  /// CardDetailView._refreshLedger, que esto dispara.
  final VoidCallback onOperationAttempted;

  @override
  State<_OperationsTab> createState() => _OperationsTabState();
}

class _OperationsData {
  _OperationsData(this.operations, this.siblingCards, this.cardholderNameById);
  final List<BalanceOperation> operations;
  final List<PaymentCard> siblingCards;
  final Map<String, String> cardholderNameById;
}

class _OperationsTabState extends State<_OperationsTab> {
  Future<_OperationsData>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.ledger != null) {
      _future = _load();
    }
  }

  Future<_OperationsData> _load() async {
    final allOps = await widget.balanceOperationRepository.listByClients([widget.card.clientId]);
    final siblingCards = await widget.cardRepository.listByClients([widget.card.clientId]);
    final cardholders = await widget.cardholderRepository.listByClient(widget.card.clientId);
    return _OperationsData(
      allOps.where((op) => op.cardId == widget.card.id).toList(),
      siblingCards,
      {for (final c in cardholders) c.id: c.fullName},
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openOperationDialog(OperationType type, _OperationsData data) async {
    final eligibleDestinations = data.siblingCards
        .where((c) => c.cardholderId != null && c.status != CardStatus.cancelled && c.id != widget.card.id)
        .toList();

    // Relee el saldo justo antes de abrir el diálogo — `widget.ledger`
    // puede llevar rato en pantalla, y `cardholder/` pudo haber movido
    // saldo de esta misma tarjeta mientras tanto. No reemplaza la
    // validación del backend (que siempre relee el saldo real al
    // ejecutar, ver PostEntry en store.go), pero evita que quien decide
    // el monto lo haga mirando un número viejo.
    final freshLedger = await widget.ledgerRepository.getByCard(widget.card.id);
    if (!mounted) return;

    final result = await showDialog<BalanceOperation>(
      context: context,
      builder: (context) => _BalanceOperationDialog(
        type: type,
        card: widget.card,
        cardholderName: widget.cardholderName,
        currentLedger: freshLedger ?? widget.ledger,
        destinationCandidates: eligibleDestinations,
        cardholderNameById: data.cardholderNameById,
        session: widget.session,
        repository: widget.balanceOperationRepository,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    _reload();
    // Cualquier intento real (ejecutado, pendiente o fallido) refresca
    // el saldo mostrado — ver el doc de CardDetailView._refreshLedger
    // para el porqué de incluir "failed" ahora.
    widget.onOperationAttempted();

    final message = switch (result.status) {
      OperationStatus.executed => 'Operación ejecutada de inmediato.',
      OperationStatus.pendingApproval => 'Operación registrada, queda pendiente de aprobación.',
      OperationStatus.failed => 'Operación fallida: ${result.resolutionNotes}',
      _ => 'Operación registrada.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ledger == null) {
      return Center(
        child: Text(
          'Sin cuenta de saldo — no hay operaciones.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    return FutureBuilder<_OperationsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final canRequest = widget.session.role.canRequestBalanceOperations;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canRequest)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openOperationDialog(OperationType.load, data),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: Text(OperationType.load.label),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openOperationDialog(OperationType.debit, data),
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                      label: Text(OperationType.debit.label),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openOperationDialog(OperationType.transfer, data),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(OperationType.transfer.label),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tu rol (${widget.session.role.label}) puede ver estas operaciones pero no solicitar nuevas.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: data.operations.isEmpty
                  ? Center(
                      child: Text(
                        'Aún no hay operaciones de saldo sobre esta tarjeta.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.operations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final op = data.operations[index];
                        PaymentCard? destination;
                        if (op.destinationCardId != null) {
                          final matches = data.siblingCards.where((c) => c.id == op.destinationCardId);
                          destination = matches.isEmpty ? null : matches.first;
                        }
                        return BalanceOperationTile(
                          operation: op,
                          card: widget.card,
                          destinationCard: destination,
                          cardholderName: widget.cardholderName,
                          clientName: '',
                          currency: widget.ledger!.currency,
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

class _BalanceOperationDialog extends StatefulWidget {
  const _BalanceOperationDialog({
    required this.type,
    required this.card,
    required this.cardholderName,
    required this.currentLedger,
    required this.destinationCandidates,
    required this.cardholderNameById,
    required this.session,
    required this.repository,
  });

  final OperationType type;
  final PaymentCard card;
  final String? cardholderName;

  /// Saldo justo antes de abrir este diálogo (ver
  /// `_OperationsTab._openOperationDialog`) — null solo si la tarjeta no
  /// tiene cuenta de saldo, lo cual no debería pasar aquí (esta pestaña
  /// no se muestra sin `ledger`).
  final LedgerAccount? currentLedger;
  final List<PaymentCard> destinationCandidates;
  final Map<String, String> cardholderNameById;
  final Session session;
  final BalanceOperationRepository repository;

  @override
  State<_BalanceOperationDialog> createState() => _BalanceOperationDialogState();
}

class _BalanceOperationDialogState extends State<_BalanceOperationDialog> {
  double _amount = 0;
  PaymentCard? _destination;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_amount <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }
    if (widget.type == OperationType.transfer && _destination == null) {
      setState(() => _error = 'Escribe la terminación de una tarjeta destino válida.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.request(
      clientId: widget.card.clientId,
      cardId: widget.card.id,
      type: widget.type,
      amount: _amount,
      destinationCardId: widget.type == OperationType.transfer ? _destination!.id : null,
      requestedByEmail: widget.session.email,
    );
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva operación'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.type.label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: KoonsColors.navy),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.cardholderName ?? '—'} · ${widget.card.maskedPan}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              if (widget.currentLedger != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Saldo disponible: ${formatCurrency(widget.currentLedger!.balance, widget.currentLedger!.currency)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: KoonsColors.navy),
                ),
              ],
              const SizedBox(height: 20),
              CurrencyField(onChanged: (value) => _amount = value, autofocus: true),
              if (widget.type == OperationType.transfer) ...[
                const SizedBox(height: 16),
                CardDestinationField(
                  candidates: widget.destinationCandidates,
                  cardholderNameById: widget.cardholderNameById,
                  onResolved: (card) => setState(() => _destination = card),
                ),
              ],
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
              : const Text('Solicitar'),
        ),
      ],
    );
  }
}
