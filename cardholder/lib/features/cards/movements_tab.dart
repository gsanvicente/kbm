import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/ledger_movement.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import 'card_repository.dart';

/// Pestaña "Movimientos" dentro de `CardholderShell` — lista de la
/// cuenta, sin filtro de fechas ni resumen de periodo todavía (esa parte
/// de "Estado de cuenta" sigue pendiente, ver
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md).
class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key, required this.card, required this.cardRepository});

  final PaymentCard card;
  final CardRepository cardRepository;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  late final Future<List<LedgerMovement>> _future = widget.cardRepository.listMovements(widget.card.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LedgerMovement>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final movements = snapshot.data!;
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
                if (movements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aún no hay movimientos en esta tarjeta.', style: TextStyle(color: Colors.grey.shade600)),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: movements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _MovementTile(movement: movements[index], currency: widget.card.currency),
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

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.currency});

  final LedgerMovement movement;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isCredit = movement.type == LedgerEntryType.credit;
    final color = isCredit ? KoonsColors.green : KoonsColors.navy;
    final sign = isCredit ? '+' : '−';
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
