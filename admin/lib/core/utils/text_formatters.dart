import 'package:flutter/services.dart';

/// Fuerza mayúsculas mientras el usuario escribe — CURP y RFC siempre se
/// capturan en mayúsculas.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Un solo formatter para un campo de "% de participación": permite
/// dígitos con hasta 2 decimales, y rechaza cualquier edición que deje el
/// valor por encima de 100 — ver docs/business/kyb-cliente.md
/// (porcentaje de un Beneficiario Controlador).
final List<TextInputFormatter> percentageInputFormatters = [
  TextInputFormatter.withFunction((oldValue, newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(text)) return oldValue;
    final parsed = double.tryParse(text);
    if (parsed != null && parsed > 100) return oldValue;
    return newValue;
  }),
];

/// Solo letras y dígitos (sin acentos ni símbolos) — CURP/RFC no admiten
/// otro tipo de carácter. Combinar con [UpperCaseTextFormatter] y
/// `TextField.maxLength` para la longitud exacta (18 para CURP, 12/13
/// para RFC de persona moral/física).
final alphanumericInputFormatter = FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'));
