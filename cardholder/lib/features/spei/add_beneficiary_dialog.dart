import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/shared/too_many_failed_attempts_exception.dart';
import '../../core/models/shared/validation_exception.dart';
import '../../core/utils/clabe.dart';
import 'spei_repository.dart';

/// Alta de un Beneficiario de Pago — ver
/// docs/adr/0021-conector-spei.md, "Seguridad". El backend nunca dice
/// cuál de los candados falló (CLABE mal formada, banco desconocido, o tu
/// propia CLABE) — el mensaje aquí es igual de genérico a propósito,
/// mismo criterio que TransferDialog con un destino no encontrado.
class AddBeneficiaryDialog extends StatefulWidget {
  const AddBeneficiaryDialog({super.key, required this.cardholderId, required this.repository});

  final String cardholderId;
  final SpeiRepository repository;

  @override
  State<AddBeneficiaryDialog> createState() => _AddBeneficiaryDialogState();
}

class _AddBeneficiaryDialogState extends State<AddBeneficiaryDialog> {
  final _aliasController = TextEditingController();
  final _clabeController = TextEditingController();
  bool _busy = false;
  bool _locked = false;
  String? _error;

  @override
  void dispose() {
    _aliasController.dispose();
    _clabeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final alias = _aliasController.text.trim();
    final clabe = _clabeController.text.trim();
    if (alias.isEmpty) {
      setState(() => _error = 'Ponle un alias a este beneficiario (por ejemplo, "Mamá" o "Renta").');
      return;
    }
    if (clabe.length != 18) {
      setState(() => _error = 'La CLABE tiene 18 dígitos exactos.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final beneficiary = await widget.repository.registerBeneficiary(
        cardholderId: widget.cardholderId,
        alias: alias,
        clabe: clabe,
      );
      if (!mounted) return;
      Navigator.pop(context, beneficiary);
    } on ValidationException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Genérico a propósito — ver el doc de la clase.
        _error = 'No pudimos agregar este beneficiario. Revisa la CLABE e intenta de nuevo.';
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo beneficiario'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _aliasController,
              enabled: !_locked,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Alias', hintText: 'Mamá, Renta, Proveedor...'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clabeController,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
              decoration: const InputDecoration(labelText: 'CLABE', hintText: '18 dígitos'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _ClabePreview(clabe: _clabeController.text),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _busy || _locked ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Agregar'),
        ),
      ],
    );
  }
}

/// Vista previa del banco detectado a partir de la CLABE, calculada
/// enteramente en el cliente (mismo algoritmo/catálogo que el backend,
/// ver `core/utils/clabe.dart`) — deja confirmar que se capturó bien la
/// CLABE antes de guardar, sin esperar el viaje de ida y vuelta al
/// servidor. Nunca dice "cuenta verificada": solo confirma formato +
/// banco, no que la cuenta exista o sea de quien el usuario cree — ver
/// docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md.
class _ClabePreview extends StatelessWidget {
  const _ClabePreview({required this.clabe});
  final String clabe;

  @override
  Widget build(BuildContext context) {
    if (clabe.length < 18) {
      return Text(
        'El banco se detecta automáticamente a partir de la CLABE.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      );
    }
    if (!isValidClabeChecksum(clabe)) {
      return _PreviewRow(
        icon: Icons.error_outline_rounded,
        color: Colors.red.shade700,
        text: 'Esta CLABE no es válida — revisa que los 18 dígitos estén bien capturados.',
      );
    }
    final bank = clabeBankName(clabe);
    if (bank == null) {
      return _PreviewRow(
        icon: Icons.error_outline_rounded,
        color: Colors.orange.shade800,
        text: 'No reconocemos el banco de esta CLABE — revisa que esté bien capturada.',
      );
    }
    return _PreviewRow(
      icon: Icons.check_circle_outline_rounded,
      color: Colors.green.shade700,
      text: 'Banco detectado: $bank. Confirma que sea el banco correcto antes de guardar.',
      bold: true,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.color, required this.text, this.bold = false});
  final IconData icon;
  final Color color;
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
      ],
    );
  }
}
