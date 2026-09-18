import 'package:flutter/material.dart';

import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../cardholders/cardholder_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import 'card_detail_view.dart';
import 'card_repository.dart';
import 'global_card_list_view.dart';

/// Owns the drill-down state for the top-level "Tarjetas" nav section:
/// global pool (disponibles + asignadas, across every Cliente accessible
/// to the user) → detalle de una Tarjeta. See
/// docs/feature/pool-y-asignacion-de-tarjetas/.
class TarjetasSection extends StatefulWidget {
  const TarjetasSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;

  @override
  State<TarjetasSection> createState() => _TarjetasSectionState();
}

class _TarjetasSectionState extends State<TarjetasSection> {
  PaymentCard? _selected;
  String? _selectedCardholderName;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem(
        'Tarjetas',
        onTap: selected != null ? () => setState(() {
          _selected = null;
          _selectedCardholderName = null;
        }) : null,
      ),
      if (selected != null) BreadcrumbItem(selected.maskedPan),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (breadcrumbItems.length > 1) ...[
          BreadcrumbBar(items: breadcrumbItems),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: selected != null
                ? CardDetailView(
                    card: selected,
                    cardholderName: _selectedCardholderName,
                    cardRepository: widget.cardRepository,
                    cardholderRepository: widget.cardholderRepository,
                    ledgerRepository: widget.ledgerRepository,
                    balanceOperationRepository: widget.balanceOperationRepository,
                    session: widget.session,
                    onChanged: (updated) => setState(() => _selected = updated),
                  )
                : GlobalCardListView(
                    session: widget.session,
                    clientRepository: widget.clientRepository,
                    cardholderRepository: widget.cardholderRepository,
                    cardRepository: widget.cardRepository,
                    ledgerRepository: widget.ledgerRepository,
                    onSelect: (card, clientName, cardholderName) => setState(() {
                      _selected = card;
                      _selectedCardholderName = cardholderName;
                    }),
                  ),
          ),
        ),
      ],
    );
  }
}
