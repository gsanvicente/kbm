import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/too_many_failed_attempts_exception.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/currency_field.dart';
import '../../shared_widgets/masked_card_number_field.dart';
import 'transfer_repository.dart';

/// Transferencia C2C — captura monto + número completo de tarjeta
/// destino, resuelve a quién pertenece y pide confirmación explícita
/// antes de enviar. Ver
/// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Flujo
/// principal". Nunca pasa por aprobación, nunca toca una Cuenta
/// Concentradora — es tarjeta a tarjeta, directo.
class TransferDialog extends StatefulWidget {
  const TransferDialog({
    super.key,
    required this.originCard,
    required this.cardholderId,
    required this.repository,
  });

  final PaymentCard originCard;
  final String cardholderId;
  final TransferRepository repository;

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

enum _Step { form, confirm }

class _TransferDialogState extends State<TransferDialog> {
  _Step _step = _Step.form;
  double _amount = 0;
  String _pan = '';
  ResolvedTransferDestination? _destination;
  bool _busy = false;
  bool _locked = false;
  String? _error;

  Future<void> _findDestination() async {
    if (_amount <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }
    if (_pan.trim().isEmpty) {
      setState(() => _error = 'Ingresa el número completo de la tarjeta destino.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resolved = await widget.repository.resolveDestination(
        cardholderId: widget.cardholderId,
        originCardId: widget.originCard.id,
        pan: _pan.trim(),
      );
      if (!mounted) return;
      if (resolved == null) {
        setState(() {
          _busy = false;
          // Mensaje genérico a propósito — nunca se distingue formato
          // inválido de "no pertenece a nuestro universo" ni "es tu
          // propia tarjeta". Ver "Seguridad" en el README de la feature.
          _error = 'No encontramos ninguna tarjeta válida con ese número dentro de tu empresa.';
        });
        return;
      }
      setState(() {
        _destination = resolved;
        _step = _Step.confirm;
        _busy = false;
      });
    } on TooManyFailedAttemptsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _locked = true;
        _error = e.message;
      });
    }
  }

  Future<void> _confirmTransfer() async {
    final destination = _destination;
    if (destination == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.transfer(
        originCardId: widget.originCard.id,
        destinationCardId: destination.card.id,
        amount: _amount,
      );
      if (!mounted) return;
      Navigator.pop(context, _amount);
    } on InsufficientFundsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferir'),
      content: SizedBox(
        width: 380,
        child: _step == _Step.form ? _buildForm() : _buildConfirm(),
      ),
      actions: _step == _Step.form
          ? [
              TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                onPressed: _busy || _locked ? null : _findDestination,
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Buscar destino'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _step = _Step.form),
                child: const Text('Atrás'),
              ),
              FilledButton(
                onPressed: _busy ? null : _confirmTransfer,
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmar'),
              ),
            ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Desde ${widget.originCard.maskedPan} · ${formatCurrency(widget.originCard.balance, widget.originCard.currency)} disponibles',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          CurrencyField(onChanged: (value) => _amount = value, autofocus: true),
          const SizedBox(height: 16),
          MaskedCardNumberField(enabled: !_locked, onChanged: (value) => _pan = value),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final destination = _destination!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vas a transferir', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          formatCurrency(_amount, widget.originCard.currency),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: KoonsColors.navy),
        ),
        const SizedBox(height: 16),
        Text('A', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(destination.cardholderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(destination.card.maskedPan, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Text(
          'Se ejecuta de inmediato, sin necesidad de aprobación.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
        ],
      ],
    );
  }
}
