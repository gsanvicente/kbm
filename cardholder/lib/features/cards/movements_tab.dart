import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/ledger_movement.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import 'card_repository.dart';

enum _Period { all, thisMonth, lastMonth, custom }

/// Pestaña "Movimientos" dentro de `CardholderShell` — lista de la
/// cuenta con filtro por periodo y resumen (depósitos/cargos/neto) del
/// rango seleccionado, más "bancario" que el historial que ve el staff
/// (ver docs/feature/portal-autoservicio-tarjetahabiente/README.md).
class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key, required this.card, required this.cardRepository});

  final PaymentCard card;
  final CardRepository cardRepository;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  late final Future<List<LedgerMovement>> _future = widget.cardRepository.listMovements(widget.card.id);

  _Period _period = _Period.all;
  DateTimeRange? _customRange;

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  List<LedgerMovement> _filter(List<LedgerMovement> movements) {
    switch (_period) {
      case _Period.all:
        return movements;
      case _Period.thisMonth:
        final now = DateTime.now();
        return movements.where((m) => _isSameMonth(m.createdAt, now)).toList();
      case _Period.lastMonth:
        final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
        return movements.where((m) => _isSameMonth(m.createdAt, lastMonth)).toList();
      case _Period.custom:
        final range = _customRange;
        if (range == null) return movements;
        // endDate inclusivo de todo su día, no solo su medianoche.
        final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
        return movements.where((m) => !m.createdAt.isBefore(range.start) && !m.createdAt.isAfter(end)).toList();
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _period = _Period.custom;
      _customRange = picked;
    });
  }

  String get _periodLabel {
    switch (_period) {
      case _Period.all:
        return 'Todo';
      case _Period.thisMonth:
        return 'Este mes';
      case _Period.lastMonth:
        return 'Mes pasado';
      case _Period.custom:
        final range = _customRange!;
        return '${formatMovementDate(range.start).split(',').first} – ${formatMovementDate(range.end).split(',').first}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LedgerMovement>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final allMovements = snapshot.data!;
        final movements = _filter(allMovements);

        double credits = 0;
        double debits = 0;
        for (final m in movements) {
          if (m.type == LedgerEntryType.credit) {
            credits += m.amount;
          } else {
            debits += m.amount;
          }
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Movimientos · ${widget.card.maskedPan}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoonsColors.navy),
                  ),
                ),
                if (allMovements.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final period in [_Period.all, _Period.thisMonth, _Period.lastMonth])
                          ChoiceChip(
                            label: Text(switch (period) {
                              _Period.all => 'Todo',
                              _Period.thisMonth => 'Este mes',
                              _Period.lastMonth => 'Mes pasado',
                              _Period.custom => 'Personalizado',
                            }),
                            selected: _period == period,
                            onSelected: (_) => setState(() => _period = period),
                          ),
                        ChoiceChip(
                          label: Text(_period == _Period.custom ? _periodLabel : 'Rango personalizado'),
                          selected: _period == _Period.custom,
                          onSelected: (_) => _pickCustomRange(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PeriodSummaryCard(
                      credits: credits,
                      debits: debits,
                      currency: widget.card.currency,
                    ),
                  ),
                ],
                if (movements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      allMovements.isEmpty
                          ? 'Aún no hay movimientos en esta tarjeta.'
                          : 'No hay movimientos en el periodo seleccionado.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: movements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _MovementTile(
                        movement: movements[index],
                        currency: widget.card.currency,
                        cardRepository: widget.cardRepository,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.credits, required this.debits, required this.currency});

  final double credits;
  final double debits;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final net = credits - debits;
    final netColor = net >= 0 ? KoonsColors.green : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KoonsColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryColumn(label: 'Depósitos', value: credits, color: KoonsColors.green, currency: currency)),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          Expanded(child: _SummaryColumn(label: 'Cargos', value: debits, color: KoonsColors.navy, currency: currency)),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          Expanded(child: _SummaryColumn(label: 'Neto', value: net, color: netColor, currency: currency, signed: true)),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.label, required this.value, required this.color, required this.currency, this.signed = false});

  final String label;
  final double value;
  final Color color;
  final String currency;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final sign = signed && value > 0 ? '+' : '';
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          '$sign${formatCurrency(value, currency)}',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.currency, required this.cardRepository});

  final LedgerMovement movement;
  final String currency;
  final CardRepository cardRepository;

  @override
  Widget build(BuildContext context) {
    final isCredit = movement.type == LedgerEntryType.credit;
    final color = isCredit ? KoonsColors.green : KoonsColors.navy;
    final sign = isCredit ? '+' : '−';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => showDialog(
        context: context,
        builder: (context) => _MovementClaimDialog(movement: movement, cardRepository: cardRepository),
      ),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
      ),
      title: Text(movement.description ?? (isCredit ? 'Depósito' : 'Cargo'), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(formatMovementDate(movement.createdAt)),
      trailing: Text(
        '$sign${formatCurrency(movement.amount, currency)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Detalle de un movimiento + su reclamo, si existe — o el formulario
/// para presentar uno nuevo. Consulta el reclamo perezosamente (solo al
/// abrir este diálogo, nunca de una sola vez para toda la lista) para
/// evitar un patrón N+1 sobre `GET .../claim` — ver
/// docs/feature/reclamos-de-movimientos/README.md, "N+1 en reclamos" del
/// lado de `admin/`, el mismo riesgo que aquí se evita desde el diseño.
class _MovementClaimDialog extends StatefulWidget {
  const _MovementClaimDialog({required this.movement, required this.cardRepository});

  final LedgerMovement movement;
  final CardRepository cardRepository;

  @override
  State<_MovementClaimDialog> createState() => _MovementClaimDialogState();
}

class _MovementClaimDialogState extends State<_MovementClaimDialog> {
  late Future<MovementClaim?> _future = widget.cardRepository.getClaim(widget.movement.id);
  late final _reasonController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Escribe el motivo del reclamo.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final claim = await widget.cardRepository.fileClaim(widget.movement.id, reason);
      if (!mounted) return;
      setState(() {
        _future = Future.value(claim);
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = widget.movement.type == LedgerEntryType.credit;
    return AlertDialog(
      title: const Text('Detalle del movimiento'),
      content: SizedBox(
        width: 380,
        child: FutureBuilder<MovementClaim?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final claim = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.movement.description ?? (isCredit ? 'Depósito' : 'Cargo'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(formatMovementDate(widget.movement.createdAt), style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                if (claim != null) ...[
                  Text('Reclamo: ${claim.status.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Motivo: ${claim.reason}'),
                  if (claim.resolutionNotes != null) ...[
                    const SizedBox(height: 4),
                    Text('Resolución: ${claim.resolutionNotes}'),
                  ],
                ] else ...[
                  Text('¿No reconoces este movimiento?', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Motivo del reclamo', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                  ],
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        FutureBuilder<MovementClaim?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || snapshot.data != null) {
              return const SizedBox.shrink();
            }
            return FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Presentar reclamo'),
            );
          },
        ),
      ],
    );
  }
}
