import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/payment_card.dart';

/// Resolves a transfer's destination card by its last 4 digits — the
/// identifier a Tarjetahabiente would actually give someone — instead of
/// a searchable directory of every card in the company. Deliberate
/// security/privacy choice, not a shortcut: see
/// docs/security/threat-model.md punto 9 and
/// docs/feature/operacion-saldo-con-aprobacion/README.md, "Captura de la
/// tarjeta destino".
class CardDestinationField extends StatefulWidget {
  const CardDestinationField({
    super.key,
    required this.candidates,
    required this.cardholderNameById,
    required this.onResolved,
  });

  /// Already scoped by the caller to the source card's own Cliente,
  /// excluding the source card itself and any ineligible card
  /// (unassigned/cancelled) — this widget never fetches or lists on its
  /// own, it only matches against what it's given.
  final List<PaymentCard> candidates;
  final Map<String, String> cardholderNameById;
  final ValueChanged<PaymentCard?> onResolved;

  @override
  State<CardDestinationField> createState() => _CardDestinationFieldState();
}

class _CardDestinationFieldState extends State<CardDestinationField> {
  final _controller = TextEditingController();
  PaymentCard? _resolved;
  bool _notFound = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    if (raw.length < 4) {
      setState(() {
        _resolved = null;
        _notFound = false;
      });
      widget.onResolved(null);
      return;
    }
    final matches = widget.candidates.where((c) => c.maskedPan.endsWith(raw)).toList();
    setState(() {
      _resolved = matches.length == 1 ? matches.first : null;
      _notFound = matches.isEmpty;
    });
    widget.onResolved(_resolved);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(labelText: 'Tarjeta destino (últimos 4 dígitos)'),
          onChanged: _handleChanged,
        ),
        const SizedBox(height: 8),
        if (_resolved != null)
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Destino: ${widget.cardholderNameById[_resolved!.cardholderId] ?? '—'} '
                  '(${_resolved!.maskedPan})',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          )
        else if (_notFound)
          Text(
            'No se encontró ninguna tarjeta con esa terminación en esta empresa.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
          ),
      ],
    );
  }
}
