import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/main.dart';
import 'package:focushaven/screens/onboarding_screen.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reviewed Spanish catalog is exact and production active', () {
    const digest =
        '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f';
    final integration = File('lib/l10n/app_es.arb');
    final candidate = File('localization/candidates/app_es.arb');
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(integration.existsSync(), isTrue);
    expect(integration.readAsBytesSync(), candidate.readAsBytesSync());
    expect(_sha256(integration.path), digest);
    expect(qualification['runtimeIntegrationPhase'], '215G-C3A');
    expect(qualification['runtimeIntegrationStatus'], 'production_active');
    expect(qualification['runtimeCatalogSha256'], digest);
    expect(qualification['generatedDelegateAvailable'], isTrue);
    expect(qualification['productionLocaleAllowed'], isTrue);
    expect(qualification['runtimeActivated'], isTrue);

    expect(
      AppLocalizations.supportedLocales,
      containsAll(const <Locale>[Locale('en'), Locale('es')]),
    );
    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[Locale('en'), Locale('es')]),
    );
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.production,
    );
  });

  testWidgets('explicit integration harness renders reviewed Spanish and ICU', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final strings = AppLocalizations.of(context);
            return Scaffold(
              body: Column(
                children: [
                  Text(strings.onboardingTitle),
                  Text(strings.onboardingSubtitle),
                  Text(strings.onboardingBeginFocus),
                  Text(strings.durationMinutes(1)),
                  Text(strings.durationMinutes(5)),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Te damos la bienvenida a FocusHaven'), findsOneWidget);
    expect(
      find.text(
        'Un lugar tranquilo para concentrarte, recargar energías y mantener la atención plena.',
      ),
      findsOneWidget,
    );
    expect(find.text('Comenzar enfoque'), findsOneWidget);
    expect(find.text('1 minuto'), findsOneWidget);
    expect(find.text('5 minutos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production app follows a supported Spanish device locale', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('es');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final localeService = LocaleService();
    await localeService.initialized;

    await tester.pumpWidget(FocusHavenApp(localeService: localeService));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.supportedLocales,
      containsAll(const <Locale>[Locale('en'), Locale('es')]),
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to FocusHaven'), findsNothing);
    expect(find.text('Te damos la bienvenida a FocusHaven'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}
