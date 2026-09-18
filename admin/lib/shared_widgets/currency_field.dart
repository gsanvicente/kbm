import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/currency_format.dart';

/// A money input masked as cents-based currency — every keystroke is a
/// digit that shifts into the cents position (type "12345" to get
/// "123.45"), exactly like a POS terminal or bank app amount field.
/// Never free text: letters can't be typed at all, and an empty field
/// reads as $0.00. See
/// docs/feature/operacion-saldo-con-aprobacion/README.md, "Captura del
/// monto".
class CurrencyField extends StatefulWidget {
  const CurrencyField({super.key, required this.onChanged, this.label = 'Monto', this.autofocus = false});

  final ValueChanged<double> onChanged;
  final String label;
  final bool autofocus;

  @override
  State<CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<CurrencyField> {
  final _controller = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final cents = digitsOnly.isEmpty ? 0 : int.parse(digitsOnly);
    final value = cents / 100;
    final formatted = formatAmount(value);
    if (_controller.text != formatted) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: _handleChanged,
      decoration: InputDecoration(labelText: widget.label, prefixText: '\$ '),
    );
  }
}
