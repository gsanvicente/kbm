import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kbm_admin/app/app.dart';

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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'admin.subA@koons.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'LocalDevOnly123!',
    );
    final loginButton = find.widgetWithText(FilledButton, 'Ingresar');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Koons Subsidiaria A'), findsOneWidget);
    expect(find.text('Grupo Koons Holding'), findsNothing);
  });
}
