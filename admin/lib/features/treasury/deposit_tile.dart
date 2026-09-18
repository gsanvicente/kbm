import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/collector_deposit_status.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';

/// Fila reutilizada entre la pestaña "Tesorería" de un Cliente
/// (`ClientDetailView`) y la pestaña "Depósitos por conciliar" del hub de
/// Aprobaciones — misma acción de conciliar disponible desde ambos
/// lugares (ver docs/feature/tesoreria-cliente/README.md, "Dos entry
/// points para conciliar"). Vive en `treasury/` (no en `clients/` ni en
/// `balance_operations/`) justamente para que ambas features la importen
/// sin crear una dependencia circular entre ellas.
class DepositTile extends StatelessWidget {
  const DepositTile({
    super.key,
    required this.deposit,
    required this.currency,
    required this.clientName,
    required this.canReconcile,
    required this.onReconcile,
  });

  final CollectorDeposit deposit;
  final String currency;

  /// Vacío cuando ya se muestra dentro de la Tesorería de un Cliente
  /// específico (el Cliente ya está implícito en la pantalla, no hace
  /// falta repetirlo) — mismo criterio que `BalanceOperationTile.clientName`.
  final String clientName;
  final bool canReconcile;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context) {
    final pending = deposit.status == CollectorDepositStatus.pending;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: KoonsColors.blue.withValues(alpha: 0.1),
        child: const Icon(Icons.account_balance_rounded, color: KoonsColors.blue, size: 20),
      ),
      title: Text('Referencia: ${deposit.reference}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (clientName.isNotEmpty) clientName,
          'Registrado por ${deposit.registeredByEmail}',
          formatDateTime(deposit.createdAt),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(formatCurrency(deposit.amount, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          // Either the action or the status, never both stacked — con
          // ambos hay riesgo real de desbordar la altura por defecto del
          // ListTile, y es redundante: ver "Conciliar" ya dice que está
          // pendiente, nada más muestra ese botón.
          if (pending && canReconcile)
            SizedBox(
              height: 28,
              child: OutlinedButton(
                onPressed: onReconcile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Conciliar', style: TextStyle(fontSize: 12)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (pending ? Colors.orange.shade800 : Colors.green.shade700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                deposit.status.label,
                style: TextStyle(
                  color: pending ? Colors.orange.shade800 : Colors.green.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
