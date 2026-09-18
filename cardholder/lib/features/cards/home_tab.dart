import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/payment_card_visual.dart';
import '../transfer/transfer_dialog.dart';
import '../transfer/transfer_repository.dart';

/// Pestaña "Inicio" dentro de `CardholderShell` — tarjeta, saldo y el
/// botón Transferir. Ver "Pantallas" en
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.card,
    required this.cardholderId,
    required this.cardholderName,
    required this.transferRepository,
    required this.onTransferred,
  });

  final PaymentCard card;
  final String cardholderId;
  final String cardholderName;
  final TransferRepository transferRepository;

  /// El diálogo ya aplicó el débito en el repositorio — el llamador
  /// (`CardholderShell`) refleja el nuevo saldo localmente con el monto
  /// que el propio diálogo confirmó, sin otra ida y vuelta.
  final ValueChanged<double> onTransferred;

  Future<void> _openTransfer(BuildContext context) async {
    final transferredAmount = await showDialog<double>(
      context: context,
      builder: (context) => TransferDialog(
        originCard: card,
        cardholderId: cardholderId,
        repository: transferRepository,
      ),
    );
    if (transferredAmount == null) return;
    onTransferred(transferredAmount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transferencia realizada.')));
  }

  @override
  Widget build(BuildContext context) {
    final blocked = card.status == CardStatus.blocked;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta grande — reemplaza cualquier texto de Red/Vigencia/
              // Estado como filas planas, esos datos ya están dibujados en
              // la propia tarjeta. Mismo criterio que
              // admin/lib/features/cards/card_detail_view.dart.
              Center(child: PaymentCardVisual(card: card, cardholderName: cardholderName, width: 320)),
              const SizedBox(height: 24),
              // Saldo — el dato central de la app, mostrado aparte de la
              // tarjeta (una tarjeta física real nunca imprime el saldo).
              // Ver docs/business/saldo-y-ledger.md. El estado ya lo
              // muestra la insignia de la propia tarjeta, no se repite aquí.
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
                      formatCurrency(card.balance, card.currency),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: KoonsColors.navy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!blocked)
                FilledButton.icon(
                  onPressed: () => _openTransfer(context),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: const Text('Transferir'),
                )
              else
                Text(
                  'Tu tarjeta está bloqueada. Contacta a tu administrador para más información.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
