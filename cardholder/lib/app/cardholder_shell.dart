import 'package:flutter/material.dart';

import '../core/models/payment_card.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/home_tab.dart';
import '../features/cards/movements_tab.dart';
import '../features/transfer/transfer_repository.dart';
import 'theme.dart';

enum _Tab { inicio, movimientos }

extension on _Tab {
  String get label {
    switch (this) {
      case _Tab.inicio:
        return 'Inicio';
      case _Tab.movimientos:
        return 'Movimientos';
    }
  }

  IconData get icon {
    switch (this) {
      case _Tab.inicio:
        return Icons.home_outlined;
      case _Tab.movimientos:
        return Icons.receipt_long_outlined;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case _Tab.inicio:
        return Icons.home_rounded;
      case _Tab.movimientos:
        return Icons.receipt_long_rounded;
    }
  }
}

/// Marco persistente de navegación una vez dentro de una tarjeta —
/// "Inicio" y "Movimientos" — con el mismo lenguaje visual que
/// `admin/lib/app/admin_shell.dart` (sidebar navy + topbar blanco):
/// sidebar de escritorio en pantallas anchas, barra inferior en angostas
/// (móvil), mismo criterio adaptativo que un portal bancario real. Ver
/// "Pantallas" en docs/feature/portal-autoservicio-tarjetahabiente/README.md.
class CardholderShell extends StatefulWidget {
  const CardholderShell({
    super.key,
    required this.card,
    required this.cardholderId,
    required this.cardholderName,
    required this.cardholderEmail,
    required this.cardRepository,
    required this.transferRepository,
    required this.onLogout,
    this.onBack,
  });

  final PaymentCard card;
  final String cardholderId;
  final String cardholderName;
  final String cardholderEmail;
  final CardRepository cardRepository;
  final TransferRepository transferRepository;
  final VoidCallback onLogout;

  /// Null cuando esta es la única tarjeta del Tarjetahabiente (no hubo
  /// selector del que regresar) — ver "Pantallas" en el README de la
  /// feature del portal.
  final VoidCallback? onBack;

  @override
  State<CardholderShell> createState() => _CardholderShellState();
}

class _CardholderShellState extends State<CardholderShell> {
  late PaymentCard _card = widget.card;
  _Tab _selected = _Tab.inicio;

  void _onTransferred(double amount) {
    setState(() => _card = _card.copyWith(balance: _card.balance - amount));
  }

  void _onCardUpdated(PaymentCard updated) {
    setState(() => _card = updated);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final body = _selected == _Tab.inicio
        ? HomeTab(
            card: _card,
            cardholderId: widget.cardholderId,
            cardholderName: widget.cardholderName,
            cardRepository: widget.cardRepository,
            transferRepository: widget.transferRepository,
            onCardUpdated: _onCardUpdated,
            onTransferred: _onTransferred,
          )
        : MovementsTab(card: _card, cardRepository: widget.cardRepository);

    final content = Column(
      children: [
        _TopBar(
          title: _selected.label,
          cardholderName: widget.cardholderName,
          cardholderEmail: widget.cardholderEmail,
          onBack: widget.onBack,
          onLogout: widget.onLogout,
        ),
        Expanded(child: body),
      ],
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                _Sidebar(selected: _selected, onSelect: (tab) => setState(() => _selected = tab)),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _Tab.values.indexOf(_selected),
              onDestinationSelected: (index) => setState(() => _selected = _Tab.values[index]),
              destinations: [
                for (final tab in _Tab.values)
                  NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
              ],
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/images/kbm_logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('KBM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          for (final tab in _Tab.values)
            _SidebarItem(tab: tab, isSelected: tab == selected, onTap: () => onSelect(tab)),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Koons Balance Management', style: TextStyle(color: KoonsColors.sidebarText, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.tab, required this.isSelected, required this.onTap});

  final _Tab tab;
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
                Icon(isSelected ? tab.selectedIcon : tab.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label,
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

/// Mismo formato que `admin/lib/app/admin_shell.dart`'s `_TopBar`: título
/// de la sección a la izquierda, identidad (avatar + nombre) y cerrar
/// sesión a la derecha — adaptado con `onBack` opcional para el flujo del
/// selector de tarjetas (ver `CardholderShell.onBack`), que `admin/` no
/// necesita.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.cardholderName,
    required this.cardholderEmail,
    required this.onLogout,
    this.onBack,
  });

  final String title;
  final String cardholderName;
  final String cardholderEmail;
  final VoidCallback onLogout;
  final VoidCallback? onBack;

  String get _initial {
    final trimmed = cardholderName.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

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
          if (onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver',
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: KoonsColors.navy),
            ),
          ),
          CircleAvatar(
            radius: 15,
            backgroundColor: KoonsColors.blue,
            child: Text(_initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cardholderName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  cardholderEmail,
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
