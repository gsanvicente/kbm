import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/dashboard_summary.dart';
import '../../core/models/movement_trend_point.dart';
import '../../core/models/session.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import 'dashboard_repository.dart';

/// Panel directivo — pantalla "Inicio", ver
/// docs/feature/panel-directivo/README.md. Solo para roles con
/// `canViewExecutiveDashboard` (Admin Cliente / Super Admin); AdminShell
/// es responsable de no ofrecer esta sección a los demás roles.
class DashboardSection extends StatefulWidget {
  const DashboardSection({
    super.key,
    required this.session,
    required this.dashboardRepository,
    required this.onNavigateToAprobaciones,
  });

  final Session session;
  final DashboardRepository dashboardRepository;

  /// 0 = Pendientes de aprobación, 1 = Depósitos por conciliar — ver
  /// AprobacionesSection.initialTabIndex.
  final ValueChanged<int> onNavigateToAprobaciones;

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  late Future<DashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.dashboardRepository.getSummary(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar el panel: ${snapshot.error}'));
        }
        final summary = snapshot.data!;
        final clientNameById = {for (final row in summary.clientBreakdown) row.clientId: row.clientName};

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KpiGrid(summary: summary),
              const SizedBox(height: 20),
              if (summary.clientBreakdown.isNotEmpty) ...[
                _ClientBreakdownCard(summary: summary),
                const SizedBox(height: 20),
              ],
              _AttentionCard(
                summary: summary,
                clientNameById: clientNameById,
                onNavigateToAprobaciones: widget.onNavigateToAprobaciones,
              ),
              const SizedBox(height: 20),
              _TrendChartCard(summary: summary),
            ],
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary});

  final DashboardSummary summary;

  // 3 por fila, mismo ancho y alto — un Wrap con anchos libres dejaba 4-5
  // tarjetas por fila en un viewport de escritorio típico, con la última
  // fila desalineada. Con LayoutBuilder calculamos un ancho exacto para
  // que 3 quepan siempre, sin importar el ancho disponible.
  static const _columns = 3;
  static const _spacing = 16.0;
  static const _cardHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        icon: Icons.account_balance_rounded,
        color: KoonsColors.blue,
        label: 'Saldo en Cuentas Concentradoras',
        value: formatCurrency(summary.concentratorBalanceTotal, summary.currency),
      ),
      _KpiCard(
        icon: Icons.credit_card_rounded,
        color: KoonsColors.navy,
        label: 'Saldo cargado en tarjetas',
        value: formatCurrency(summary.cardBalanceTotal, summary.currency),
      ),
      _KpiCard(
        icon: Icons.move_to_inbox_rounded,
        color: Colors.orange.shade800,
        label: 'Depósitos pendientes de conciliar',
        value: formatCurrency(summary.pendingDepositsAmount, summary.currency),
        subtitle: '${summary.pendingDepositsCount} depósito(s)',
      ),
      _KpiCard(
        icon: Icons.fact_check_rounded,
        color: Colors.orange.shade800,
        label: 'Operaciones pendientes de aprobación',
        value: formatCurrency(summary.pendingOperationsAmount, summary.currency),
        subtitle: '${summary.pendingOperationsCount} operación(es)',
      ),
      _KpiCard(
        icon: Icons.report_problem_rounded,
        color: Colors.red.shade700,
        label: 'Reclamos abiertos',
        value: '${summary.openClaimsCount}',
      ),
      _CardsFootprintCard(summary: summary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - _spacing * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, height: _cardHeight, child: card),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: KoonsColors.navy)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardsFootprintCard extends StatelessWidget {
  const _CardsFootprintCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KoonsColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.credit_card_rounded, color: KoonsColors.green, size: 20),
            ),
            const SizedBox(height: 12),
            Text('Estado de tarjetas', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _CardsFootprintStat(label: 'Activas', value: summary.activeCardsCount)),
                Expanded(child: _CardsFootprintStat(label: 'Disponibles', value: summary.availableCardsCount)),
                Expanded(child: _CardsFootprintStat(label: 'Bloq./cong.', value: summary.blockedOrFrozenCardsCount)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsFootprintStat extends StatelessWidget {
  const _CardsFootprintStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KoonsColors.navy)),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ClientBreakdownCard extends StatelessWidget {
  const _ClientBreakdownCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Desglose por empresa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KoonsColors.border))),
                  children: [
                    _headerCell('Empresa'),
                    _headerCell('Saldo Concentradora'),
                    _headerCell('Tarjetas activas'),
                    _headerCell('Operac. pendientes'),
                    _headerCell('Depósitos pendientes'),
                  ],
                ),
                for (final row in summary.clientBreakdown)
                  TableRow(
                    children: [
                      _cell(row.clientName, bold: true),
                      _cell(formatCurrency(row.concentratorBalance, summary.currency)),
                      _cell('${row.activeCardsCount}'),
                      _cell('${row.pendingOperationsCount}'),
                      _cell('${row.pendingDepositsCount}'),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
      );

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      );
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.summary,
    required this.clientNameById,
    required this.onNavigateToAprobaciones,
  });

  final DashboardSummary summary;
  final Map<String, String> clientNameById;
  final ValueChanged<int> onNavigateToAprobaciones;

  bool get _isEmpty => summary.attentionPendingOperations.isEmpty && summary.attentionPendingDeposits.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Requiere tu atención', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            if (_isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Todo al día — sin operaciones ni depósitos pendientes.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            for (final op in summary.attentionPendingOperations)
              _AttentionOperationTile(
                operation: op,
                clientName: clientNameById[op.clientId],
                // Aprobar una operación vive en la pestaña 0 del hub.
                onTap: () => onNavigateToAprobaciones(0),
              ),
            for (final deposit in summary.attentionPendingDeposits)
              _AttentionDepositTile(
                deposit: deposit,
                clientName: clientNameById[deposit.clientId],
                // Conciliar un depósito vive en la pestaña 1 del hub —
                // ver docs/feature/tesoreria-cliente/README.md, "Dos entry
                // points para conciliar" (Tesorería del Cliente sigue
                // siendo el otro).
                onTap: () => onNavigateToAprobaciones(1),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttentionOperationTile extends StatelessWidget {
  const _AttentionOperationTile({required this.operation, required this.clientName, required this.onTap});

  final BalanceOperation operation;
  final String? clientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (clientName != null) clientName!,
      formatDateTime(operation.createdAt),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade50,
        child: Icon(Icons.fact_check_rounded, color: Colors.orange.shade800, size: 20),
      ),
      title: Text('${operation.type.label} pendiente de aprobación'),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(operation.amount, 'MXN'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AttentionDepositTile extends StatelessWidget {
  const _AttentionDepositTile({required this.deposit, required this.clientName, required this.onTap});

  final CollectorDeposit deposit;
  final String? clientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (clientName != null) clientName!,
      'Ref. ${deposit.reference}',
      formatDateTime(deposit.createdAt),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade50,
        child: Icon(Icons.move_to_inbox_rounded, color: Colors.orange.shade800, size: 20),
      ),
      title: const Text('Depósito pendiente de conciliar'),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(deposit.amount, 'MXN'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.summary});

  final DashboardSummary summary;

  static const _dispersionColor = KoonsColors.green;
  static final _deduccionColor = Colors.orange.shade700;
  static const _transferenciaColor = KoonsColors.blue;

  @override
  Widget build(BuildContext context) {
    final trend = summary.weeklyTrend;
    final maxTotal = trend.fold(0.0, (max, p) => p.total > max ? p.total : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Volumen de operaciones — últimas 12 semanas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Dato ilustrativo mientras no haya integración bancaria real. No representa transacciones reales.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            _Legend(items: [
              (_dispersionColor, 'Dispersión'),
              (_deduccionColor, 'Deducción'),
              (_transferenciaColor, 'Transferencia'),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: trend.isEmpty
                  ? Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey.shade600)))
                  : BarChart(
                      duration: Duration.zero,
                      BarChartData(
                        maxY: maxTotal <= 0 ? 1 : maxTotal * 1.2,
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= trend.length || index.isOdd) return const SizedBox.shrink();
                                final week = trend[index].weekStart;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${week.day.toString().padLeft(2, '0')}/${week.month.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < trend.length; i++) _buildGroup(i, trend[i]),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildGroup(int index, MovementTrendPoint point) {
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: point.total,
          width: 16,
          borderRadius: BorderRadius.zero,
          rodStackItems: [
            BarChartRodStackItem(0, point.dispersion, _dispersionColor),
            BarChartRodStackItem(point.dispersion, point.dispersion + point.deduccion, _deduccionColor),
            BarChartRodStackItem(
              point.dispersion + point.deduccion,
              point.total,
              _transferenciaColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: item.$1, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(item.$2, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
      ],
    );
  }
}
