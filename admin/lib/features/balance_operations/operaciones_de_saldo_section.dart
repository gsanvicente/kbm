import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';

/// Fila reutilizada entre la pestaña "Historial completo" del hub de
/// Aprobaciones (ver `aprobaciones_section.dart`), la pestaña
/// "Operaciones" de una tarjeta, y la cola de pendientes del mismo hub —
/// misma información, distinta acción al final (o ninguna).
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
