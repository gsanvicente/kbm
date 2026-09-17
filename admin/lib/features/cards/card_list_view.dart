import 'package:flutter/material.dart';

import '../../core/models/payment_card.dart';
import 'card_repository.dart';
import 'payment_card_visual.dart';

/// Read-only — assigning happens from the global pool
/// (docs/feature/pool-y-asignacion-de-tarjetas/), never from here. Cards
/// shown here are, by definition, already assigned to this cardholder, so
/// none of them can be "available" — no Assign action is ever applicable
/// in this view.
class CardListView extends StatefulWidget {
  const CardListView({
    super.key,
    required this.repository,
    required this.cardholderId,
    required this.cardholderName,
    this.onSelect,
  });

  final CardRepository repository;
  final String cardholderId;
  final String cardholderName;
  final ValueChanged<PaymentCard>? onSelect;

  @override
  State<CardListView> createState() => _CardListViewState();
}

class _CardListViewState extends State<CardListView> {
  late Future<List<PaymentCard>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listByCardholder(widget.cardholderId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentCard>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error al cargar tarjetas: ${snapshot.error}'),
          );
        }

        final cards = snapshot.data!;
        if (cards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Este tarjetahabiente no tiene tarjetas asignadas',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              PaymentCardVisual(
                card: card,
                cardholderName: widget.cardholderName,
                onTap: widget.onSelect != null ? () => widget.onSelect!(card) : null,
              ),
          ],
        );
      },
    );
  }
}
