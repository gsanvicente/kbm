import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/ledger_movement.dart';
import '../../core/models/movement_claim.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/pdf_download.dart';
import '../../shared_widgets/pdf_statement.dart';
import '../spei/spei_repository.dart';
import 'card_repository.dart';

enum _Period { all, thisMonth, lastMonth, custom }

/// Pestaña "Movimientos" — la vista completa e histórica de la Cuenta
/// (ver docs/adr/0020-cuenta-individual-tarjetahabiente.md: Dispersión,
/// Deducción, Transferencia C2C y SPEI entrante/saliente todos afectan
/// el mismo saldo, así que todos aparecen aquí mezclados, un solo
/// listado). [loadMovements] desacopla esta pantalla de que exista una
/// tarjeta: `CardholderShell` la llama con
/// `cardRepository.listMovements(card.id)`, y el Tarjetahabiente sin
/// ninguna tarjeta asignada (`HomeShell._AccountOnlyShell`) con
/// `speiRepository.getAccountLedger(cardholderId).movements` — mismo
/// dato real (la misma Cuenta), dos formas válidas de pedirlo. Ver
/// docs/adr/0028-reorganizacion-ux-cardholder.md.
class MovementsTab extends StatefulWidget {
  const MovementsTab({
    super.key,
    required this.headerLabel,
    required this.currency,
    required this.accountBalance,
    required this.loadMovements,
    required this.cardRepository,
    required this.speiRepository,
    required this.cardholderId,
    required this.cardholderName,
  });

  final String headerLabel;
  final String currency;

  /// Saldo actual de la Cuenta — para el bloque de identificación del
  /// PDF descargable (ver "Descargar estado de cuenta" más abajo), no
  /// para ningún cálculo en pantalla (el saldo puntual ya se muestra en
  /// "Inicio").
  final double accountBalance;

  final Future<List<LedgerMovement>> Function() loadMovements;
  final CardRepository cardRepository;
  final SpeiRepository speiRepository;
  final String cardholderId;
  final String cardholderName;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  late final Future<List<LedgerMovement>> _future = widget.loadMovements();

  // Los comprobantes SPEI (folio, CLABE, estatus) no viven en
  // LedgerMovement — se piden una sola vez, perezosamente, la primera
  // vez que se toca un movimiento que se ve como SPEI (ver
  // `_looksLikeSpei`), y se cachean aquí para no repetir la llamada en
  // cada tap. Nunca se piden por adelantado para toda la lista (mismo
  // criterio anti-N+1 que ya documenta `_MovementClaimDialog`).
  Future<List<SpeiPayment>>? _paymentsFuture;
  Future<List<SpeiDeposit>>? _depositsFuture;

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

  bool _looksLikeSpei(String? description) =>
      description != null && (description.startsWith('Pago SPEI') || description.startsWith('Depósito SPEI'));

  /// Busca, dentro de los pagos/depósitos SPEI del propio Tarjetahabiente,
  /// el que corresponde a [movement] — por monto exacto y el timestamp
  /// más cercano dentro de una ventana corta. `LedgerMovement` no trae un
  /// folio ni la CLABE del beneficiario (esos datos viven en
  /// `SpeiPayment`/`SpeiDeposit`, no en el ledger genérico), así que esto
  /// es lo más cercano a una relación real sin un campo de referencia
  /// explícito en el backend — ver "Limitación conocida" en
  /// docs/adr/0028-reorganizacion-ux-cardholder.md. Un movimiento
  /// genuino de SPEI siempre tiene una coincidencia exacta de monto y
  /// prácticamente el mismo instante (se crean en la misma transacción),
  /// así que el margen de error real es mínimo.
  Future<Object?> _resolveSpeiMatch(LedgerMovement movement) async {
    if (movement.type == LedgerEntryType.credit) {
      _depositsFuture ??= widget.speiRepository.listDeposits(widget.cardholderId);
      final deposits = await _depositsFuture!;
      return _closestMatch<SpeiDeposit>(deposits, movement, (d) => d.amount, (d) => d.createdAt);
    } else {
      _paymentsFuture ??= widget.speiRepository.listPayments(widget.cardholderId);
      final payments = await _paymentsFuture!;
      return _closestMatch<SpeiPayment>(payments, movement, (p) => p.amount, (p) => p.createdAt);
    }
  }

  T? _closestMatch<T>(
    List<T> candidates,
    LedgerMovement movement,
    double Function(T) amountOf,
    DateTime Function(T) createdAtOf,
  ) {
    T? best;
    Duration? bestDelta;
    for (final c in candidates) {
      if (amountOf(c) != movement.amount) continue;
      final delta = createdAtOf(c).difference(movement.createdAt).abs();
      if (delta > const Duration(minutes: 5)) continue;
      if (bestDelta == null || delta < bestDelta) {
        best = c;
        bestDelta = delta;
      }
    }
    return best;
  }

  Future<void> _downloadStatement(List<LedgerMovement> movements) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Individual',
      infoFields: [MapEntry('Titular', widget.cardholderName)],
      balance: widget.accountBalance,
      currency: widget.currency,
      periodLabel: 'Historial completo',
      rows: [
        for (final m in movements)
          PdfStatementRow(
            date: formatMovementDate(m.createdAt),
            isCredit: m.type == LedgerEntryType.credit,
            description: m.description ?? '',
            amount: m.amount,
            balanceAfter: m.balanceAfter,
          ),
      ],
    );
    if (!mounted) return;
    try {
      downloadPdf('estado-de-cuenta-${widget.cardholderId}-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  Future<void> _openMovement(LedgerMovement movement) async {
    Object? speiMatch;
    if (_looksLikeSpei(movement.description)) {
      speiMatch = await _resolveSpeiMatch(movement);
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _MovementDetailDialog(
        movement: movement,
        speiMatch: speiMatch,
        cardRepository: widget.cardRepository,
      ),
    );
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.headerLabel,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoonsColors.navy),
                        ),
                      ),
                      if (allMovements.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _downloadStatement(allMovements),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Descargar'),
                        ),
                    ],
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
                    child: _PeriodSummaryCard(credits: credits, debits: debits, currency: widget.currency),
                  ),
                ],
                if (movements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      allMovements.isEmpty ? 'Aún no hay movimientos en tu Cuenta.' : 'No hay movimientos en el periodo seleccionado.',
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
                        currency: widget.currency,
                        onTap: () => _openMovement(movements[index]),
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
  const _MovementTile({required this.movement, required this.currency, required this.onTap});

  final LedgerMovement movement;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCredit = movement.type == LedgerEntryType.credit;
    final color = isCredit ? KoonsColors.green : KoonsColors.navy;
    final sign = isCredit ? '+' : '−';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
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

/// Detalle de un movimiento — si se identificó como un pago/depósito
/// SPEI (ver `_looksLikeSpei`/`_resolveSpeiMatch` en `MovementsTab`),
/// muestra primero su comprobante real (folio, CLABE/beneficiario,
/// estatus); siempre, sin importar el origen, deja ver/presentar un
/// reclamo — un movimiento SPEI sigue siendo dinero real que se puede
/// disputar, igual que cualquier otro.
class _MovementDetailDialog extends StatefulWidget {
  const _MovementDetailDialog({required this.movement, required this.speiMatch, required this.cardRepository});

  final LedgerMovement movement;
  final Object? speiMatch;
  final CardRepository cardRepository;

  @override
  State<_MovementDetailDialog> createState() => _MovementDetailDialogState();
}

class _MovementDetailDialogState extends State<_MovementDetailDialog> {
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
    final match = widget.speiMatch;
    return AlertDialog(
      title: const Text('Detalle del movimiento'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
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
                  if (match is SpeiPayment) ...[
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Folio', value: match.id),
                    _DetailRow(label: 'Beneficiario', value: match.beneficiaryAlias),
                    _DetailRow(label: 'CLABE destino', value: match.beneficiaryClabe),
                    _DetailRow(label: 'Estatus', value: match.status.label),
                  ] else if (match is SpeiDeposit) ...[
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Folio', value: match.id),
                    _DetailRow(label: 'Referencia', value: match.providerReference),
                  ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
        ],
      ),
    );
  }
}
