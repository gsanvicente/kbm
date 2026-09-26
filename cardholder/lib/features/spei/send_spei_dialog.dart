import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/beneficiary.dart';
import '../../core/models/shared/validation_exception.dart';
import '../../core/models/spei_payment.dart';
import '../../core/models/spei_payment_status.dart';
import '../../core/utils/currency_format.dart';
import '../../shared_widgets/currency_field.dart';
import 'add_beneficiary_dialog.dart';
import 'spei_repository.dart';

/// Enviar un pago SPEI a un Beneficiario ya registrado, o a uno nuevo
/// dado de alta sin salir de este mismo flujo (ver
/// docs/adr/0028-reorganizacion-ux-cardholder.md: los Beneficiarios ya no
/// se muestran de entrada en ningún lado — solo aquí, al momento de
/// enviar, o en "Beneficiarios" para administrarlos con calma) — dos
/// pasos (monto → confirmar), igual criterio que TransferDialog, pero sin
/// resolver destino a mano (siempre por CLABE ya validada de un
/// Beneficiario). Ver docs/adr/0021-conector-spei.md, puntos 5-7.
class SendSpeiDialog extends StatefulWidget {
  const SendSpeiDialog({
    super.key,
    required this.cardholderId,
    required this.beneficiaries,
    required this.balance,
    required this.currency,
    required this.repository,
  });

  final String cardholderId;
  final List<Beneficiary> beneficiaries;

  /// Saldo disponible de la Cuenta Individual — para bloquear un envío
  /// que ya sabemos que no puede cubrirse, antes de siquiera mandarlo al
  /// servidor. Ver docs/adr/0027-validacion-de-saldo-y-estatus-de-pago-spei.md:
  /// antes de esto, un pago por encima del saldo (y por encima del
  /// umbral de aprobación) se aceptaba igual y quedaba "pendiente de
  /// aprobación" sin que nadie le avisara al Tarjetahabiente que ya
  /// sabíamos, desde el momento en que lo pidió, que no había fondos.
  final double balance;
  final String currency;
  final SpeiRepository repository;

  @override
  State<SendSpeiDialog> createState() => _SendSpeiDialogState();
}

enum _Step { form, confirm }

class _SendSpeiDialogState extends State<SendSpeiDialog> {
  _Step _step = _Step.form;
  late List<Beneficiary> _beneficiaries = List.of(widget.beneficiaries);
  Beneficiary? _beneficiary;
  double _amount = 0;
  bool _busy = false;
  String? _error;

  Future<void> _addBeneficiary() async {
    final added = await showDialog<Beneficiary>(
      context: context,
      builder: (context) => AddBeneficiaryDialog(cardholderId: widget.cardholderId, repository: widget.repository),
    );
    if (added == null) return;
    setState(() {
      _beneficiaries = [..._beneficiaries, added];
      _beneficiary = added;
      _error = null;
    });
  }

  void _goToConfirm() {
    if (_beneficiary == null) {
      setState(() => _error = 'Elige a quién le vas a enviar.');
      return;
    }
    if (_amount <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }
    if (_amount > widget.balance) {
      setState(() => _error = 'Saldo insuficiente — tu saldo disponible es ${formatCurrency(widget.balance, widget.currency)}.');
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
          if (_beneficiaries.isEmpty)
            Text(
              'Aún no tienes beneficiarios registrados.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
            )
          else
            DropdownButtonFormField<Beneficiary>(
              initialValue: _beneficiary,
              decoration: const InputDecoration(labelText: 'Beneficiario'),
              items: [
                for (final b in _beneficiaries)
                  DropdownMenuItem(value: b, child: Text('${b.alias} · ${b.maskedClabe}')),
              ],
              onChanged: (value) => setState(() => _beneficiary = value),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addBeneficiary,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Agregar nuevo beneficiario'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(height: 8),
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
