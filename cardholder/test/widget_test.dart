import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kbm_cardholder/app/app.dart';

const _password = 'LocalDevOnly123!';

Future<void> _login(WidgetTester tester, String email, {String password = _password}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), password);
  final loginButton = find.widgetWithText(FilledButton, 'Ingresar');
  await tester.ensureVisible(loginButton);
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

/// Llena y confirma el diálogo de Transferir hasta el paso de captura —
/// no incluye "Buscar destino" ni la confirmación, cada test decide qué
/// tan lejos llegar.
Future<void> _openTransferAndFill(WidgetTester tester, {required String amountCents, required String pan}) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Monto'), amountCents);
  await tester.enterText(find.byType(TextField).last, pan);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the login screen with no session', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Ingresar'), findsOneWidget);
  });

  testWidgets('a single-card cardholder lands directly on their card detail', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    expect(find.text('**** **** **** 1234'), findsOneWidget);
    expect(find.text('\$1,250.00 MXN'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Transferir'), findsOneWidget);
  });

  testWidgets('wrong password shows a generic error', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test', password: 'wrong');

    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('an inactive cardholder cannot log in', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'inactivo@cardholder.test');

    // Mismo mensaje genérico que una contraseña incorrecta — Capa 1 de
    // docs/business/desactivacion-de-tarjetahabientes.md.
    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('a cardholder with more than one card sees a selector first', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'sofia.ramirez@cardholder.test');

    expect(find.text('Mis tarjetas'), findsOneWidget);
    expect(find.text('**** **** **** 4321'), findsOneWidget);
    expect(find.text('**** **** **** 8899'), findsOneWidget);

    await tester.tap(find.text('**** **** **** 4321'));
    await tester.pumpAndSettle();
    expect(find.text('\$600.00 MXN'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mis tarjetas'), findsOneWidget);
  });

  testWidgets('a blocked card shows no Transferir button and a contact-admin message', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'carlos.ruiz@cardholder.test');

    expect(find.text('Bloqueada'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Transferir'), findsNothing);
    expect(find.textContaining('Contacta a tu administrador'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Bloqueo temporal'), findsNothing);
  });

  testWidgets('a cardholder can apply and remove a temporary block on their own active card', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    expect(find.widgetWithText(FilledButton, 'Transferir'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Bloqueo temporal'));
    await tester.pumpAndSettle();

    expect(find.text('Bloqueo temporal'), findsWidgets); // insignia de la tarjeta + snackbar/mensaje
    expect(find.widgetWithText(FilledButton, 'Transferir'), findsNothing);
    expect(find.text('\$1,250.00 MXN'), findsOneWidget); // el saldo no cambia por congelar

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar bloqueo temporal'));
    await tester.pumpAndSettle();

    expect(find.text('Activa'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Transferir'), findsOneWidget);
  });

  testWidgets('a successful C2C transfer moves balance and never asks for approval', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await _openTransferAndFill(tester, amountCents: '10000', pan: '5500000000005566'); // Ana Torres
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('**** **** **** 5566'), findsOneWidget);
    expect(find.textContaining('sin necesidad de aprobación'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Transferencia realizada.'), findsOneWidget);
    expect(find.text('\$1,150.00 MXN'), findsOneWidget); // 1250 - 100
  });

  testWidgets('a card number from a different Cliente resolves to nothing', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await _openTransferAndFill(tester, amountCents: '5000', pan: '5500000000005678'); // Maria Gomez, Subsidiaria B
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No encontramos ninguna tarjeta válida'), findsOneWidget);
  });

  testWidgets('a made-up card number gives the exact same generic error', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await _openTransferAndFill(tester, amountCents: '5000', pan: '0000000000000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No encontramos ninguna tarjeta válida'), findsOneWidget);
  });

  testWidgets('transferring to your own other card resolves to nothing', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'sofia.ramirez@cardholder.test');

    await tester.tap(find.text('**** **** **** 4321'));
    await tester.pumpAndSettle();

    await _openTransferAndFill(tester, amountCents: '1000', pan: '5500000000008899'); // su propia otra tarjeta
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No encontramos ninguna tarjeta válida'), findsOneWidget);
  });

  testWidgets('insufficient funds fails the transfer without touching any balance', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await _openTransferAndFill(tester, amountCents: '999999999', pan: '5500000000005566'); // 9,999,999.99
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fondos insuficientes'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Atrás'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('\$1,250.00 MXN'), findsOneWidget); // sin cambios
  });

  testWidgets('five failed destination lookups lock the form for the rest of the session', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    for (var i = 0; i < 5; i++) {
      await _openTransferAndFill(tester, amountCents: '1000', pan: '0000000000000000');
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
      await tester.pumpAndSettle();
      if (i < 4) {
        await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.textContaining('Demasiados intentos fallidos'), findsOneWidget);
    final searchButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Buscar destino'));
    expect(searchButton.onPressed, isNull);
  });

  testWidgets('logging out returns to the login screen', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Ingresar'), findsOneWidget);
  });

  testWidgets('the Movimientos tab lists the seeded ledger entries for the current card', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Movimientos'), findsWidgets);
    expect(find.text('Carga inicial'), findsOneWidget);
    expect(find.text('Compra en restaurante'), findsOneWidget);
    expect(find.text('Carga de fondos'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('\$1,250.00 MXN'), findsOneWidget);
  });

  testWidgets('a completed transfer shows up in Movimientos right away', (tester) async {
    await tester.pumpWidget(const KbmCardholderApp());
    await tester.pumpAndSettle();
    await _login(tester, 'juan.perez@cardholder.test');

    await _openTransferAndFill(tester, amountCents: '10000', pan: '5500000000005566'); // Ana Torres
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar destino'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();

    expect(find.text('Transferencia enviada'), findsOneWidget);
  });
}
