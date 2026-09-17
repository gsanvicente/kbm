import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/card_status.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.trailingLabel,
    this.ledgerAccount,
  });

  final PaymentCard card;
  final VoidCallback? onTap;
  final String? trailingLabel;

  /// null means "no ledger account fetched/exists yet" — see
  /// docs/business/saldo-y-ledger.md. Only meaningful to show as an
  /// actual absence for [PaymentCard.isAvailable] cards; for assigned
  /// cards a null here just means the balance hasn't loaded.
  final LedgerAccount? ledgerAccount;

  Color get _statusColor {
    switch (card.status) {
      case CardStatus.active:
        return KoonsColors.green;
      case CardStatus.unassigned:
        return Colors.grey.shade600;
      case CardStatus.blocked:
      case CardStatus.cancelled:
        return Colors.red.shade700;
      case CardStatus.frozen:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: KoonsColors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.credit_card_rounded,
            color: KoonsColors.blue, size: 20),
      ),
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            card.maskedPan,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              card.status.label,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${card.network.label} · Vence ${card.expiryLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            card.isAvailable
                ? 'Sin cuenta de saldo'
                : (ledgerAccount != null
                    ? 'Saldo: ${formatCurrency(ledgerAccount!.balance, ledgerAccount!.currency)}'
                    : ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: card.isAvailable ? Colors.grey.shade400 : KoonsColors.navy,
              fontSize: 12.5,
              fontWeight: card.isAvailable ? FontWeight.normal : FontWeight.w600,
              fontStyle: card.isAvailable ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (card.assignedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Asignada: ${formatDate(card.assignedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            ),
          ],
        ],
      ),
      trailing: trailingLabel != null
          ? Text(trailingLabel!,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5))
          : Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}
