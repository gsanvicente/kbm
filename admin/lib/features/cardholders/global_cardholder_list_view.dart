import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/cardholder_search_field.dart';
import '../../shared_widgets/multi_select_filter_button.dart';
import '../clients/client_repository.dart';
import 'cardholder_list_view.dart';
import 'cardholder_repository.dart';

/// Lists every Tarjetahabiente across all Clientes accessible to
/// [session] — complements the per-Cliente drill-down, see
/// docs/feature/listado-global-tarjetahabientes/README.md. Resolves
/// accessible clients first (via ClientRepository, the same hierarchy
/// rule as the Clientes screen), then asks CardholderRepository for
/// their cardholders — keeps hierarchy logic in one place.
class GlobalCardholderListView extends StatefulWidget {
  const GlobalCardholderListView({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.onSelect,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final void Function(Cardholder cardholder, String clientName) onSelect;

  @override
  State<GlobalCardholderListView> createState() => _GlobalCardholderListViewState();
}

class _GlobalCardholderListViewState extends State<GlobalCardholderListView> {
  late Future<(List<Client>, List<Cardholder>)> _future;

  Set<String> _clientFilter = {};
  Cardholder? _nameFilter;
  int _searchFieldGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Client>, List<Cardholder>)> _load() async {
    final clients = await widget.clientRepository.listAccessibleClients(widget.session);
    final cardholders = await widget.cardholderRepository.listByClients(
      clients.map((c) => c.id).toList(),
    );
    return (clients, cardholders);
  }

  bool get _hasActiveFilters => _clientFilter.isNotEmpty || _nameFilter != null;

  void _clearFilters() {
    setState(() {
      _clientFilter = {};
      _nameFilter = null;
      _searchFieldGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Client>, List<Cardholder>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar tarjetahabientes: ${snapshot.error}'));
        }

        final (clients, cardholders) = snapshot.data!;
        final clientNameById = {for (final c in clients) c.id: c.name};

        final filtered = cardholders.where((c) {
          if (_clientFilter.isNotEmpty && !_clientFilter.contains(c.clientId)) return false;
          if (_nameFilter != null && c.id != _nameFilter!.id) return false;
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
                    onChanged: (selected) => setState(() => _nameFilter = selected),
                  ),
                  if (_hasActiveFilters)
                    TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: cardholders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No hay tarjetahabientes dentro de tu alcance',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Ningún tarjetahabiente coincide con los filtros',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                          itemBuilder: (context, index) {
                            final cardholder = filtered[index];
                            final clientName = clientNameById[cardholder.clientId] ?? '—';
                            return CardholderTile(
                              cardholder: cardholder,
                              trailingLabel: clientName,
                              onTap: () => widget.onSelect(cardholder, clientName),
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
