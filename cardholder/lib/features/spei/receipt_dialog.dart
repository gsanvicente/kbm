import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';

/// Comprobante propio de KBM — nunca el CEP oficial de Banxico, decisión
/// de alcance explícita, ver docs/adr/0021-conector-spei.md, punto 9.
/// Sirve tanto para un pago SPEI saliente como para un depósito entrante
/// (el documento de referencia original pide comprobante para ambos) —
/// [rows] trae los campos específicos de cada uno, esta pantalla solo
/// les da el mismo formato.
class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({
    super.key,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.folio,
    required this.rows,
    required this.createdAt,
  });

  final String title;
  final double amount;
  final bool isCredit;
  final String folio;
  final List<(String, String)> rows;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: KoonsColors.blue),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: (isCredit ? KoonsColors.green : KoonsColors.navy).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${isCredit ? '+' : '−'}${formatCurrency(amount, 'MXN')}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: isCredit ? KoonsColors.green : KoonsColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(formatMovementDate(createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ReceiptRow(label: 'Folio', value: folio),
              for (final row in rows) _ReceiptRow(label: row.$1, value: row.$2),
              const SizedBox(height: 12),
              Text(
                'Comprobante propio de KBM — no es el CEP oficial de Banxico.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
