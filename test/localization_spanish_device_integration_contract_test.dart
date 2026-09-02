import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('production app remains English-only by default', (tester) async {
    await tester.pumpWidget(const FocusHavenApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull);
    expect(app.supportedLocales, FocusHavenLocales.productionLocales);
    expect(app.supportedLocales, const <Locale>[Locale('en')]);
    expect(find.text('Welcome to FocusHaven'), findsOneWidget);
    expect(find.text('Te damos la bienvenida a FocusHaven'), findsNothing);
  });

  testWidgets('explicit device harness renders the reviewed Spanish app', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FocusHavenApp(
        locale: Locale('es'),
        supportedLocales: FocusHavenLocales.spanishDeviceTestLocales,
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('es'));
    expect(app.supportedLocales, const <Locale>[Locale('en'), Locale('es')]);
    expect(find.text('Te damos la bienvenida a FocusHaven'), findsOneWidget);
    expect(find.text('Welcome to FocusHaven'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('device entry point is explicit, debug-only, and fail-closed', () {
    final productionMain = File('lib/main.dart').readAsStringSync();
    final deviceMain = File(
      'lib/main_spanish_integration.dart',
    ).readAsStringSync();
    final registry = File(
      'lib/l10n/focus_haven_locales.dart',
    ).readAsStringSync();
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(
      productionMain,
      contains('supportedLocales: FocusHavenLocales.productionLocales'),
    );
    expect(deviceMain, contains("'FOCUSHAVEN_SPANISH_DEVICE_TEST'"));
    expect(
      deviceMain,
      contains('if (!kDebugMode || !_spanishDeviceTestAuthorized)'),
    );
    expect(deviceMain, contains("locale: const Locale('es')"));
    expect(
      deviceMain,
      contains('supportedLocales: FocusHavenLocales.spanishDeviceTestLocales'),
    );
    expect(
      registry,
      contains('static const productionLocales = <Locale>[Locale(\'en\')]'),
    );
    expect(FocusHavenLocales.productionLocales, const <Locale>[Locale('en')]);
    expect(FocusHavenLocales.spanishDeviceTestLocales, const <Locale>[
      Locale('en'),
      Locale('es'),
    ]);
    expect(qualification['deviceIntegrationPreparationPhase'], '215G-C3E');
    expect(
      qualification['deviceIntegrationPreparationStatus'],
      'debug_target_verified_pending_physical_acceptance',
    );
    expect(qualification['screenReaderPhysicalAcceptancePassed'], isFalse);
    expect(qualification['runtimeActivated'], isFalse);
    expect(qualification['productionLocaleAllowed'], isFalse);
  });
}
