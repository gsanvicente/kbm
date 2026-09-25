import 'package:flutter/material.dart';

import '../core/models/cardholder_session.dart';
import '../core/models/payment_card.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/card_tile.dart';
import '../features/spei/spei_repository.dart';
import '../features/spei/spei_section.dart';
import '../features/transfer/transfer_repository.dart';
import 'cardholder_shell.dart';
import 'theme.dart';

/// Dueño de la navegación posterior al login: si el Tarjetahabiente tiene
/// una sola tarjeta, va directo a su detalle; si tiene más de una,
/// primero un selector — ver
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md, "Pantallas".
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    required this.cardRepository,
    required this.transferRepository,
    required this.speiRepository,
    required this.onLogout,
  });

  final CardholderSession session;
  final CardRepository cardRepository;
  final TransferRepository transferRepository;
  final SpeiRepository speiRepository;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<List<PaymentCard>> _future;
  PaymentCard? _selectedCard;

  @override
  void initState() {
    super.initState();
    _future = widget.cardRepository.listMine(widget.session.cardholderId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentCard>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final cards = snapshot.data!;
        if (cards.isEmpty) {
          // Sin tarjeta todavía no significa sin Cuenta — desde
          // docs/adr/0020-cuenta-individual-tarjetahabiente.md la Cuenta
          // Individual nace al alta del Tarjetahabiente, no al asignarle
          // una tarjeta, así que ya puede tener CLABE/recibir SPEI incluso
          // aquí. Ver también docs/adr/0021-conector-spei.md.
          return _AccountOnlyShell(session: widget.session, speiRepository: widget.speiRepository, onLogout: widget.onLogout);
        }
        if (cards.length == 1) {
          return CardholderShell(
            card: cards.first,
            cardholderId: widget.session.cardholderId,
            cardholderName: widget.session.fullName,
            cardholderEmail: widget.session.email,
            cardRepository: widget.cardRepository,
            transferRepository: widget.transferRepository,
            speiRepository: widget.speiRepository,
            onLogout: widget.onLogout,
          );
        }

        final selected = _selectedCard;
        if (selected != null) {
          return CardholderShell(
            card: selected,
            cardholderId: widget.session.cardholderId,
            cardholderName: widget.session.fullName,
            cardholderEmail: widget.session.email,
            cardRepository: widget.cardRepository,
            transferRepository: widget.transferRepository,
            speiRepository: widget.speiRepository,
            onLogout: widget.onLogout,
            onBack: () => setState(() => _selectedCard = null),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mis tarjetas'),
            actions: [
              IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Cerrar sesión', onPressed: widget.onLogout),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (final card in cards)
                    CardTile(
                      card: card,
                      cardholderName: widget.session.fullName,
                      onTap: () => setState(() => _selectedCard = card),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Para un Tarjetahabiente sin ninguna tarjeta todavía — solo su Cuenta
/// Individual (CLABE/Beneficiarios/pagos SPEI, ver `SpeiSection`). Sin
/// pestañas (a diferencia de `CardholderShell`): "Inicio"/"Movimientos"
/// no tienen sentido sin una tarjeta, así que esto es la única pantalla,
/// no una más dentro de un selector.
class _AccountOnlyShell extends StatelessWidget {
  const _AccountOnlyShell({required this.session, required this.speiRepository, required this.onLogout});

  final CardholderSession session;
  final SpeiRepository speiRepository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        backgroundColor: Colors.white,
        foregroundColor: KoonsColors.navy,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Cerrar sesión', onPressed: onLogout),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aún no tienes ninguna tarjeta asignada, pero tu Cuenta ya está activa.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
          Expanded(child: SpeiSection(cardholderId: session.cardholderId, cardholderName: session.fullName, repository: speiRepository)),
        ],
      ),
    );
  }
}
