import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/payment_card_visual.dart';

class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card, required this.cardholderName, required this.onTap});

  final PaymentCard card;
  final String cardholderName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = card.status == CardStatus.active;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sin repetir el número enmascarado aparte — la propia
              // tarjeta ya lo muestra, igual que
              // admin/lib/features/cards/card_list_view.dart.
              PaymentCardVisual(card: card, cardholderName: cardholderName, width: 140),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isActive ? formatCurrency(card.balance, card.currency) : card.status.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isActive ? KoonsColors.navy : Colors.red.shade700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
