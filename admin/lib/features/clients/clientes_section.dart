import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../balance_operations/balance_operation_repository.dart';
import '../cardholders/cardholder_detail_view.dart';
import '../cardholders/cardholder_repository.dart';
import '../cards/card_detail_view.dart';
import '../cards/card_repository.dart';
import '../ledger/ledger_repository.dart';
import '../spei/spei_repository.dart';
import '../staff_users/staff_user_repository.dart';
import '../treasury/treasury_repository.dart';
import 'client_detail_view.dart';
import 'client_list_view.dart';
import 'client_repository.dart';
import 'edit_client_view.dart';
import 'new_client_wizard.dart';

/// Owns the drill-down state for the "Clientes" nav section: Clientes list
/// → Tarjetahabientes of a Cliente → detalle de un Tarjetahabiente →
/// detalle de una de sus Tarjetas. See docs/feature/tarjetahabientes-por-cliente/,
/// docs/feature/detalle-y-gestion-tarjetahabiente/ y
/// docs/feature/panel-principal-admin/README.md ("Breadcrumb con
/// ancestría completa").
class ClientesSection extends StatefulWidget {
  const ClientesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.balanceOperationRepository,
    required this.treasuryRepository,
    required this.staffUserRepository,
    required this.speiRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;
  final BalanceOperationRepository balanceOperationRepository;
  final TreasuryRepository treasuryRepository;
  final StaffUserRepository staffUserRepository;
  final SpeiRepository speiRepository;

  @override
  State<ClientesSection> createState() => _ClientesSectionState();
}

class _ClientesSectionState extends State<ClientesSection> {
  Client? _selectedClient;
  Cardholder? _selectedCardholder;
  PaymentCard? _selectedCard;
  bool _creatingClient = false;
  bool _editingClient = false;

  /// Empresa padre precargada en el Paso 0 del wizard cuando se llega
  /// desde el botón "Agregar filial" de ClientDetailView — null cuando se
  /// llega desde el botón general del listado de Clientes.
  String? _creatingClientParentId;

  /// Todos los Clientes accesibles — usado solo para resolver la cadena
  /// de ancestros del breadcrumb (ver `_ancestorChainFor`). Se llena de
  /// forma asíncrona; hasta que cargue, el breadcrumb degrada con
  /// gracia mostrando solo el Cliente seleccionado, sin sus ancestros.
  List<Client> _allClients = const [];

  @override
  void initState() {
    super.initState();
    widget.clientRepository.listAccessibleClients(widget.session).then((clients) {
      if (mounted) setState(() => _allClients = clients);
    });
  }

  List<Client> _ancestorChainFor(Client client) {
    final byId = {for (final c in _allClients) c.id: c};
    final chain = <Client>[client];
    var current = client;
    while (current.parentClientId != null && byId.containsKey(current.parentClientId)) {
      current = byId[current.parentClientId]!;
      chain.insert(0, current);
    }
    return chain;
  }

  @override
  Widget build(BuildContext context) {
    final client = _selectedClient;
    final cardholder = _selectedCardholder;
    final card = _selectedCard;
    final ancestorChain = client != null ? _ancestorChainFor(client) : const <Client>[];

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem(
        'Clientes',
        onTap: (client != null || _creatingClient)
            ? () => setState(() {
                  _selectedClient = null;
                  _selectedCardholder = null;
                  _selectedCard = null;
                  _creatingClient = false;
                  _creatingClientParentId = null;
                  _editingClient = false;
                })
            : null,
      ),
      if (_creatingClient) const BreadcrumbItem('Nuevo Cliente'),
      for (var i = 0; i < ancestorChain.length; i++)
        BreadcrumbItem(
          ancestorChain[i].name,
          onTap: (i < ancestorChain.length - 1 || cardholder != null || _editingClient)
              ? () => setState(() {
                    _selectedClient = ancestorChain[i];
                    _selectedCardholder = null;
                    _selectedCard = null;
                    _editingClient = false;
                  })
              : null,
        ),
      if (_editingClient) const BreadcrumbItem('Editar'),
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
    if (_creatingClient) {
      // Sin SingleChildScrollView aquí a propósito: Stepper ya trae su
      // propio ListView interno — envolverlo en otro scroll le da altura
      // no acotada y rompe su layout (Expanded dentro de una columna sin
      // límite de altura).
      return Padding(
        padding: const EdgeInsets.all(24),
        child: NewClientWizard(
          session: widget.session,
          clientRepository: widget.clientRepository,
          treasuryRepository: widget.treasuryRepository,
          initialParentClientId: _creatingClientParentId,
          onCreated: (created) => setState(() {
            _creatingClient = false;
            _creatingClientParentId = null;
            _selectedClient = created;
          }),
        ),
      );
    }
    if (_editingClient && client != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EditClientView(
          client: client,
          clientRepository: widget.clientRepository,
          onSaved: (updated) => setState(() {
            _editingClient = false;
            _selectedClient = updated;
          }),
          onCancel: () => setState(() => _editingClient = false),
        ),
      );
    }
    if (card != null && cardholder != null && client != null) {
      return CardDetailView(
        // Sin esto, cambiar de tarjeta sin desmontar este widget (misma
        // posición en el árbol) deja el estado de la anterior — ver la
        // nota equivalente en ClientDetailView más abajo.
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
    if (cardholder != null && client != null) {
      return CardholderDetailView(
        key: ValueKey('cardholder-${cardholder.id}'),
        cardholder: cardholder,
        clientName: client.name,
        repository: widget.cardholderRepository,
        cardRepository: widget.cardRepository,
        speiRepository: widget.speiRepository,
        session: widget.session,
        onChanged: (updated) => setState(() => _selectedCardholder = updated),
        onSelectCard: (selected) => setState(() => _selectedCard = selected),
      );
    }
    if (client != null) {
      return ClientDetailView(
        // El breadcrumb (Clientes > ... > este Cliente) cambia
        // widget.client sin desmontar ClientDetailView (misma posición en
        // el árbol) — sin un key que dependa del id, Flutter reutiliza el
        // State existente (didUpdateWidget, no initState) y _TreasuryTab
        // se queda con el Future del Cliente anterior. Bug real
        // encontrado navegando Clientes > Grupo Koons Holding > Koons
        // Subsidiaria A > Filiar 1 y de regreso: el título cambiaba, el
        // saldo de la Concentradora no.
        key: ValueKey('client-${client.id}'),
        client: client,
        session: widget.session,
        cardholderRepository: widget.cardholderRepository,
        treasuryRepository: widget.treasuryRepository,
        clientRepository: widget.clientRepository,
        cardRepository: widget.cardRepository,
        balanceOperationRepository: widget.balanceOperationRepository,
        staffUserRepository: widget.staffUserRepository,
        onSelectCardholder: (selected) => setState(() => _selectedCardholder = selected),
        onEdit: () => setState(() => _editingClient = true),
        onClientUpdated: (updated) => setState(() => _selectedClient = updated),
        onAddSubsidiary: widget.session.role.canManageClients
            ? () => setState(() {
                  _creatingClientParentId = client.id;
                  _creatingClient = true;
                })
            : null,
      );
    }
    return ClientListView(
      repository: widget.clientRepository,
      session: widget.session,
      onSelect: (selected) => setState(() => _selectedClient = selected),
      onCreateNew: widget.session.role.canManageClients ? () => setState(() => _creatingClient = true) : null,
    );
  }
}
