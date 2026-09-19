import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/payment_card_visual.dart';
import '../transfer/transfer_dialog.dart';
import '../transfer/transfer_repository.dart';
import 'card_repository.dart';

/// Pestaña "Inicio" dentro de `CardholderShell` — tarjeta, saldo,
/// Transferir y el autocongelamiento ("Bloqueo temporal") de la propia
/// tarjeta. Ver "Pantallas" en
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md y
/// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs. bloquear
/// una tarjeta".
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.card,
    required this.cardholderId,
    required this.cardholderName,
    required this.cardRepository,
    required this.transferRepository,
    required this.onTransferred,
    required this.onCardUpdated,
  });

  final PaymentCard card;
  final String cardholderId;
  final String cardholderName;
  final CardRepository cardRepository;
  final TransferRepository transferRepository;

  /// El diálogo ya aplicó el débito en el repositorio — el llamador
  /// (`CardholderShell`) refleja el nuevo saldo localmente con el monto
  /// que el propio diálogo confirmó, sin otra ida y vuelta.
  final ValueChanged<double> onTransferred;

  /// Congelar/descongelar cambia el `status` de la tarjeta — a
  /// diferencia de una transferencia, el repositorio ya devuelve la
  /// tarjeta actualizada completa, así que el llamador la reemplaza tal
  /// cual en vez de recalcular un delta.
  final ValueChanged<PaymentCard> onCardUpdated;

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

  Future<void> _toggleFrozen(BuildContext context, bool freeze) async {
    try {
      final updated = await cardRepository.setFrozen(cardholderId, card.id, freeze);
      onCardUpdated(updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(freeze ? 'Bloqueaste temporalmente tu tarjeta.' : 'Quitaste el bloqueo temporal.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado de la tarjeta. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta grande — mismo tamaño (440) que
              // admin/lib/features/cards/card_detail_view.dart, reemplaza
              // cualquier texto de Red/Vigencia/Estado como filas planas,
              // esos datos ya están dibujados en la propia tarjeta.
              Center(child: PaymentCardVisual(card: card, cardholderName: cardholderName, width: 440)),
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
              ..._actionsFor(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Tres estados posibles, cada uno con sus propias acciones — ver
  /// "Congelar vs. bloquear una tarjeta": un bloqueo de staff
  /// (`blocked`) nunca deja ninguna acción de autoservicio disponible,
  /// ni siquiera "descongelar" (nunca estuvo `frozen` desde la
  /// perspectiva del Tarjetahabiente).
  List<Widget> _actionsFor(BuildContext context) {
    switch (card.status) {
      case CardStatus.active:
        return [
          FilledButton.icon(
            onPressed: () => _openTransfer(context),
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            label: const Text('Transferir'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _toggleFrozen(context, true),
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: const Text('Bloqueo temporal'),
          ),
        ];
      case CardStatus.frozen:
        return [
          Text(
            'Le pusiste un bloqueo temporal a esta tarjeta. Quítalo para volver a usarla.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _toggleFrozen(context, false),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Quitar bloqueo temporal'),
          ),
        ];
      case CardStatus.blocked:
        return [
          Text(
            'Tu tarjeta está bloqueada. Contacta a tu administrador para más información.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ];
    }
  }
}
