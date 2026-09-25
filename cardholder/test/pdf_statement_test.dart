import 'package:flutter_test/flutter_test.dart';
import 'package:kbm_cardholder/shared_widgets/pdf_statement.dart';

/// No verifica el layout visual (eso se hizo a ojo durante el diseño,
/// ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md,
/// punto 6) — solo que `buildStatementPdf` no truene por un asset roto
/// (el logo) o una config de tabla inválida, y que produzca bytes con
/// cabecera PDF real.
void main() {
  testWidgets('buildStatementPdf produces a non-empty PDF for a statement with movements', (tester) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Individual',
      infoFields: const [MapEntry('Titular', 'Juan Pérez'), MapEntry('Cliente', 'Koons Subsidiaria A')],
      balance: 1000,
      currency: 'MXN',
      periodLabel: 'Este mes',
      rows: const [
        PdfStatementRow(date: '01/01/2026 10:00', isCredit: true, description: 'Depósito', amount: 500, balanceAfter: 1000),
      ],
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('buildStatementPdf handles an empty movements list', (tester) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Concentradora',
      infoFields: const [MapEntry('Cliente', 'Koons Subsidiaria A')],
      balance: 0,
      currency: 'MXN',
      periodLabel: 'Todo el historial',
      rows: const [],
    );
    expect(bytes, isNotEmpty);
  });

  test('sanitizeForPdf replaces the bullet used to mask a CLABE — the base PDF font cannot draw it', () {
    // Regresión real: "****2302" en pantalla salía en blanco en el PDF
    // (font sin soporte Unicode para "•") hasta que se agregó este
    // saneo — ver docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md.
    expect(sanitizeForPdf('••••2302'), '****2302');
  });

  test('sanitizeForPdf replaces em/en dashes and smart quotes', () {
    expect(sanitizeForPdf('KBM — Koons'), 'KBM - Koons');
    expect(sanitizeForPdf('a–b'), 'a-b');
    expect(sanitizeForPdf('“hola”'), '"hola"');
  });
}
