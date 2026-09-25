import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/beneficiary.dart';
import '../../core/models/shared/validation_exception.dart';
import '../../core/models/spei_payment.dart';
import '../../core/models/spei_payment_status.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/currency_field.dart';
import 'spei_repository.dart';

/// Enviar un pago SPEI a un Beneficiario ya registrado — dos pasos (monto
/// → confirmar), igual criterio que TransferDialog, pero sin resolver
/// destino (el Beneficiario ya se eligió de una lista propia, nunca se
/// escribe una CLABE ajena a mano aquí). Ver
/// docs/adr/0021-conector-spei.md, puntos 5-7.
class SendSpeiDialog extends StatefulWidget {
  const SendSpeiDialog({
    super.key,
    required this.cardholderId,
    required this.beneficiaries,
    required this.repository,
  });

  final String cardholderId;
  final List<Beneficiary> beneficiaries;
  final SpeiRepository repository;

  @override
  State<SendSpeiDialog> createState() => _SendSpeiDialogState();
}

enum _Step { form, confirm }

class _SendSpeiDialogState extends State<SendSpeiDialog> {
  _Step _step = _Step.form;
  Beneficiary? _beneficiary;
  double _amount = 0;
  bool _busy = false;
  String? _error;

  void _goToConfirm() {
    if (_beneficiary == null) {
      setState(() => _error = 'Elige a quién le vas a enviar.');
      return;
    }
    if (_amount <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.confirm;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payment = await widget.repository.createPayment(
        cardholderId: widget.cardholderId,
        beneficiaryId: _beneficiary!.id,
        amount: _amount,
      );
      if (!mounted) return;
      Navigator.pop(context, payment);
    } on ValidationException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Este Beneficiario sigue en su periodo de enfriamiento — solo puede recibir montos pequeños por ahora.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar dinero'),
      content: SizedBox(width: 380, child: _step == _Step.form ? _buildForm() : _buildConfirm()),
      actions: _step == _Step.form
          ? [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(onPressed: _goToConfirm, child: const Text('Continuar')),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _step = _Step.form),
                child: const Text('Atrás'),
              ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar'),
              ),
            ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Beneficiary>(
            initialValue: _beneficiary,
            decoration: const InputDecoration(labelText: 'Beneficiario'),
            items: [
              for (final b in widget.beneficiaries)
                DropdownMenuItem(value: b, child: Text('${b.alias} · ${b.maskedClabe}')),
            ],
            onChanged: (value) => setState(() => _beneficiary = value),
          ),
          const SizedBox(height: 16),
          CurrencyField(onChanged: (value) => _amount = value),
          if (_beneficiary?.isCooling ?? false) ...[
            const SizedBox(height: 8),
            Text(
              'Beneficiario agregado recientemente: los montos grandes quedan limitados por 24 horas.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final beneficiary = _beneficiary!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vas a enviar', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          formatCurrency(_amount, 'MXN'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: KoonsColors.navy),
        ),
        const SizedBox(height: 16),
        Text('A', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(beneficiary.alias, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text('${beneficiary.bankName} · ${beneficiary.maskedClabe}', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Text(
          'Por debajo del umbral configurado por tu empresa se envía de inmediato; por encima, queda pendiente de aprobación.',
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

/// Mensaje de resultado tras un envío exitoso — distingue "ya se fue" de
/// "queda pendiente" porque son experiencias muy distintas para quien
/// acaba de mandar dinero. Ver docs/business/approval-policy.md.
String speiResultMessage(SpeiPayment payment) {
  switch (payment.status) {
    case SpeiPaymentStatus.executed:
      return 'Pago enviado.';
    case SpeiPaymentStatus.pendingApproval:
      return 'Pago registrado — queda pendiente de aprobación por superar el monto libre de tu empresa.';
    case SpeiPaymentStatus.failed:
      return 'El pago falló: ${payment.resolutionNotes ?? 'intenta de nuevo'}.';
    case SpeiPaymentStatus.rejected:
      return 'El pago fue rechazado.';
  }
}
