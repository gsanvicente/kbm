import 'package:flutter/material.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/session.dart';
import '../../shared_widgets/breadcrumb_bar.dart';
import '../clients/client_repository.dart';
import 'cardholder_detail_view.dart';
import 'cardholder_repository.dart';
import 'global_cardholder_list_view.dart';

/// Owns the drill-down state for the top-level "Tarjetahabientes" nav
/// section: global list (across every Cliente accessible to the user) →
/// detalle de un Tarjetahabiente. See
/// docs/feature/listado-global-tarjetahabientes/.
class TarjetahabientesSection extends StatefulWidget {
  const TarjetahabientesSection({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;

  @override
  State<TarjetahabientesSection> createState() => _TarjetahabientesSectionState();
}

class _TarjetahabientesSectionState extends State<TarjetahabientesSection> {
  Cardholder? _selected;
  String? _selectedClientName;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    final breadcrumbItems = <BreadcrumbItem>[
      BreadcrumbItem(
        'Tarjetahabientes',
        onTap: selected != null ? () => setState(() {
          _selected = null;
          _selectedClientName = null;
        }) : null,
      ),
      if (selected != null) BreadcrumbItem(selected.fullName),
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
                ? CardholderDetailView(
                    cardholder: selected,
                    clientName: _selectedClientName ?? '—',
                    repository: widget.cardholderRepository,
                    session: widget.session,
                    onChanged: (updated) => setState(() => _selected = updated),
                  )
                : GlobalCardholderListView(
                    session: widget.session,
                    clientRepository: widget.clientRepository,
                    cardholderRepository: widget.cardholderRepository,
                    onSelect: (cardholder, clientName) => setState(() {
                      _selected = cardholder;
                      _selectedClientName = clientName;
                    }),
                  ),
          ),
        ),
      ],
    );
  }
}
