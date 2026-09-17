import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../cardholders/cardholder_detail_view.dart';
import '../cardholders/cardholder_list_view.dart';
import '../cardholders/cardholder_repository.dart';
import 'client_list_view.dart';
import 'client_repository.dart';

/// Owns the drill-down state for the "Clientes" nav section: Clientes list
/// → Tarjetahabientes of a Cliente → detalle de un Tarjetahabiente. See
/// docs/feature/tarjetahabientes-por-cliente/ and
/// docs/feature/detalle-y-gestion-tarjetahabiente/.
class ClientesSection extends StatefulWidget {
  const ClientesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;

  @override
  State<ClientesSection> createState() => _ClientesSectionState();
}

class _ClientesSectionState extends State<ClientesSection> {
  Client? _selectedClient;
  Cardholder? _selectedCardholder;

  @override
  Widget build(BuildContext context) {
    final client = _selectedClient;
    final cardholder = _selectedCardholder;

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem('Clientes', onTap: client != null ? () => setState(() {
        _selectedClient = null;
        _selectedCardholder = null;
      }) : null),
      if (client != null)
        BreadcrumbItem(client.name, onTap: cardholder != null ? () => setState(() => _selectedCardholder = null) : null),
      if (cardholder != null) BreadcrumbItem(cardholder.fullName),
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
            child: _buildBody(client, cardholder),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(Client? client, Cardholder? cardholder) {
    if (cardholder != null && client != null) {
      return CardholderDetailView(
        cardholder: cardholder,
        clientName: client.name,
        repository: widget.cardholderRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCardholder = updated),
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
