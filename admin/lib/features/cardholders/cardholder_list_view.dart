import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/cardholder.dart';
import 'cardholder_repository.dart';

class CardholderListView extends StatefulWidget {
  const CardholderListView({
    super.key,
    required this.repository,
    required this.clientId,
    this.onSelect,
  });

  final CardholderRepository repository;
  final String clientId;
  final ValueChanged<Cardholder>? onSelect;

  @override
  State<CardholderListView> createState() => _CardholderListViewState();
}

class _CardholderListViewState extends State<CardholderListView> {
  late Future<List<Cardholder>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listByClient(widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cardholder>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar tarjetahabientes: ${snapshot.error}'));
        }

        final cardholders = snapshot.data!;
        if (cardholders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Este cliente no tiene tarjetahabientes propios',
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
            return CardholderTile(
              cardholder: cardholder,
              onTap: widget.onSelect != null ? () => widget.onSelect!(cardholder) : null,
            );
          },
        );
      },
    );
  }
}

class CardholderTile extends StatelessWidget {
  const CardholderTile({super.key, required this.cardholder, this.onTap, this.trailingLabel});

  final Cardholder cardholder;
  final VoidCallback? onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: KoonsColors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.person_rounded, color: KoonsColors.blue, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              cardholder.fullName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!cardholder.isActive) ...[
            const SizedBox(width: 8),
            _Chip(label: 'Inactivo', color: Colors.red.shade700, background: Colors.red.shade50),
          ],
          if (cardholder.isPoliticallyExposed) ...[
            const SizedBox(width: 8),
            _Chip(label: 'PEP', color: Colors.orange.shade800, background: Colors.orange.shade50),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (cardholder.curp != null) 'CURP ${cardholder.curp}',
          if (cardholder.email != null) cardholder.email,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
      ),
      trailing: trailingLabel != null
          ? Text(trailingLabel!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5))
          : Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
