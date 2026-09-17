import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kbm_admin/app/app.dart';

Future<void> _login(WidgetTester tester, String email) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'LocalDevOnly123!');
  final loginButton = find.widgetWithText(FilledButton, 'Ingresar');
  await tester.ensureVisible(loginButton);
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

Future<void> _goToSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the login screen when there is no session', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Consola administrativa'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
  });

  testWidgets('logging in with a seeded user reaches the admin shell', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    expect(find.text('Koons Subsidiaria A'), findsOneWidget);
    expect(find.text('Grupo Koons Holding'), findsNothing);
  });

  testWidgets('drilling into a client shows its cardholders, breadcrumb goes back', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Koons Subsidiaria A');

    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.byKey(const Key('breadcrumb-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();

    expect(find.text('Koons Subsidiaria A'), findsOneWidget);
    expect(find.text('Juan Perez'), findsNothing);
  });

  testWidgets('client with no cardholders of its own shows an empty state', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Grupo Koons Holding');

    expect(find.text('Este cliente no tiene tarjetahabientes propios'), findsOneWidget);
  });

  testWidgets('global Tarjetahabientes list shows people from every accessible client', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');

    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('Maria Gomez'), findsOneWidget);
    // 2 cardholders per subsidiary share the same trailing client label
    expect(find.text('Koons Subsidiaria A'), findsNWidgets(2));
    expect(find.text('Koons Subsidiaria B'), findsNWidgets(2));
  });

  testWidgets('Admin Cliente can edit a cardholder from the detail view', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Juan Perez');

    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '+1 809 000 0000');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('+1 809 000 0000'), findsOneWidget);
  });

  testWidgets('Admin Cliente can deactivate a cardholder without approval', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Juan Perez');

    expect(find.text('Activo'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(find.text('Inactivo'), findsWidgets);
  });

  testWidgets('Auditor can see a cardholder but not manage them', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Juan Perez');

    expect(find.text('PERJ850312HDFRRN05'), findsOneWidget); // CURP
    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Desactivar'), findsNothing);
  });

  testWidgets('a cardholder flagged as PEP shows the badge in list and detail', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');
    expect(find.text('PEP'), findsOneWidget); // Carlos Ruiz, in the list

    await _goToSection(tester, 'Carlos Ruiz');
    expect(find.text('PEP'), findsOneWidget); // header badge
    expect(find.text('Sí'), findsOneWidget); // Cumplimiento section value
  });
}
