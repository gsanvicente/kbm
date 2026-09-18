import 'package:flutter/material.dart';

import '../../core/models/card_status.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/ledger_account.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/cardholder_search_field.dart';
import '../../shared_widgets/multi_select_filter_button.dart';
import '../cardholders/cardholder_repository.dart';
import '../clients/client_repository.dart';
import '../ledger/ledger_repository.dart';
import 'card_repository.dart';
import 'card_tile.dart';

/// Lists every card (disponible + asignada) across every Cliente
/// accessible to [session] — see
/// docs/feature/pool-y-asignacion-de-tarjetas/README.md. The "Asignar"
/// action lives in CardDetailView, reached by tapping a row here, not
/// inline in this list — same split as list/detail everywhere else in
/// the app.
class GlobalCardListView extends StatefulWidget {
  const GlobalCardListView({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.cardRepository,
    required this.ledgerRepository,
    required this.onSelect,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final CardRepository cardRepository;
  final LedgerRepository ledgerRepository;

  /// cardholderName is null when the card is still in the available pool.
  final void Function(PaymentCard card, String clientName, String? cardholderName) onSelect;

  @override
  State<GlobalCardListView> createState() => _GlobalCardListViewState();
}

class _GlobalCardListViewState extends State<GlobalCardListView> {
  late Future<(List<Client>, List<Cardholder>, List<PaymentCard>, Map<String, LedgerAccount>)> _future;

  Set<CardStatus> _statusFilter = {};
  Set<String> _clientFilter = {};
  Cardholder? _cardholderFilter;
  int _searchFieldGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Client>, List<Cardholder>, List<PaymentCard>, Map<String, LedgerAccount>)> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final clientIds = clients.map((c) => c.id).toList();
    final cardholders = await widget.cardholderRepository.listByClients(clientIds);
    final cards = await widget.cardRepository.listByClients(clientIds);
    final ledgerAccounts = await widget.ledgerRepository.getByCards(cards.map((c) => c.id).toList());
    return (clients, cardholders, cards, ledgerAccounts);
  }

  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty || _clientFilter.isNotEmpty || _cardholderFilter != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = {};
      _clientFilter = {};
      _cardholderFilter = null;
      _searchFieldGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Client>, List<Cardholder>, List<PaymentCard>, Map<String, LedgerAccount>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar tarjetas: ${snapshot.error}'));
        }

        final (clients, cardholders, cards, ledgerAccounts) = snapshot.data!;
        final clientNameById = {for (final c in clients) c.id: c.name};
        final cardholderNameById = {for (final c in cardholders) c.id: c.fullName};

        final filtered = cards.where((c) {
          if (_statusFilter.isNotEmpty && !_statusFilter.contains(c.status)) return false;
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(c.clientId)) return false;
          if (_cardholderFilter != null && c.cardholderId != _cardholderFilter!.id) return false;
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MultiSelectFilterButton<CardStatus>(
                    label: 'Estado',
                    options: CardStatus.values,
                    optionLabel: (s) => s.label,
                    selected: _statusFilter,
                    onChanged: (next) => setState(() => _statusFilter = next),
                  ),
                  if (clients.length > 1)
                    MultiSelectFilterButton<String>(
                      label: 'Empresa',
                      options: clients.map((c) => c.id).toList(),
                      optionLabel: (id) => clientNameById[id] ?? '—',
                      selected: _clientFilter,
                      onChanged: (next) => setState(() => _clientFilter = next),
                    ),
                  CardholderSearchField(
                    key: ValueKey(_searchFieldGeneration),
                    candidates: cardholders,
                    onChanged: (selected) => setState(() => _cardholderFilter = selected),
                  ),
                  if (_hasActiveFilters)
                    TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        cards.isEmpty
                            ? 'No hay tarjetas dentro de tu alcance'
                            : 'Ninguna tarjeta coincide con los filtros',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final card = filtered[index];
                        final clientName = clientNameById[card.clientId] ?? '—';
                        final cardholderName =
                            card.cardholderId != null ? cardholderNameById[card.cardholderId] : null;
                        return CardTile(
                          card: card,
                          trailingLabel: clientName,
                          ledgerAccount: ledgerAccounts[card.id],
                          cardholderName: cardholderName,
                          onTap: () => widget.onSelect(card, clientName, cardholderName),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
