import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../cardholders/cardholder_detail_view.dart';
import '../cardholders/cardholder_list_view.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_detail_view.dart';
import '../cards/card_repository.dart';
import '../ledger/ledger_repository.dart';
import 'client_list_view.dart';
import 'client_repository.dart';

/// Owns the drill-down state for the "Clientes" nav section: Clientes list
/// → Tarjetahabientes of a Cliente → detalle de un Tarjetahabiente →
/// detalle de una de sus Tarjetas. See docs/feature/tarjetahabientes-por-cliente/,
/// docs/feature/detalle-y-gestion-tarjetahabiente/ and
/// docs/feature/tarjetas-de-tarjetahabiente/.
class ClientesSection extends StatefulWidget {
  const ClientesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;

  @override
  State<ClientesSection> createState() => _ClientesSectionState();
}

class _ClientesSectionState extends State<ClientesSection> {
  Client? _selectedClient;
  Cardholder? _selectedCardholder;
  PaymentCard? _selectedCard;

  @override
  Widget build(BuildContext context) {
    final client = _selectedClient;
    final cardholder = _selectedCardholder;
    final card = _selectedCard;

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem(
        'Clientes',
        onTap: client != null
            ? () => setState(() {
                  _selectedClient = null;
                  _selectedCardholder = null;
                  _selectedCard = null;
                })
            : null,
      ),
      if (client != null)
        BreadcrumbItem(
          client.name,
          onTap: cardholder != null
              ? () => setState(() {
                    _selectedCardholder = null;
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
            child: _buildBody(client, cardholder, card),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(Client? client, Cardholder? cardholder, PaymentCard? card) {
    if (card != null && cardholder != null && client != null) {
      return CardDetailView(
        card: card,
        cardholderName: cardholder.fullName,
        cardRepository: widget.cardRepository,
        cardholderRepository: widget.cardholderRepository,
        ledgerRepository: widget.ledgerRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCard = updated),
      );
    }
    if (cardholder != null && client != null) {
      return CardholderDetailView(
        cardholder: cardholder,
        clientName: client.name,
        repository: widget.cardholderRepository,
        cardRepository: widget.cardRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCardholder = updated),
        onSelectCard: (selected) => setState(() => _selectedCard = selected),
      );
    }
    if (client != null) {
      return CardholderListView(
        repository: widget.cardholderRepository,
        clientId: client.id,
        onSelect: (selected) => setState(() => _selectedCardholder = selected),
      );
    }
    return ClientListView(
      repository: widget.clientRepository,
      session: widget.session,
      onSelect: (selected) => setState(() => _selectedClient = selected),
    );
  }
}
