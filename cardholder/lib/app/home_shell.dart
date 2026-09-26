import 'package:flutter/material.dart';

import '../core/models/account_ledger.dart';
import '../core/models/cardholder_session.dart';
import '../core/models/payment_card.dart';
import '../core/models/spei_payment.dart';
import '../core/utils/currency_format.dart';
import '../features/cards/card_repository.dart';
import '../features/cards/card_tile.dart';
import '../features/cards/movements_tab.dart';
import '../features/spei/beneficiarios_section.dart';
import '../features/spei/send_spei_dialog.dart';
import '../features/spei/spei_repository.dart';
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
          return _AccountOnlyShell(
            session: widget.session,
            cardRepository: widget.cardRepository,
            speiRepository: widget.speiRepository,
            onLogout: widget.onLogout,
          );
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

enum _AccountTab { inicio, movimientos, beneficiarios }

/// Para un Tarjetahabiente sin ninguna tarjeta todavía — misma
/// organización de 3 secciones que `CardholderShell` una vez tiene
/// tarjeta (ver docs/adr/0028-reorganizacion-ux-cardholder.md), sin la
/// tarjeta visual ni Transferencia C2C (esa sí requiere una tarjeta en
/// ambos extremos) — SPEI, en cambio, no necesita ninguna tarjeta, solo
/// la CLABE de la Cuenta. [cardRepository] se sigue pasando (nunca se
/// usan sus métodos de tarjeta aquí) porque `getClaim`/`fileClaim` viven
/// ahí y sí aplican sin tarjeta — ver la nota en `_NoOpCardRepository`
/// más abajo sobre por qué ya no se usa un stand-in.
class _AccountOnlyShell extends StatefulWidget {
  const _AccountOnlyShell({
    required this.session,
    required this.cardRepository,
    required this.speiRepository,
    required this.onLogout,
  });

  final CardholderSession session;
  final CardRepository cardRepository;
  final SpeiRepository speiRepository;
  final VoidCallback onLogout;

  @override
  State<_AccountOnlyShell> createState() => _AccountOnlyShellState();
}

class _AccountOnlyShellState extends State<_AccountOnlyShell> {
  _AccountTab _selected = _AccountTab.inicio;
  late final Future<AccountLedger> _ledgerFuture = widget.speiRepository.getAccountLedger(widget.session.cardholderId);

  String get _title {
    switch (_selected) {
      case _AccountTab.inicio:
        return 'Mi cuenta';
      case _AccountTab.movimientos:
        return 'Movimientos';
      case _AccountTab.beneficiarios:
        return 'Beneficiarios';
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_selected) {
      _AccountTab.inicio => _AccountOnlyHomeTab(session: widget.session, speiRepository: widget.speiRepository),
      _AccountTab.movimientos => FutureBuilder<AccountLedger>(
          future: _ledgerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final ledger = snapshot.data!;
            return MovementsTab(
              headerLabel: 'Movimientos de mi Cuenta',
              currency: ledger.currency,
              accountBalance: ledger.balance,
              loadMovements: () async => (await _ledgerFuture).movements,
              cardRepository: widget.cardRepository,
              speiRepository: widget.speiRepository,
              cardholderId: widget.session.cardholderId,
              cardholderName: widget.session.fullName,
            );
          },
        ),
      _AccountTab.beneficiarios => BeneficiariosSection(cardholderId: widget.session.cardholderId, repository: widget.speiRepository),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.white,
        foregroundColor: KoonsColors.navy,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Cerrar sesión', onPressed: widget.onLogout),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _AccountTab.values.indexOf(_selected),
        onDestinationSelected: (index) => setState(() => _selected = _AccountTab.values[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Beneficiarios',
          ),
        ],
      ),
    );
  }
}

/// Saldo + "Enviar dinero" para quien todavía no tiene ninguna tarjeta —
/// mismo botón y mismo diálogo (`SendSpeiDialog`) que `HomeTab`, sin
/// Transferencia C2C (necesita tarjeta en ambos extremos) ni tarjeta
/// visual que mostrar.
class _AccountOnlyHomeTab extends StatefulWidget {
  const _AccountOnlyHomeTab({required this.session, required this.speiRepository});

  final CardholderSession session;
  final SpeiRepository speiRepository;

  @override
  State<_AccountOnlyHomeTab> createState() => _AccountOnlyHomeTabState();
}

class _AccountOnlyHomeTabState extends State<_AccountOnlyHomeTab> {
  late Future<_Balance> _future = _load();
  bool _sending = false;

  Future<_Balance> _load() async {
    final ledger = await widget.speiRepository.getAccountLedger(widget.session.cardholderId);
    return _Balance(ledger.balance, ledger.currency);
  }

  Future<void> _openSendSpei(double balance, String currency) async {
    setState(() => _sending = true);
    final beneficiaries = await widget.speiRepository.listBeneficiaries(widget.session.cardholderId);
    if (!mounted) return;
    setState(() => _sending = false);

    final payment = await showDialog<SpeiPayment>(
      context: context,
      builder: (context) => SendSpeiDialog(
        cardholderId: widget.session.cardholderId,
        beneficiaries: beneficiaries,
        balance: balance,
        currency: currency,
        repository: widget.speiRepository,
      ),
    );
    if (payment == null) return;
    setState(() => _future = _load());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(speiResultMessage(payment))));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Balance>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final balance = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aún no tienes ninguna tarjeta asignada, pero tu Cuenta ya está activa.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KoonsColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'SALDO DISPONIBLE',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatCurrency(balance.amount, balance.currency),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: KoonsColors.navy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _sending ? null : () => _openSendSpei(balance.amount, balance.currency),
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.account_balance_outlined, size: 18),
                    label: const Text('Enviar dinero (SPEI)'),
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

class _Balance {
  const _Balance(this.amount, this.currency);
  final double amount;
  final String currency;
}
