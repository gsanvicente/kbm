import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/client.dart';
import '../../core/models/session.dart';
import 'client_repository.dart';

class ClientListView extends StatefulWidget {
  const ClientListView({
    super.key,
    required this.repository,
    required this.session,
    this.onSelect,
  });

  final ClientRepository repository;
  final Session session;
  final ValueChanged<Client>? onSelect;

  @override
  State<ClientListView> createState() => _ClientListViewState();
}

class _ClientListViewState extends State<ClientListView> {
  late Future<List<Client>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listAccessibleClients(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Client>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar clientes: ${snapshot.error}'));
        }

        final clients = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: clients.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
          itemBuilder: (context, index) {
            final client = clients[index];
            final isGroup = client.parentClientId == null &&
                clients.any((c) => c.parentClientId == client.id);
            return ListTile(
              onTap: widget.onSelect != null ? () => widget.onSelect!(client) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isGroup ? KoonsColors.blue : KoonsColors.green).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGroup ? Icons.corporate_fare_rounded : Icons.apartment_rounded,
                  color: isGroup ? KoonsColors.blue : KoonsColors.green,
                  size: 20,
                ),
              ),
              title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                client.parentClientId != null ? 'Empresa hija' : (isGroup ? 'Empresa matriz' : 'Empresa'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            );
          },
        );
      },
    );
  }
}
