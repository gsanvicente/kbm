import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/client.dart';
import '../../core/models/session.dart';
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

        if (cardholders.isEmpty) {
          return Center(
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
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: cardholders.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
          itemBuilder: (context, index) {
            final cardholder = cardholders[index];
            final clientName = clientNameById[cardholder.clientId] ?? '—';
            return CardholderTile(
              cardholder: cardholder,
              trailingLabel: clientName,
              onTap: () => widget.onSelect(cardholder, clientName),
            );
          },
        );
      },
    );
  }
}
