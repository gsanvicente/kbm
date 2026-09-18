import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Campo de número de tarjeta destino de una transferencia C2C — enmascara
/// visualmente todo menos los últimos 4 dígitos mientras el usuario
/// escribe, pero [onChanged] siempre entrega el valor completo real. Es
/// **solo UX**, no cifrado — ver
/// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md, punto 2 ("para
/// una app web, cualquier llave puesta en el cliente sería visible en el
/// bundle — falsa sensación de seguridad").
///
/// Implementado con un `TextField` de texto transparente (para conservar
/// cursor/selección/teclado nativos) superpuesto a un `Text` con la
/// versión enmascarada — no se pudo verificar la alineación exacta con
/// una captura de pantalla real (limitación del entorno); confirmar
/// visualmente y ajustar `_padding` si hace falta.
class MaskedCardNumberField extends StatefulWidget {
  const MaskedCardNumberField({super.key, required this.onChanged, this.enabled = true});

  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<MaskedCardNumberField> createState() => _MaskedCardNumberFieldState();
}

class _MaskedCardNumberFieldState extends State<MaskedCardNumberField> {
  static const _padding = EdgeInsets.symmetric(horizontal: 12, vertical: 16);

  final _controller = TextEditingController();
  String _masked = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged() {
    final digits = _controller.text;
    final visibleCount = digits.length <= 4 ? digits.length : 4;
    final hiddenCount = digits.length - visibleCount;
    setState(() {
      _masked = ('•' * hiddenCount) + digits.substring(digits.length - visibleCount);
    });
    widget.onChanged(digits);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Número de tarjeta destino',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            TextField(
              controller: _controller,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
              style: const TextStyle(color: Colors.transparent),
              cursorColor: KoonsColors.blue,
              decoration: const InputDecoration(contentPadding: _padding),
            ),
            IgnorePointer(
              child: Padding(
                padding: _padding,
                child: Text(
                  _masked.isEmpty ? 'Número completo de la tarjeta' : _masked,
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: _masked.isEmpty ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
