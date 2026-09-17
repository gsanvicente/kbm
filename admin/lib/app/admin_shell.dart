import 'package:flutter/material.dart';

import '../core/models/session.dart';
import '../features/cardholders/cardholder_repository.dart';
import '../features/cardholders/tarjetahabientes_section.dart';
import '../features/clients/client_repository.dart';
import '../features/clients/clientes_section.dart';
import 'auth_controller.dart';
import 'theme.dart';

enum _Section { clientes, tarjetahabientes, tarjetas, operaciones, aprobaciones }

extension on _Section {
  String get label {
    switch (this) {
      case _Section.clientes:
        return 'Clientes';
      case _Section.tarjetahabientes:
        return 'Tarjetahabientes';
      case _Section.tarjetas:
        return 'Tarjetas';
      case _Section.operaciones:
        return 'Operaciones de saldo';
      case _Section.aprobaciones:
        return 'Aprobaciones';
    }
  }

  IconData get icon {
    switch (this) {
      case _Section.clientes:
        return Icons.corporate_fare_rounded;
      case _Section.tarjetahabientes:
        return Icons.people_alt_rounded;
      case _Section.tarjetas:
        return Icons.credit_card_rounded;
      case _Section.operaciones:
        return Icons.swap_horiz_rounded;
      case _Section.aprobaciones:
        return Icons.fact_check_rounded;
    }
  }

}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.cardholderRepository,
    required this.authController,
  });

  final Session session;
  final ClientRepository clientRepository;
  final CardholderRepository cardholderRepository;
  final AuthController authController;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  _Section _selected = _Section.clientes;

  String get _initials {
    final email = widget.session.email;
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: _selected,
            onSelect: (section) => setState(() => _selected = section),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _selected.label,
                  session: widget.session,
                  initials: _initials,
                  onLogout: widget.authController.logout,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selected) {
      case _Section.clientes:
        return ClientesSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
        );
      case _Section.tarjetahabientes:
        return TarjetahabientesSection(
          session: widget.session,
          clientRepository: widget.clientRepository,
          cardholderRepository: widget.cardholderRepository,
        );
      case _Section.tarjetas:
      case _Section.operaciones:
      case _Section.aprobaciones:
        return _EmptySectionPlaceholder(label: _selected.label);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final _Section selected;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: KoonsColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/images/kbm_logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'KBM Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          for (final section in _Section.values)
            _SidebarItem(
              section: section,
              isSelected: section == selected,
              onTap: () => onSelect(section),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Koons Balance Management',
              style: TextStyle(color: KoonsColors.sidebarText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.section, required this.isSelected, required this.onTap});

  final _Section section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? KoonsColors.sidebarTextActive : KoonsColors.sidebarText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? KoonsColors.sidebarItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(section.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.session,
    required this.initials,
    required this.onLogout,
  });

  final String title;
  final Session session;
  final String initials;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KoonsColors.border)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: KoonsColors.navy),
            ),
          ),
          const Spacer(),
          CircleAvatar(
            radius: 15,
            backgroundColor: KoonsColors.blue,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  session.role.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionPlaceholder extends StatelessWidget {
  const _EmptySectionPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '$label — próximamente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
