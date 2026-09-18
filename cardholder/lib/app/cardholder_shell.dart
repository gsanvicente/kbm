import 'package:flutter/material.dart';

import '../core/models/payment_card.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/home_tab.dart';
import '../features/cards/movements_tab.dart';
import '../features/transfer/transfer_repository.dart';

/// Marco persistente de navegación una vez dentro de una tarjeta —
/// "Inicio" y "Movimientos" — con nav lateral en pantallas anchas
/// (web/desktop) y barra inferior en angostas (móvil), mismo criterio
/// adaptativo que un portal bancario real. Ver "Pantallas" en
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
class CardholderShell extends StatefulWidget {
  const CardholderShell({
    super.key,
    required this.card,
    required this.cardholderId,
    required this.cardholderName,
    required this.cardRepository,
    required this.transferRepository,
    required this.onLogout,
    this.onBack,
  });

  final PaymentCard card;
  final String cardholderId;
  final String cardholderName;
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
  int _tabIndex = 0;

  void _onTransferred(double amount) {
    setState(() => _card = _card.copyWith(balance: _card.balance - amount));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final firstName = widget.cardholderName.trim().split(' ').first;

    final body = _tabIndex == 0
        ? HomeTab(
            card: _card,
            cardholderId: widget.cardholderId,
            cardholderName: widget.cardholderName,
            transferRepository: widget.transferRepository,
            onTransferred: _onTransferred,
          )
        : MovementsTab(card: _card, cardRepository: widget.cardRepository);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack)
            : null,
        title: Text('Hola, $firstName'),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Cerrar sesión', onPressed: widget.onLogout),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (index) => setState(() => _tabIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Inicio'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Movimientos'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) => setState(() => _tabIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Movimientos',
                ),
              ],
            ),
    );
  }
}
