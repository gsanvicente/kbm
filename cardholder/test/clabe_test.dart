import 'package:flutter_test/flutter_test.dart';
import 'package:kbm_cardholder/core/utils/clabe.dart';

/// Mismos casos que `backend/internal/domain/clabe/clabe_test.go` — este
/// puerto a Dart tiene que producir exactamente los mismos resultados
/// que el servidor, o la vista previa mentiría. Ver
/// docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md.
void main() {
  test('isValidClabeChecksum accepts a real seeded CLABE (Banorte)', () {
    expect(isValidClabeChecksum('072123456789012302'), isTrue);
    expect(clabeBankName('072123456789012302'), 'Banorte');
  });

  test('isValidClabeChecksum accepts a freshly computed checksum', () {
    const prefix = '84600001183597193'; // 17 dígitos exactos
    final digit = clabeCheckDigit(prefix);
    expect(digit, isNotNull);
    expect(isValidClabeChecksum('$prefix$digit'), isTrue);
  });

  test('isValidClabeChecksum rejects wrong length', () {
    expect(isValidClabeChecksum('12345'), isFalse);
  });

  test('isValidClabeChecksum rejects non-digits', () {
    expect(isValidClabeChecksum('84600001183597A193'), isFalse);
  });

  test('isValidClabeChecksum rejects a tampered internal digit', () {
    const prefix = '84600001183597193'; // 17 dígitos exactos
    final digit = clabeCheckDigit(prefix)!;
    final good = '$prefix$digit';
    final tamperedChar = (int.parse(good[5]) + 1) % 10;
    final tampered = good.replaceRange(5, 6, tamperedChar.toString());
    expect(isValidClabeChecksum(tampered), isFalse);
  });

  test('clabeBankName returns null for an unknown bank code', () {
    expect(clabeBankName('99900001183597193'), isNull);
  });

  test('clabeBankName returns null before 3 digits are typed', () {
    expect(clabeBankName('07'), isNull);
  });
}
