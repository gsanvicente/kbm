import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbm_admin/core/utils/text_formatters.dart';

/// Aplica una lista de [TextInputFormatter] en orden, como lo haría un
/// `TextField` real al recibir una edición.
TextEditingValue _apply(List<TextInputFormatter> formatters, String oldText, String newText) {
  var value = TextEditingValue(text: newText);
  final old = TextEditingValue(text: oldText);
  for (final formatter in formatters) {
    value = formatter.formatEditUpdate(old, value);
  }
  return value;
}

void main() {
  group('UpperCaseTextFormatter', () {
    test('forces uppercase as the user types', () {
      final result = UpperCaseTextFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abc123'),
      );
      expect(result.text, 'ABC123');
    });
  });

  group('percentageInputFormatters', () {
    test('allows a valid percentage with up to two decimals', () {
      expect(_apply(percentageInputFormatters, '', '99.99').text, '99.99');
    });

    test('allows exactly 100', () {
      expect(_apply(percentageInputFormatters, '10', '100').text, '100');
    });

    test('rejects a value over 100', () {
      expect(_apply(percentageInputFormatters, '10', '101').text, '10');
    });

    test('rejects letters', () {
      expect(_apply(percentageInputFormatters, '', 'abc').text, '');
    });

    test('rejects a third decimal digit', () {
      expect(_apply(percentageInputFormatters, '12.34', '12.345').text, '12.34');
    });

    test('rejects a second decimal point', () {
      expect(_apply(percentageInputFormatters, '12.3', '12.3.4').text, '12.3');
    });

    test('rejects more than 3 integer digits', () {
      expect(_apply(percentageInputFormatters, '100', '1000').text, '100');
    });
  });
}
