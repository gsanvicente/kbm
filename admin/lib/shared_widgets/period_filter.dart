import 'package:flutter/material.dart';

/// Filtro de periodo por presets — usado por el Estado de cuenta para
/// directivos (`client_detail_view.dart`) y por los reportes de staff
/// (`reportes_section.dart`), ver
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md.
enum PeriodFilter { all, thisMonth, last30Days, last90Days }

extension PeriodFilterLabel on PeriodFilter {
  String get label => switch (this) {
        PeriodFilter.all => 'Todo el historial',
        PeriodFilter.thisMonth => 'Este mes',
        PeriodFilter.last30Days => 'Últimos 30 días',
        PeriodFilter.last90Days => 'Últimos 90 días',
      };

  /// null significa "sin límite inferior" (todo el historial).
  DateTime? startDate(DateTime now) => switch (this) {
        PeriodFilter.all => null,
        PeriodFilter.thisMonth => DateTime(now.year, now.month, 1),
        PeriodFilter.last30Days => now.subtract(const Duration(days: 30)),
        PeriodFilter.last90Days => now.subtract(const Duration(days: 90)),
      };

  bool includes(DateTime createdAt, DateTime now) {
    final start = startDate(now);
    return start == null || !createdAt.isBefore(start);
  }
}

class PeriodDropdown extends StatelessWidget {
  const PeriodDropdown({super.key, required this.value, required this.onChanged});

  final PeriodFilter value;
  final ValueChanged<PeriodFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<PeriodFilter>(
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (final p in PeriodFilter.values)
          DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 13))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
