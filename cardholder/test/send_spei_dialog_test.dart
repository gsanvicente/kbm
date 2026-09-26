import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbm_cardholder/core/fake_backend.dart';
import 'package:kbm_cardholder/core/models/beneficiary.dart';
import 'package:kbm_cardholder/features/spei/send_spei_dialog.dart';

/// Bug real reportado en vivo (2026-09-25): un Tarjetahabiente con
/// $736.00 pudo "enviar" un pago SPEI de $10,000.00 — el backend lo
/// aceptó como `pending_approval` sin ningún aviso, porque el saldo solo
/// se valida al momento de ejecutar, no al capturar. Ver
/// docs/adr/0027-validacion-de-saldo-y-estatus-de-pago-spei.md.
void main() {
  final beneficiary = Beneficiary(
    id: 'ben-1',
    alias: 'Mamá',
    clabe: '072123456789012302',
    bankName: 'Banorte',
    coolingUntil: DateTime(2020),
    createdAt: DateTime(2020),
  );

  Future<void> pumpDialog(WidgetTester tester, {required double balance}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => SendSpeiDialog(
                  cardholderId: 'ch-1',
                  beneficiaries: [beneficiary],
                  balance: balance,
                  currency: 'MXN',
                  repository: FakeCardholderBackend(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('blocks continuing when the requested amount exceeds the available balance', (tester) async {
    await pumpDialog(tester, balance: 736);

    await tester.tap(find.byType(DropdownButtonFormField<Beneficiary>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mamá · •••• 2302').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1000000'); // $10,000.00 (masked cents input)
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
    expect(find.text('Vas a enviar'), findsNothing); // never reached the confirm step
  });

  testWidgets('allows continuing when the requested amount is within balance', (tester) async {
    await pumpDialog(tester, balance: 736);

    await tester.tap(find.byType(DropdownButtonFormField<Beneficiary>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mamá · •••• 2302').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '50000'); // $500.00 (masked cents input)
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo insuficiente'), findsNothing);
    expect(find.text('Vas a enviar'), findsOneWidget);
  });
}
