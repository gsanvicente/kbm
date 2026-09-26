import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/spei_payment.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/payment_card_visual.dart';
import '../spei/send_spei_dialog.dart';
import '../spei/spei_repository.dart';
import '../transfer/transfer_dialog.dart';
import '../transfer/transfer_repository.dart';
import 'card_repository.dart';

/// Pestaña "Inicio" dentro de `CardholderShell` — tarjeta, saldo, y las
/// dos formas de mandar dinero desde la misma Cuenta (ver
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md: Transferencia C2C
/// y pago SPEI afectan el mismo saldo, así que viven aquí juntas, no
/// repartidas entre pestañas distintas — ver
/// docs/adr/0028-reorganizacion-ux-cardholder.md), más el
/// autocongelamiento ("Bloqueo temporal") de la propia tarjeta. Ver
/// docs/business/autoservicio-tarjetahabiente.md, "Congelar vs.
/// bloquear una tarjeta".
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.card,
    required this.cardholderId,
    required this.cardholderName,
    required this.cardRepository,
    required this.transferRepository,
    required this.speiRepository,
    required this.onTransferred,
    required this.onSpeiSent,
    required this.onCardUpdated,
  });

  final PaymentCard card;
  final String cardholderId;
  final String cardholderName;
  final CardRepository cardRepository;
  final TransferRepository transferRepository;
  final SpeiRepository speiRepository;

  /// El diálogo ya aplicó el débito en el repositorio — el llamador
  /// (`CardholderShell`) refleja el nuevo saldo localmente con el monto
  /// que el propio diálogo confirmó, sin otra ida y vuelta.
  final ValueChanged<double> onTransferred;

  /// A diferencia de una Transferencia (siempre inmediata), un pago SPEI
  /// puede quedar `pendingApproval` — el llamador decide si le resta algo
  /// al saldo mostrado según el estatus real del pago devuelto.
  final ValueChanged<SpeiPayment> onSpeiSent;

  /// Congelar/descongelar cambia el `status` de la tarjeta — a
  /// diferencia de una transferencia, el repositorio ya devuelve la
  /// tarjeta actualizada completa, así que el llamador la reemplaza tal
  /// cual en vez de recalcular un delta.
  final ValueChanged<PaymentCard> onCardUpdated;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loadingBeneficiaries = false;

  Future<void> _openTransfer(BuildContext context) async {
    final transferredAmount = await showDialog<double>(
      context: context,
      builder: (context) => TransferDialog(
        originCard: widget.card,
        cardholderId: widget.cardholderId,
        repository: widget.transferRepository,
      ),
    );
    if (transferredAmount == null) return;
    widget.onTransferred(transferredAmount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transferencia realizada.')));
  }

  Future<void> _openSendSpei(BuildContext context) async {
    setState(() => _loadingBeneficiaries = true);
    final beneficiaries = await widget.speiRepository.listBeneficiaries(widget.cardholderId);
    if (!mounted) return;
    setState(() => _loadingBeneficiaries = false);

    final payment = await showDialog<SpeiPayment>(
      context: context,
      builder: (context) => SendSpeiDialog(
        cardholderId: widget.cardholderId,
        beneficiaries: beneficiaries,
        balance: widget.card.balance,
        currency: widget.card.currency,
        repository: widget.speiRepository,
      ),
    );
    if (payment == null) return;
    widget.onSpeiSent(payment);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(speiResultMessage(payment))));
  }

  Future<void> _toggleFrozen(BuildContext context, bool freeze) async {
    try {
      final updated = await widget.cardRepository.setFrozen(widget.cardholderId, widget.card.id, freeze);
      widget.onCardUpdated(updated);
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
              Center(child: PaymentCardVisual(card: widget.card, cardholderName: widget.cardholderName, width: 440)),
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
                      formatCurrency(widget.card.balance, widget.card.currency),
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
  /// perspectiva del Tarjetahabiente). "Enviar dinero" agrupa
  /// Transferencia (a una tarjeta KBM) y SPEI (a una cuenta externa) como
  /// las dos formas de sacar dinero de la misma Cuenta — ver el doc de la
  /// clase.
  List<Widget> _actionsFor(BuildContext context) {
    switch (widget.card.status) {
      case CardStatus.active:
        return [
          Text('ENVIAR DINERO', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openTransfer(context),
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: const Text('A una tarjeta KBM'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loadingBeneficiaries ? null : () => _openSendSpei(context),
                  icon: _loadingBeneficiaries
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.account_balance_outlined, size: 18),
                  label: const Text('A una cuenta (SPEI)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
