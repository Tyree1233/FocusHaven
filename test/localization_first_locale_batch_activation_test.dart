import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/main.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('both reviewed batch catalogs are exact and production active', () {
    _expectReviewedRuntime(
      locale: 'de',
      arbLocale: 'de',
      accepted: 623,
      revised: 357,
      sourceEqualCount: 9,
    );
    _expectReviewedRuntime(
      locale: 'pt-BR',
      arbLocale: 'pt_BR',
      accepted: 735,
      revised: 245,
      sourceEqualCount: 6,
    );

    expect(FocusHavenLocales.productionLocales, contains(const Locale('de')));
    expect(
      FocusHavenLocales.productionLocales,
      contains(const Locale('pt', 'BR')),
    );
    expect(AppLocalizations.supportedLocales, contains(const Locale('de')));
    expect(
      AppLocalizations.supportedLocales,
      contains(const Locale('pt', 'BR')),
    );
    expect(AppLocalizations.supportedLocales, contains(const Locale('pt')));
    _expectBrazilianPortugueseFallback();
    expect(FocusHavenLocales.integrationLocales, isEmpty);
  });

  testWidgets('device German and explicit German preference render in German', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const FocusHavenApp());
    await tester.pumpAndSettle();
    expect(find.text('Willkommen bei FocusHaven'), findsOneWidget);
    expect(find.text('Fokus starten'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final german = FocusHavenLocales.production.singleWhere(
      (definition) => definition.languageTag == 'de',
    );
    final localeService = LocaleService();
    await localeService.initialized;
    await localeService.setLanguage(
      FocusHavenLanguageChoice.forDefinition(german),
    );
    expect(localeService.selectedLocale, const Locale('de'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleService.storageKey), 'de');
  });

  testWidgets(
    'device Brazilian Portuguese and explicit preference render in Portuguese',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('pt', 'BR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('pt', 'BR'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const FocusHavenApp());
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo ao FocusHaven'), findsOneWidget);
      expect(find.text('Comece o foco'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final portuguese = FocusHavenLocales.production.singleWhere(
        (definition) => definition.languageTag == 'pt-BR',
      );
      final localeService = LocaleService();
      await localeService.initialized;
      await localeService.setLanguage(
        FocusHavenLanguageChoice.forDefinition(portuguese),
      );
      expect(localeService.selectedLocale, const Locale('pt', 'BR'));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(LocaleService.storageKey), 'pt-BR');
    },
  );

  test('batch activation keeps exceptional and store gates closed', () {
    for (final locale in ['de', 'pt-BR']) {
      final plan = _json('localization/plans/$locale.json');
      expect(
        (plan['exceptionalGates'] as Map<String, dynamic>).values,
        everyElement(isFalse),
      );
    }

    final voice = File(
      'lib/services/voice_transcription_service.dart',
    ).readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md',
    ).readAsStringSync();
    expect(voice, contains("supportedLocaleIds = <String>{'en', 'es'}"));
    expect(policy, contains('store promotion remains separate'));
  });
}

void _expectReviewedRuntime({
  required String locale,
  required String arbLocale,
  required int accepted,
  required int revised,
  required int sourceEqualCount,
}) {
  final plan = _json('localization/plans/$locale.json');
  final validation = _json(
    'localization/reviews/$locale/private-human-validation.json',
  );
  final approved = File(
    'localization/reviews/$locale/app_$arbLocale.approved.arb',
  ).readAsBytesSync();
  final runtime = File('lib/l10n/app_$arbLocale.arb').readAsBytesSync();

  expect(runtime, orderedEquals(approved));
  expect(plan['runtimeCatalog'], 'lib/l10n/app_$arbLocale.arb');
  expect(plan['exceptionalGates'], {
    'rightToLeft': false,
    'fontCoverage': false,
    'physicalScreenReader': false,
    'physicalSpeechRecognition': false,
    'storePromotion': false,
  });
  expect(validation['messageCount'], 980);
  expect(validation['decisionCounts'], {
    'accepted': accepted,
    'revised': revised,
    'blocked': 0,
  });
  expect(validation['personalDataIncluded'], isFalse);
  expect(validation['runtimeActivated'], isFalse);
  expect(validation['reviewApprovedSourceEqual'], hasLength(sourceEqualCount));

  final definition = FocusHavenLocales.production.singleWhere(
    (candidate) => candidate.languageTag == locale,
  );
  expect(definition.status, FocusHavenLocaleStatus.production);
}

void _expectBrazilianPortugueseFallback() {
  final brazilian = _json('lib/l10n/app_pt_BR.arb');
  final fallback = _json('lib/l10n/app_pt.arb');

  expect(brazilian.remove('@@locale'), 'pt_BR');
  expect(fallback.remove('@@locale'), 'pt');
  expect(fallback, brazilian);
  expect(
    FocusHavenLocales.production.map((definition) => definition.languageTag),
    contains('pt-BR'),
  );
  expect(
    FocusHavenLocales.production.map((definition) => definition.languageTag),
    isNot(contains('pt')),
  );
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
