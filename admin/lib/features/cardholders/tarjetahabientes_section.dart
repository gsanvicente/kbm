import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../cards/card_detail_view.dart';
import '../cards/card_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import 'cardholder_detail_view.dart';
import 'cardholder_repository.dart';
import 'global_cardholder_list_view.dart';

/// Owns the drill-down state for the top-level "Tarjetahabientes" nav
/// section: global list (across every Cliente accessible to the user) →
/// detalle de un Tarjetahabiente → detalle de una de sus Tarjetas. See
/// docs/feature/listado-global-tarjetahabientes/ and
/// docs/feature/tarjetas-de-tarjetahabiente/.
class TarjetahabientesSection extends StatefulWidget {
  const TarjetahabientesSection({
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
  State<TarjetahabientesSection> createState() => _TarjetahabientesSectionState();
}

class _TarjetahabientesSectionState extends State<TarjetahabientesSection> {
  Cardholder? _selectedCardholder;
  String? _selectedClientName;
  PaymentCard? _selectedCard;

  @override
  Widget build(BuildContext context) {
    final cardholder = _selectedCardholder;
    final card = _selectedCard;

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem(
        'Tarjetahabientes',
        onTap: cardholder != null
            ? () => setState(() {
                  _selectedCardholder = null;
                  _selectedClientName = null;
                  _selectedCard = null;
                })
            : null,
      ),
      if (cardholder != null)
        BreadcrumbItem(cardholder.fullName, onTap: card != null ? () => setState(() => _selectedCard = null) : null),
      if (card != null) BreadcrumbItem(card.maskedPan),
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
            child: _buildBody(cardholder, card),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(Cardholder? cardholder, PaymentCard? card) {
    if (card != null && cardholder != null) {
      return CardDetailView(
        key: ValueKey('card-${card.id}'),
        card: card,
        cardholderName: cardholder.fullName,
        cardRepository: widget.cardRepository,
        cardholderRepository: widget.cardholderRepository,
        ledgerRepository: widget.ledgerRepository,
        balanceOperationRepository: widget.balanceOperationRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCard = updated),
      );
    }
    if (cardholder != null) {
      return CardholderDetailView(
        key: ValueKey('cardholder-${cardholder.id}'),
        cardholder: cardholder,
        clientName: _selectedClientName ?? '—',
        repository: widget.cardholderRepository,
        cardRepository: widget.cardRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCardholder = updated),
        onSelectCard: (selected) => setState(() => _selectedCard = selected),
      );
    }
    return GlobalCardholderListView(
      session: widget.session,
      clientRepository: widget.clientRepository,
      cardholderRepository: widget.cardholderRepository,
      onSelect: (selected, clientName) => setState(() {
        _selectedCardholder = selected;
        _selectedClientName = clientName;
      }),
    );
  }
}
