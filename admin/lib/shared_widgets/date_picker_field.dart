import 'package:flutter/material.dart';

import '../core/utils/date_format.dart';

/// Campo de fecha de solo-lectura que abre `showDatePicker` al tocarlo —
/// usado en el wizard de alta y en la edición de Cliente.
class DatePickerField extends StatelessWidget {
  const DatePickerField({super.key, required this.label, required this.value, required this.onPick});

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onPick,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(value != null ? formatDate(value) : 'Seleccionar'),
        ),
      ),
    );
  }
}
