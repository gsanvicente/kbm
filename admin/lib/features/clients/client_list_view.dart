import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/client.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import 'client_repository.dart';

/// Listado de Clientes como **árbol** (no plano) — la jerarquía puede
/// tener profundidad arbitraria (holding → subsidiaria →
/// sub-subsidiaria). Ver docs/feature/panel-principal-admin/README.md,
/// "Vista jerárquica" y "Búsqueda".
class ClientListView extends StatefulWidget {
  const ClientListView({
    super.key,
    required this.repository,
    required this.session,
    this.onSelect,
    this.onCreateNew,
  });

  final ClientRepository repository;
  final Session session;
  final ValueChanged<Client>? onSelect;

  /// Null oculta el botón por completo — `ClientesSection` solo lo pasa
  /// cuando `session.role.canManageClients`. Ver
  /// docs/feature/alta-y-gestion-de-clientes/README.md.
  final VoidCallback? onCreateNew;

  @override
  State<ClientListView> createState() => _ClientListViewState();
}

class _ClientListViewState extends State<ClientListView> {
  late Future<List<Client>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  /// Ids expandidos manualmente por el usuario — el estado inicial
  /// depende del rol (ver `_initializeExpansion`), independiente de
  /// cualquier búsqueda activa (esa se calcula aparte, ver
  /// `_ancestorsToForceExpand`).
  final Set<String> _expandedIds = {};
  bool _expansionInitialized = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.listAccessibleClients(widget.session);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Admin Cliente: expandido por defecto (su propio subárbol suele ser
  /// acotado). Super Admin: colapsado por defecto (puede haber varias
  /// empresas raíz independientes, cada una con su propio árbol).
  void _initializeExpansion(List<Client> clients) {
    if (_expansionInitialized) return;
    _expansionInitialized = true;
    if (widget.session.role != Role.superAdmin) {
      _expandedIds.addAll(clients.map((c) => c.id));
    }
  }

  bool _matches(Client client) {
    if (_query.isEmpty) return false;
    return client.name.toLowerCase().contains(_query) ||
        (client.razonSocial?.toLowerCase().contains(_query) ?? false) ||
        (client.rfc?.toLowerCase().contains(_query) ?? false);
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
        _initializeExpansion(clients);
        final clientsById = {for (final c in clients) c.id: c};
        final rootIds = clients
            .where((c) => c.parentClientId == null || !clientsById.containsKey(c.parentClientId))
            .map((c) => c.id)
            .toSet();
        final childrenByParentId = <String, List<Client>>{};
        for (final client in clients) {
          if (client.parentClientId != null && clientsById.containsKey(client.parentClientId)) {
            childrenByParentId.putIfAbsent(client.parentClientId!, () => []).add(client);
          }
        }

        // Búsqueda: qué ids coinciden, y qué ids hay que forzar a mostrar
        // (los ancestros de una coincidencia, aunque ellos mismos no
        // coincidan) — mismo criterio que un explorador de archivos con
        // buscador.
        final hasQuery = _query.isNotEmpty;
        final matchIds = <String>{};
        final visibleIds = <String>{};
        final forceExpandIds = <String>{};
        if (hasQuery) {
          for (final client in clients) {
            if (_matches(client)) {
              matchIds.add(client.id);
              var current = client;
              visibleIds.add(current.id);
              while (current.parentClientId != null && clientsById.containsKey(current.parentClientId)) {
                forceExpandIds.add(current.parentClientId!);
                current = clientsById[current.parentClientId]!;
                visibleIds.add(current.id);
              }
            }
          }
        }

        final effectiveExpanded = {..._expandedIds, ...forceExpandIds};

        final rows = <(Client, int)>[];
        void walk(Client client, int depth) {
          if (hasQuery && !visibleIds.contains(client.id)) return;
          rows.add((client, depth));
          final children = childrenByParentId[client.id] ?? const <Client>[];
          if (children.isNotEmpty && effectiveExpanded.contains(client.id)) {
            for (final child in children) {
              walk(child, depth + 1);
            }
          }
        }

        for (final rootId in rootIds) {
          walk(clientsById[rootId]!, 0);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, razón social o RFC',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        suffixIcon: hasQuery
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (widget.onCreateNew != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: widget.onCreateNew,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nuevo Cliente'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'Ningún Cliente coincide con tu búsqueda.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final (client, depth) = rows[index];
                        final isGroup = (childrenByParentId[client.id] ?? const []).isNotEmpty;
                        final isExpanded = effectiveExpanded.contains(client.id);
                        return _ClientTreeRow(
                          client: client,
                          depth: depth,
                          isGroup: isGroup,
                          isExpanded: isExpanded,
                          onToggleExpand: isGroup
                              ? () => setState(() {
                                    if (_expandedIds.contains(client.id)) {
                                      _expandedIds.remove(client.id);
                                    } else {
                                      _expandedIds.add(client.id);
                                    }
                                  })
                              : null,
                          onTap: widget.onSelect != null ? () => widget.onSelect!(client) : null,
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

class _ClientTreeRow extends StatelessWidget {
  const _ClientTreeRow({
    required this.client,
    required this.depth,
    required this.isGroup,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onTap,
  });

  final Client client;
  final int depth;
  final bool isGroup;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 16, top: 6, bottom: 6),
      leading: SizedBox(
        width: 64,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              child: onToggleExpand != null
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded),
                      onPressed: onToggleExpand,
                    )
                  : null,
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isGroup ? KoonsColors.blue : KoonsColors.green).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isGroup ? Icons.corporate_fare_rounded : Icons.apartment_rounded,
                color: isGroup ? KoonsColors.blue : KoonsColors.green,
                size: 18,
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (!client.isActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Inactiva',
                style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        client.parentClientId != null ? 'Empresa hija' : (isGroup ? 'Empresa matriz' : 'Empresa'),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
    );
  }
}
