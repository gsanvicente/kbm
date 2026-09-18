import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kbm_admin/app/app.dart';

Future<void> _login(WidgetTester tester, String email) async {
  // Desktop-sized viewport: the admin shell is designed for real browser
  // windows, not phone-sized 800x600. Avoids fragile scroll-into-view
  // math in list-heavy tests (see 2026-09-17 Tarjetas feature).
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'LocalDevOnly123!');
  final loginButton = find.widgetWithText(FilledButton, 'Ingresar');
  await tester.ensureVisible(loginButton);
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

Future<void> _goToSection(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens a MultiSelectFilterButton combo (found by its current label, so
/// pass the un-suffixed label e.g. "Estado", not "Estado (1)") and taps
/// one checkbox option inside it. Leaves the menu open, same as a real
/// user picking several options before dismissing it.
Future<void> _toggleFilterOption(WidgetTester tester, String comboLabel, String option) async {
  await tester.tap(find.widgetWithText(OutlinedButton, comboLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile, option));
  await tester.pumpAndSettle();
}

/// Types into the Tarjetahabiente autocomplete search field and picks a
/// suggestion — selecting is what actually applies the filter, per
/// docs/feature/pool-y-asignacion-de-tarjetas/README.md.
Future<void> _searchAndPickCardholder(WidgetTester tester, String query, String pick) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
  final suggestion = find.descendant(
    of: find.byKey(const Key('cardholder-search-options')),
    matching: find.text(pick),
  );
  await tester.tap(suggestion);
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

  testWidgets('the Tarjetahabientes Empresa filter narrows the list by company', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');
    await _toggleFilterOption(tester, 'Empresa', 'Koons Subsidiaria B');

    expect(find.text('Maria Gomez'), findsOneWidget); // Subsidiaria B
    expect(find.text('Juan Perez'), findsNothing); // Subsidiaria A
  });

  testWidgets('the Tarjetahabientes Empresa filter is hidden for a single-client role', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');

    expect(find.widgetWithText(OutlinedButton, 'Empresa'), findsNothing);
  });

  testWidgets('searching and picking a name narrows the Tarjetahabientes list to that person', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');
    await _searchAndPickCardholder(tester, 'Maria', 'Maria Gomez');

    // Scoped to the list, not the search box itself — after picking a
    // suggestion its own text field also reads "Maria Gomez".
    final resultsList = find.byType(ListView);
    expect(find.descendant(of: resultsList, matching: find.text('Maria Gomez')), findsOneWidget);
    expect(find.descendant(of: resultsList, matching: find.text('Juan Perez')), findsNothing);
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

  testWidgets('cardholder detail shows their assigned card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Juan Perez');

    expect(find.text('**** **** **** 1234'), findsOneWidget);
  });

  testWidgets('cardholder detail shows an empty state when no cards are assigned', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Ana Torres');

    expect(find.text('Este tarjetahabiente no tiene tarjetas asignadas'), findsOneWidget);
  });

  testWidgets('assigning an available card succeeds within the configured limit', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    // Subsidiaria B allows up to 2 active cards/cardholder; Maria has 1.
    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 3001');

    expect(find.text('Disponible'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria Gomez').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Asignar'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Activa'), findsWidgets);
    expect(find.text('MARIA GOMEZ'), findsOneWidget); // printed on the card art
  });

  testWidgets('assigning a card is rejected once the cardholder is at the client limit', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    // Subsidiaria A allows only 1 active card/cardholder; Juan already has 1.
    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 2001');

    await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juan Perez').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Asignar'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('máximo de 1 tarjeta'), findsOneWidget);
    expect(find.text('Disponible'), findsWidgets); // still unassigned
  });

  testWidgets('Operador cannot see the Asignar button on an available card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 2001');

    expect(find.text('Disponible'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Asignar'), findsNothing);
  });

  testWidgets('an already-assigned card shows its cardholder from the global Tarjetas list', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 5678'); // seeded as Maria Gomez's card

    expect(find.text('MARIA GOMEZ'), findsOneWidget); // printed on the card art
    expect(find.text('SIN ASIGNAR'), findsNothing);
  });

  testWidgets('the Tarjetas Estado filter narrows the list and supports multiple values', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    expect(find.text('**** **** **** 1234'), findsOneWidget); // active
    expect(find.text('**** **** **** 2001'), findsOneWidget); // unassigned
    expect(find.text('**** **** **** 7890'), findsOneWidget); // blocked

    await _toggleFilterOption(tester, 'Estado', 'Disponible');

    expect(find.text('**** **** **** 1234'), findsNothing);
    expect(find.text('**** **** **** 7890'), findsNothing);
    expect(find.text('**** **** **** 2001'), findsOneWidget);

    // Adding a second value to the same combo is additive (OR within the
    // facet), not a replacement.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bloqueada'));
    await tester.pumpAndSettle();

    expect(find.text('**** **** **** 2001'), findsOneWidget);
    expect(find.text('**** **** **** 7890'), findsOneWidget);
    expect(find.text('**** **** **** 1234'), findsNothing); // still excluded (active)
  });

  testWidgets('the Tarjetas Empresa filter narrows the list by company', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _toggleFilterOption(tester, 'Empresa', 'Koons Subsidiaria B');

    expect(find.text('**** **** **** 1234'), findsNothing); // Subsidiaria A
    expect(find.text('**** **** **** 5678'), findsOneWidget); // Subsidiaria B
  });

  testWidgets('the Empresa filter is hidden when the role only has one accessible client', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');

    expect(find.widgetWithText(OutlinedButton, 'Empresa'), findsNothing);
  });

  testWidgets('searching and picking a Tarjetahabiente narrows the Tarjetas list to their cards', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _searchAndPickCardholder(tester, 'Juan', 'Juan Perez');

    expect(find.text('**** **** **** 1234'), findsOneWidget); // Juan's card
    expect(find.text('**** **** **** 5678'), findsNothing);
    expect(find.text('**** **** **** 2001'), findsNothing); // available cards never match
  });

  testWidgets('Limpiar filtros resets every active Tarjetas filter', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _toggleFilterOption(tester, 'Estado', 'Disponible');
    expect(find.text('**** **** **** 1234'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('**** **** **** 1234'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Limpiar filtros'), findsNothing);
  });

  testWidgets('Operador can block an active card directly, no approval needed', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez, active

    await tester.tap(find.widgetWithText(OutlinedButton, 'Bloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Bloqueada'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Desbloquear'), findsOneWidget);
  });

  testWidgets('Operador can unblock a blocked card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 7890'); // Carlos Ruiz, seeded as blocked

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Activa'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Bloquear'), findsOneWidget);
  });

  testWidgets('Auditor cannot see block/unblock controls on an assigned card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');

    expect(find.widgetWithText(OutlinedButton, 'Bloquear'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Desbloquear'), findsNothing);
  });

  testWidgets('an available card never shows block/unblock, only Asignar', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 2001'); // unassigned

    expect(find.widgetWithText(FilledButton, 'Asignar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Bloquear'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Desbloquear'), findsNothing);
  });

  testWidgets('the Tarjetas list shows balance for assigned cards, and "sin cuenta" for available ones',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');

    expect(find.textContaining('Saldo: \$1,250.00 MXN'), findsOneWidget); // Juan Perez's card
    expect(find.text('Sin cuenta de saldo'), findsWidgets); // the 4 unassigned pool cards
  });

  testWidgets('card detail shows the balance prominently for an assigned card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez

    expect(find.text('SALDO ACTUAL'), findsOneWidget);
    expect(find.text('\$1,250.00 MXN'), findsOneWidget);
  });

  testWidgets('card detail shows "sin cuenta de saldo" for an available card, not \$0.00', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 2001'); // unassigned

    expect(find.text('Sin cuenta de saldo'), findsOneWidget);
    expect(find.textContaining('\$0.00'), findsNothing);
  });

  testWidgets('a blocked card still shows its balance normally', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 7890'); // Carlos Ruiz, seeded blocked

    expect(find.text('\$75.00 MXN'), findsOneWidget);
  });

  testWidgets('the Movimientos tab lists a card\'s ledger entries with a claim badge', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez
    await _goToSection(tester, 'Movimientos');

    expect(find.text('Carga inicial'), findsOneWidget);
    expect(find.text('Compra en restaurante'), findsOneWidget);
    expect(find.text('Carga de fondos'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget); // seeded claim on the restaurant charge
  });

  testWidgets('Operador can file a claim on a movement with no existing claim', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Movimientos');

    await tester.tap(find.text('Carga de fondos'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Reclamar este movimiento'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reclamar este movimiento'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Motivo del reclamo'), 'Cargo duplicado.');
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar reclamo'));
    await tester.pumpAndSettle();

    // The list underneath already re-rendered too, so scope to the dialog.
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Abierto')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Abierto'), findsOneWidget); // now shown as the list-row badge
  });

  testWidgets('Auditor cannot file a claim', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Movimientos');

    await tester.tap(find.text('Carga de fondos'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Reclamar este movimiento'), findsNothing);
    expect(find.textContaining('no puede solicitar reclamos'), findsOneWidget);
  });

  testWidgets('Admin Cliente can resolve an in-review claim in favor', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Movimientos');

    await tester.tap(find.text('Compra en restaurante')); // has the seeded in_review claim
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Resolver a favor'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Resolver a favor'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Notas de resolución (a favor)'),
      'Se valida ante el banco emisor.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar a favor'));
    await tester.pumpAndSettle();

    // The list underneath already re-rendered too, so scope to the dialog.
    final dialogFinder = find.byType(AlertDialog);
    expect(find.descendant(of: dialogFinder, matching: find.text('Resuelto a favor')), findsOneWidget);
    expect(find.descendant(of: dialogFinder, matching: find.text('admin.subA@koons.test')), findsOneWidget);
  });

  testWidgets('card detail shows the cardholder\'s name on the card, not the company name', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez, Koons Subsidiaria A

    expect(find.text('JUAN PEREZ'), findsOneWidget); // printed on the card art
    expect(find.text('KOONS SUBSIDIARIA A'), findsNothing);
  });

  testWidgets('an available card shows a placeholder name on the card art', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 2001'); // unassigned

    expect(find.text('SIN ASIGNAR'), findsOneWidget);
  });

  testWidgets('card detail no longer shows the assignment date, only the Tarjetas list does', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    expect(find.text('Asignada: 10/01/2026'), findsOneWidget); // Juan Perez's card, in the list

    await _goToSection(tester, '**** **** **** 1234');
    expect(find.text('Fecha de asignación'), findsNothing);
  });

  testWidgets('Operador cannot resolve a claim, only file one', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Movimientos');

    await tester.tap(find.text('Compra en restaurante')); // has the seeded in_review claim
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Resolver a favor'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Rechazar'), findsNothing);
    expect(find.textContaining('no puede resolver reclamos'), findsOneWidget);
  });

  testWidgets('Operaciones de saldo shows the seeded pending Deducción', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');

    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
  });

  testWidgets('the Empresa filter in Operaciones de saldo is hidden for a single-client role', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');

    expect(find.widgetWithText(OutlinedButton, 'Empresa'), findsNothing);
  });

  testWidgets('Operaciones de saldo has no creation button — it is history-only', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');

    expect(find.widgetWithText(FilledButton, 'Nueva operación'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Auditor sees a card\'s Operaciones tab but not the action buttons', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Operaciones');

    expect(find.widgetWithText(FilledButton, 'Dispersión'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Deducción'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Transferencia'), findsNothing);
    expect(find.textContaining('no solicitar nuevas'), findsOneWidget);
  });

  testWidgets(
      'Operador can request a Dispersión (it\'s the point of the role), and it refreshes '
      'the balance shown in Resumen', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test'); // Operador de Saldos: this is exactly its job

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez, balance 1250.00
    await _goToSection(tester, 'Operaciones');

    await tester.tap(find.widgetWithText(FilledButton, 'Dispersión'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva operación'), findsOneWidget); // generic dialog title
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10000'); // masked as $100.00
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ejecutada de inmediato'), findsOneWidget);
    expect(find.textContaining('Dispersión: **** **** **** 1234'), findsOneWidget);
    expect(find.text('Ejecutada'), findsOneWidget);

    await _goToSection(tester, 'Resumen');
    expect(find.text('\$1,350.00 MXN'), findsOneWidget); // 1250.00 + 100.00, no manual refresh needed
  });

  testWidgets('a Deducción with no configured rule requires approval by default', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Operaciones');

    await tester.tap(find.widgetWithText(FilledButton, 'Deducción'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '5000'); // $50.00
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pendiente de aprobación'), findsOneWidget);
  });

  testWidgets('the amount field only accepts digits, masked to 2 decimals', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Operaciones');
    await tester.tap(find.widgetWithText(FilledButton, 'Dispersión'));
    await tester.pumpAndSettle();

    expect(find.text('0.00'), findsOneWidget); // default before typing anything

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), 'asdasd');
    await tester.pumpAndSettle();
    expect(find.text('0.00'), findsOneWidget); // letters never reach the field

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '123456');
    await tester.pumpAndSettle();
    expect(find.text('1,234.56'), findsOneWidget);
  });

  testWidgets('a transfer at or under the threshold executes immediately and moves both balances',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 5678'); // Maria Gomez
    await _goToSection(tester, 'Operaciones');

    await tester.tap(find.widgetWithText(FilledButton, 'Transferencia'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10000'); // $100.00
    await tester.enterText(
      find.widgetWithText(TextField, 'Tarjeta destino (últimos 4 dígitos)'),
      '7890', // Carlos Ruiz, same Cliente
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Destino: Carlos Ruiz'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ejecutada de inmediato'), findsOneWidget);
    expect(
      find.textContaining('Transferencia: **** **** **** 5678 → **** **** **** 7890'),
      findsOneWidget,
    );
  });

  testWidgets('an immediate transfer that exceeds the source balance fails, not partially applied',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 7890'); // Carlos Ruiz, balance 75.00
    await _goToSection(tester, 'Operaciones');

    await tester.tap(find.widgetWithText(FilledButton, 'Transferencia'));
    await tester.pumpAndSettle();

    // Well under the 500 approval threshold, so this never needs
    // approval, but 100 still exceeds his balance of 75.00.
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Tarjeta destino (últimos 4 dígitos)'),
      '5678', // Maria Gomez, same Cliente
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('fallida'), findsOneWidget);
    expect(find.text('Fallida'), findsOneWidget);
  });

  testWidgets('the destination field only resolves cards from the same company', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 5678'); // Maria Gomez, Subsidiaria B
    await _goToSection(tester, 'Operaciones');
    await tester.tap(find.widgetWithText(FilledButton, 'Transferencia'));
    await tester.pumpAndSettle();

    // Juan Perez's card ends the same as no card in Subsidiaria B —
    // 1234 doesn't belong to this company at all.
    await tester.enterText(find.widgetWithText(TextField, 'Tarjeta destino (últimos 4 dígitos)'), '1234');
    await tester.pumpAndSettle();

    expect(find.textContaining('No se encontró ninguna tarjeta'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Tarjeta destino (últimos 4 dígitos)'), '7890');
    await tester.pumpAndSettle();

    expect(find.textContaining('Destino: Carlos Ruiz'), findsOneWidget);
  });

  testWidgets('Admin Cliente can approve a pending operation, executing it', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Aprobaciones');
    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget);

    await tester.tap(find.byTooltip('Aprobar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('aprobada y ejecutada'), findsOneWidget);
    expect(find.textContaining('Deducción: **** **** **** 1234'), findsNothing);
  });

  testWidgets('Admin Cliente can reject a pending operation with a reason', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Aprobaciones');
    await tester.tap(find.byTooltip('Rechazar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Motivo del rechazo'), 'No autorizado.');
    await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
    await tester.pumpAndSettle();

    expect(find.text('Operación rechazada.'), findsOneWidget);
    expect(find.textContaining('Deducción: **** **** **** 1234'), findsNothing);
  });

  testWidgets('Operador can see Aprobaciones but not act on it', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Aprobaciones');

    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget);
    expect(find.byTooltip('Aprobar'), findsNothing);
    expect(find.byTooltip('Rechazar'), findsNothing);
    expect(find.textContaining('no aprobar ni rechazar'), findsOneWidget);
  });
}
