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

/// Taps a tab inside `ClientDetailView`'s TabBar by label — "Tarjetahabientes"
/// and "Tesorería" also exist elsewhere (sidebar nav item, breadcrumb), so
/// `find.text` alone is ambiguous here; scoping to `Tab` disambiguates.
Future<void> _goToClientTab(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(Tab, label);
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

/// Opens a `_DatePickerField` (found by its label) and confirms the
/// dialog's default `initialDate` via the "OK" action — good enough for
/// tests that only need *some* valid date, not a specific one.
/// Super Admin's Clientes tree is collapsed by default (see
/// docs/feature/panel-principal-admin/README.md, "Vista jerárquica") —
/// expands one node's chevron so a descendant becomes reachable.
Future<void> _expandClientTreeNode(WidgetTester tester, String clientName) async {
  final row = find.ancestor(of: find.text(clientName), matching: find.byType(ListTile));
  final chevron = find.descendant(of: row, matching: find.byType(IconButton));
  await tester.tap(chevron);
  await tester.pumpAndSettle();
}

Future<void> _confirmDatePicker(WidgetTester tester, String fieldLabel) async {
  final field = find.ancestor(of: find.text(fieldLabel), matching: find.byType(InkWell));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
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

    await _goToSection(tester, 'Clientes'); // Admin Cliente lands on "Inicio" first now
    expect(find.text('Koons Subsidiaria A'), findsOneWidget);
    expect(find.text('Grupo Koons Holding'), findsNothing);
  });

  testWidgets('drilling into a client shows its cardholders, breadcrumb goes back', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');

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

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Grupo Koons Holding');
    await _goToClientTab(tester, 'Tarjetahabientes');

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
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');

    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '5512345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('5512345678'), findsOneWidget);
  });

  testWidgets('Admin Cliente can deactivate a cardholder without approval, after confirming', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');

    expect(find.text('Activo'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(find.text('Inactivo'), findsWidgets);
  });

  testWidgets('deactivating a cardholder freezes their active card, and editing is no longer available', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');

    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Reactivar'), findsOneWidget);

    await _goToSection(tester, '**** **** **** 1234');
    expect(find.text('Bloqueada'), findsWidgets);
  });

  testWidgets('Auditor can see a cardholder but not manage them', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
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
    expect(find.text('PEP'), findsNWidgets(2)); // filtro "PEP" + chip de Carlos Ruiz, in the list

    await _goToSection(tester, 'Carlos Ruiz');
    expect(find.text('PEP'), findsOneWidget); // header badge
    expect(find.text('Sí'), findsOneWidget); // Cumplimiento section value
  });

  testWidgets('cardholder detail shows their assigned card', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');

    expect(find.text('**** **** **** 1234'), findsOneWidget);
  });

  testWidgets('cardholder detail shows an empty state when no cards are assigned', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
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

  testWidgets('Historial completo shows the seeded pending Deducción', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');
    await tester.tap(find.text('Historial completo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
  });

  testWidgets('the Empresa filter in Historial completo is hidden for a single-client role', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');
    await tester.tap(find.text('Historial completo'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Empresa'), findsNothing);
  });

  testWidgets('Historial completo has no creation button — it is history-only', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');
    await tester.tap(find.text('Historial completo'));
    await tester.pumpAndSettle();

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

    await _goToSection(tester, 'Operaciones de saldo');
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

    await _goToSection(tester, 'Operaciones de saldo');
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

    await _goToSection(tester, 'Operaciones de saldo');

    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget);
    expect(find.byTooltip('Aprobar'), findsNothing);
    expect(find.byTooltip('Rechazar'), findsNothing);
    expect(find.textContaining('no aprobar ni rechazar'), findsOneWidget);
  });

  testWidgets('the Tesorería tab shows the Concentradora balance and the seeded pending deposit', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');

    expect(find.text('\$10,000.00 MXN'), findsOneWidget);
    expect(find.textContaining('Referencia: SPEI-DEMO-001'), findsOneWidget);
    // super.admin can reconcile, so the row shows the action button
    // instead of a passive "Pendiente" badge — see the dedicated
    // Auditor/Operador tests below for the read-only badge case.
    expect(find.widgetWithText(OutlinedButton, 'Conciliar'), findsOneWidget);
  });

  testWidgets('Operador can register a deposit, which stays pending and does not move the Concentradora',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar depósito'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '250000'); // $2,500.00
    await tester.enterText(find.widgetWithText(TextField, 'Referencia / folio bancario'), 'SPEI-TEST-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pendiente de conciliar'), findsOneWidget);
    expect(find.textContaining('Referencia: SPEI-TEST-1'), findsOneWidget);
    expect(find.text('\$10,000.00 MXN'), findsOneWidget); // Concentradora unchanged
  });

  testWidgets('Auditor cannot register a deposit', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'auditor.subA@koons.test');

    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');

    expect(find.widgetWithText(FilledButton, 'Registrar depósito'), findsNothing);
    expect(find.textContaining('no registrar nuevos'), findsOneWidget);
  });

  testWidgets('Operador cannot reconcile a pending deposit', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');

    expect(find.textContaining('Referencia: SPEI-DEMO-001'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Conciliar'), findsNothing);
  });

  testWidgets('Admin Cliente can reconcile a deposit, increasing the Concentradora balance', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');

    // Admin Cliente sees the same figure twice: the header chip (their
    // own Concentradora) and the Tesorería body.
    expect(find.text('\$10,000.00 MXN'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Conciliar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('conciliado'), findsOneWidget);
    expect(find.text('Conciliado'), findsOneWidget);
    expect(find.text('\$15,000.00 MXN'), findsOneWidget); // Tesorería body updates immediately
    // The header chip was fetched once at login — it does not live-refresh.
    expect(find.text('\$10,000.00 MXN'), findsOneWidget);
  });

  testWidgets('a Dispersión larger than the Concentradora balance fails, without touching the card',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234'); // Juan Perez, balance 1250.00
    await _goToSection(tester, 'Operaciones');

    await tester.tap(find.widgetWithText(FilledButton, 'Dispersión'));
    await tester.pumpAndSettle();
    // Concentradora de Koons Subsidiaria A only has 10,000.00.
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '1500000'); // $15,000.00
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('fallida'), findsOneWidget);
    expect(find.text('Fallida'), findsOneWidget);

    await _goToSection(tester, 'Resumen');
    expect(find.text('\$1,250.00 MXN'), findsOneWidget); // unchanged

    await _goToSection(tester, 'Clientes'); // permanent sidebar item
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');
    expect(find.text('\$10,000.00 MXN'), findsOneWidget); // unchanged
  });

  testWidgets('approving a Deducción credits the Concentradora', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test'); // can both request and approve

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 1234');
    await _goToSection(tester, 'Operaciones');
    await tester.tap(find.widgetWithText(FilledButton, 'Deducción'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '5000'); // $50.00, no rule => pending
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    await _goToSection(tester, 'Operaciones de saldo');
    // The seeded pending Deducción (200.00) on the same card is also in
    // this queue, sorted most-recent-first — the one just requested
    // (DateTime.now()) always sorts ahead of the seeded one (2026-01-21).
    await tester.tap(find.byTooltip('Aprobar').first);
    await tester.pumpAndSettle();

    await _goToSection(tester, 'Clientes');
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');
    expect(find.text('\$10,050.00 MXN'), findsOneWidget); // 10,000.00 + 50.00
  });

  testWidgets('a transfer between two cards of the same Cliente never touches the Concentradora', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 5678'); // Maria Gomez, Subsidiaria B
    await _goToSection(tester, 'Operaciones');
    await tester.tap(find.widgetWithText(FilledButton, 'Transferencia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '10000'); // $100.00
    await tester.enterText(find.widgetWithText(TextField, 'Tarjeta destino (últimos 4 dígitos)'), '7890');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar'));
    await tester.pumpAndSettle();

    await _goToSection(tester, 'Clientes');
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria B');
    await _goToSection(tester, 'Tesorería');
    expect(find.text('\$10,000.00 MXN'), findsOneWidget); // untouched
  });

  testWidgets('Admin Cliente sees their own Concentradora balance in the header', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    // Lands on "Inicio" (Panel directivo) by default, whose own KPI card
    // shows the same figure as the header chip — see
    // docs/feature/panel-directivo/README.md.
    expect(find.text('\$10,000.00 MXN'), findsNWidgets(2));
  });

  testWidgets('Super Admin sees no balance in the header — no empresa propia to show', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    expect(find.byTooltip('Saldo de la Cuenta Concentradora de tu empresa'), findsNothing);
  });

  testWidgets('Operador and Auditor see no balance indicator in the header', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    expect(find.byTooltip('Saldo de la Cuenta Concentradora de tu empresa'), findsNothing);
  });

  // --- Panel directivo ("Inicio") — docs/feature/panel-directivo/ -------

  testWidgets('Super Admin lands on Inicio and sees KPIs aggregated across all Clientes', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    expect(find.text('Inicio'), findsNWidgets(2)); // sidebar item + header title
    expect(find.text('\$20,000.00 MXN'), findsOneWidget); // Concentradoras: 10,000 (subA) + 10,000 (subB)
    expect(find.text('\$1,665.50 MXN'), findsOneWidget); // tarjetas: 1250.00 + 340.50 + 75.00
  });

  testWidgets('Admin Cliente of the parent company sees a Desglose por empresa with its filiales', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.holding@koons.test');

    expect(find.text('Desglose por empresa'), findsOneWidget);
    expect(find.text('Grupo Koons Holding'), findsOneWidget);
    expect(find.text('Koons Subsidiaria A'), findsOneWidget);
    expect(find.text('Koons Subsidiaria B'), findsOneWidget);
  });

  testWidgets('Admin Cliente without filiales sees Inicio scoped only to their own Cliente', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    expect(find.text('\$1,250.00 MXN'), findsOneWidget); // saldo en tarjetas: solo la 1234 de subA
    expect(find.text('Desglose por empresa'), findsNothing); // sin filiales, no hay nada que comparar
    expect(find.text('1 depósito(s)'), findsOneWidget);
    expect(find.text('1 operación(es)'), findsOneWidget);
  });

  testWidgets('Operador and Auditor never see "Inicio" — they keep landing on Clientes', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Koons Subsidiaria A'), findsOneWidget); // ya aterrizó en Clientes
  });

  testWidgets('tapping a pending operation under "Requiere tu atención" navigates to Operaciones de saldo',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    expect(find.text('Requiere tu atención'), findsOneWidget);
    await tester.tap(find.text('Deducción pendiente de aprobación'));
    await tester.pumpAndSettle();

    expect(find.text('Operaciones de saldo'), findsNWidgets(2)); // sidebar item + header title
  });

  testWidgets('Inicio shows the volumen chart with its synthetic-data disclosure', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    expect(find.text('Volumen de operaciones — últimas 12 semanas'), findsOneWidget);
    expect(find.textContaining('Dato ilustrativo'), findsOneWidget);
    expect(find.text('Dispersión'), findsOneWidget);
    expect(find.text('Transferencia'), findsOneWidget);
  });

  // --- "Operaciones de saldo" como hub (Pendientes + Depósitos + Historial) ---

  testWidgets('Operaciones de saldo hub has Pendientes, Depósitos por conciliar and Historial completo tabs',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');
    expect(find.text('Historial completo'), findsOneWidget); // las 3 pestañas están montadas
    expect(find.textContaining('Deducción: **** **** **** 1234'), findsOneWidget); // pestaña 0 por defecto

    await tester.tap(find.text('Depósitos por conciliar'));
    await tester.pumpAndSettle();

    expect(find.text('Referencia: SPEI-DEMO-001'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Conciliar'), findsOneWidget);
  });

  testWidgets('Admin Cliente can reconcile a deposit from the Operaciones de saldo hub too', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Operaciones de saldo');
    await tester.tap(find.text('Depósitos por conciliar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Conciliar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('conciliado'), findsOneWidget);

    // Mismo saldo actualizado visible desde Tesorería — sigue siendo el
    // otro entry point para la misma acción, no se rompió al agregar el
    // del hub.
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToSection(tester, 'Tesorería');
    expect(find.text('\$15,000.00 MXN'), findsOneWidget); // 10,000 + 5,000
  });

  testWidgets('tapping a pending deposit under "Requiere tu atención" opens the Depósitos por conciliar tab',
      (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    expect(find.text('Depósito pendiente de conciliar'), findsOneWidget);
    await tester.tap(find.text('Depósito pendiente de conciliar'));
    await tester.pumpAndSettle();

    expect(find.text('Operaciones de saldo'), findsNWidgets(2)); // sidebar item + header title
    expect(find.text('Referencia: SPEI-DEMO-001'), findsOneWidget); // aterrizó directo en la pestaña de depósitos
  });

  // --- Alta y gestión de Clientes ----------------------------------------

  testWidgets('Only Admin Cliente and Super Admin see the "Nuevo Cliente" button', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    expect(find.widgetWithText(FilledButton, 'Nuevo Cliente'), findsNothing);
  });

  testWidgets('Admin Cliente does not see the option to create a Cliente without an empresa padre', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Clientes');
    await tester.tap(find.widgetWithText(FilledButton, 'Nuevo Cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Crear sin empresa padre (nueva empresa raíz)'), findsNothing);
  });

  testWidgets('Super Admin can create a new root Cliente with its full KYB expediente', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await tester.tap(find.widgetWithText(FilledButton, 'Nuevo Cliente'));
    await tester.pumpAndSettle();

    // Paso 0: Ubicación.
    await tester.tap(find.text('Crear sin empresa padre (nueva empresa raíz)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // Paso 1: Datos generales.
    await tester.enterText(find.widgetWithText(TextField, 'Razón social'), 'Nueva Empresa de Prueba SA de CV');
    await tester.enterText(find.widgetWithText(TextField, 'RFC'), 'NEP250101AB1');
    await tester.enterText(find.widgetWithText(TextField, 'Objeto social / giro'), 'Comercio al por menor');
    await _confirmDatePicker(tester, 'Fecha de constitución');
    await tester.enterText(find.widgetWithText(TextField, 'Número de escritura'), '12345');
    await tester.enterText(find.widgetWithText(TextField, 'Notario público (acta)'), 'Lic. Juan Notario');
    await tester.enterText(find.widgetWithText(TextField, 'Plaza / ciudad del notario'), 'Ciudad de México');
    await _confirmDatePicker(tester, 'Fecha del acta');
    await tester.enterText(find.widgetWithText(TextField, 'Folio de Registro Público de Comercio'), 'RPC-9999');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // Paso 2: Domicilio fiscal.
    await tester.enterText(find.widgetWithText(TextField, 'Calle y número'), 'Av. Siempre Viva 123');
    await tester.enterText(find.widgetWithText(TextField, 'Colonia'), 'Centro');
    await tester.enterText(find.widgetWithText(TextField, 'Ciudad'), 'CDMX');
    await tester.enterText(find.widgetWithText(TextField, 'Estado'), 'CDMX');
    await tester.enterText(find.widgetWithText(TextField, 'Código postal'), '01000');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // Paso 3: Apoderado principal.
    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo del apoderado'), 'Carlos Apoderado');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación (apoderado)'), 'ID12345');
    await tester.enterText(find.widgetWithText(TextField, 'Número de escritura del poder'), '54321');
    await tester.enterText(find.widgetWithText(TextField, 'Notario público (del poder)'), 'Lic. Ana Notaria');
    await _confirmDatePicker(tester, 'Fecha del instrumento');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // Paso 4: Beneficiario controlador mayoritario.
    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo del beneficiario'), 'Beatriz Beneficiaria');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación (beneficiario)'), 'ID67890');
    await tester.enterText(find.widgetWithText(TextField, '% de participación'), '60');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();

    // Paso 5: Revisión.
    expect(find.text('Nueva Empresa de Prueba SA de CV'), findsWidgets); // resumen de revisión
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear Cliente'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear Cliente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('creado'), findsOneWidget); // snackbar de confirmación

    // Aterrizó en el detalle del Cliente recién creado — regresa al
    // listado por el breadcrumb (no por el sidebar: "Clientes" aparece
    // en ambos a la vez en este punto).
    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    expect(find.text('Nueva Empresa de Prueba SA de CV'), findsOneWidget);
  });

  testWidgets('searching the Clientes tree filters by name and keeps ancestors visible', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    // Super Admin: árbol colapsado por defecto.
    expect(find.text('Koons Subsidiaria A'), findsNothing);
    expect(find.text('Koons Subsidiaria B'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Subsidiaria B');
    await tester.pumpAndSettle();

    expect(find.text('Grupo Koons Holding'), findsOneWidget); // ancestro forzado a mostrarse
    expect(find.text('Koons Subsidiaria B'), findsOneWidget);
    expect(find.text('Koons Subsidiaria A'), findsNothing); // no coincide, se oculta
  });

  testWidgets('clearing the Clientes search restores the collapsed tree', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await tester.enterText(find.byType(TextField), 'Subsidiaria B');
    await tester.pumpAndSettle();
    expect(find.text('Koons Subsidiaria A'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Koons Subsidiaria A'), findsNothing); // vuelve a colapsado, no se filtra ni se expande
    expect(find.text('Koons Subsidiaria B'), findsNothing);
    expect(find.text('Grupo Koons Holding'), findsOneWidget);
  });

  testWidgets('Admin Cliente can edit their own company expediente and the tree label updates', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.holding@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Grupo Koons Holding');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();

    // El expediente sembrado para este Cliente raíz no trae KYB — se
    // completa por primera vez desde la edición.
    await tester.enterText(find.widgetWithText(TextField, 'Razón social'), 'Koons Holding SA de CV');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre comercial (opcional)'), 'Koons Holding');
    await tester.enterText(find.widgetWithText(TextField, 'RFC'), 'KHO250101AB1');
    await tester.enterText(find.widgetWithText(TextField, 'Objeto social / giro'), 'Tenencia de acciones');
    await _confirmDatePicker(tester, 'Fecha de constitución');
    await tester.enterText(find.widgetWithText(TextField, 'Número de escritura'), '111');
    await tester.enterText(find.widgetWithText(TextField, 'Notario público (acta)'), 'Lic. Juan Notario');
    await tester.enterText(find.widgetWithText(TextField, 'Plaza / ciudad del notario'), 'Ciudad de México');
    await _confirmDatePicker(tester, 'Fecha del acta');
    await tester.enterText(find.widgetWithText(TextField, 'Folio de Registro Público de Comercio'), 'RPC-1');
    await tester.enterText(find.widgetWithText(TextField, 'Calle y número'), 'Reforma 100');
    await tester.enterText(find.widgetWithText(TextField, 'Colonia'), 'Juárez');
    await tester.enterText(find.widgetWithText(TextField, 'Ciudad'), 'CDMX');
    await tester.enterText(find.widgetWithText(TextField, 'Estado'), 'CDMX');
    await tester.enterText(find.widgetWithText(TextField, 'Código postal'), '06600');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo del apoderado'), 'Carlos Apoderado');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación (apoderado)'), 'ID1');
    await tester.enterText(find.widgetWithText(TextField, 'Número de escritura del poder'), '222');
    await tester.enterText(find.widgetWithText(TextField, 'Notario público (del poder)'), 'Lic. Ana Notaria');
    await _confirmDatePicker(tester, 'Fecha del instrumento');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo del beneficiario'), 'Beatriz Beneficiaria');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación (beneficiario)'), 'ID2');
    await tester.enterText(find.widgetWithText(TextField, '% de participación'), '80');

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Cambios guardados.'), findsOneWidget);
    // El nombre comercial capturado ahora es el nombre mostrado en el
    // encabezado del detalle y en el breadcrumb (mismo criterio que al
    // crear un Cliente).
    expect(find.text('Koons Holding'), findsNWidgets(2));

    // La corrección también se refleja en el árbol.
    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    expect(find.text('Koons Holding'), findsOneWidget);
  });

  testWidgets('Admin Cliente cannot deactivate their own company but can deactivate a filial', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.holding@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Grupo Koons Holding');
    expect(find.widgetWithText(OutlinedButton, 'Desactivar'), findsNothing);
    expect(find.text('No puedes desactivar tu propia empresa.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    // Admin Cliente: árbol expandido por defecto, no hace falta abrir el
    // nodo manualmente (a diferencia de Super Admin).
    await _goToSection(tester, 'Koons Subsidiaria A');

    expect(find.widgetWithText(OutlinedButton, 'Desactivar'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(find.text('Inactiva'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reactivar'), findsOneWidget);
  });

  testWidgets('deactivating a parent Cliente cascades to its filiales and blocks their login', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Grupo Koons Holding');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();
    expect(find.text('Inactiva'), findsOneWidget);

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    // La cascada desactivó también a la filial, aunque nunca se tocó
    // directamente.
    expect(find.text('Inactiva'), findsNWidgets(3)); // Holding + Subsidiaria A + Subsidiaria B, todas en el árbol

    // Capa 1: el staff de la filial ya no puede iniciar sesión.
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('reactivating a parent Cliente cascades to its filiales', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Grupo Koons Holding');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reactivar'));
    await tester.pumpAndSettle();
    expect(find.text('Inactiva'), findsNothing);

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    expect(find.text('Inactiva'), findsNothing);

    // El staff de la filial vuelve a poder iniciar sesión.
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    expect(find.text('Email o contraseña incorrectos.'), findsNothing);
  });

  // --- Alta y gestión de Tarjetahabientes --------------------------------

  testWidgets('Only Admin Cliente and Super Admin see the "Nuevo Tarjetahabiente" button', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'operador.subA@koons.test');

    // Operador aterriza directo en "Clientes" (no tiene "Inicio").
    await _goToSection(tester, 'Koons Subsidiaria A');

    expect(find.widgetWithText(FilledButton, 'Nuevo Tarjetahabiente'), findsNothing);
  });

  testWidgets('Admin Cliente can create a new Tarjetahabiente from a Cliente\'s tab', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await tester.tap(find.widgetWithText(FilledButton, 'Nuevo Tarjetahabiente'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo'), 'Pedro Nuevo');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación'), 'INE9999999999999');
    await tester.enterText(find.widgetWithText(TextField, 'CURP'), 'NUPE900101HDFXXX01');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear'));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro Nuevo'), findsOneWidget);
  });

  testWidgets('CURP is required only for Mexican nationality when creating a Tarjetahabiente', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');

    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await tester.tap(find.widgetWithText(FilledButton, 'Nuevo Tarjetahabiente'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nombre completo'), 'Foreign Person');
    await tester.enterText(find.widgetWithText(TextField, 'Número de identificación'), 'PASSPORT123');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CURP es obligatorio'), findsOneWidget); // Mexicana por default, sin CURP

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estadounidense').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Foreign Person'), findsOneWidget); // ahora sí se crea, sin CURP
  });

  testWidgets('assigning a card excludes an inactive Tarjetahabiente from the picker', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria B');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Carlos Ruiz');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 3002');
    await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Ruiz'), findsNothing);
    expect(find.text('Maria Gomez'), findsWidgets);
  });

  testWidgets('cannot unblock a card while its Tarjetahabiente is inactive', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Clientes');
    await _expandClientTreeNode(tester, 'Grupo Koons Holding');
    await _goToSection(tester, 'Koons Subsidiaria B');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Carlos Ruiz');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breadcrumb-0')));
    await tester.pumpAndSettle();
    await _goToSection(tester, 'Tarjetas');
    await _goToSection(tester, '**** **** **** 7890');
    expect(find.text('Bloqueada'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.textContaining('inactivo'), findsOneWidget);
    expect(find.text('Bloqueada'), findsWidgets);
  });

  testWidgets('reactivating a Tarjetahabiente does not automatically unblock the card it froze', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reactivar'));
    await tester.pumpAndSettle();

    await _goToSection(tester, '**** **** **** 1234');
    expect(find.text('Bloqueada'), findsWidgets); // sigue bloqueada pese a reactivar

    await tester.tap(find.widgetWithText(OutlinedButton, 'Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Activa'), findsWidgets); // ahora sí se puede desbloquear manualmente
  });

  testWidgets('the per-Cliente Tarjetahabientes list can filter by Estado', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'admin.subA@koons.test');
    await _goToSection(tester, 'Clientes');
    await _goToSection(tester, 'Koons Subsidiaria A');
    await _goToClientTab(tester, 'Tarjetahabientes');
    await _goToSection(tester, 'Juan Perez');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('breadcrumb-1')));
    await tester.pumpAndSettle();
    await _goToClientTab(tester, 'Tarjetahabientes');

    await _toggleFilterOption(tester, 'Estado', 'Inactivo');
    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('Ana Torres'), findsNothing);
  });

  testWidgets('the global Tarjetahabientes list can filter by PEP', (tester) async {
    await tester.pumpWidget(const KbmAdminApp());
    await tester.pumpAndSettle();
    await _login(tester, 'super.admin@koons.test');

    await _goToSection(tester, 'Tarjetahabientes');
    await _toggleFilterOption(tester, 'PEP', 'Sí');

    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('Juan Perez'), findsNothing);
  });
}
