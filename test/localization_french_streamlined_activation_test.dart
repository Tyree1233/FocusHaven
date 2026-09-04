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

  test(
    'reviewed French catalog is integrated exactly and production active',
    () {
      final plan = _json('localization/plans/fr.json');
      final validation = _json(
        'localization/reviews/fr/private-human-validation.json',
      );
      final approved = File(
        'localization/reviews/fr/app_fr.approved.arb',
      ).readAsBytesSync();
      final runtime = File('lib/l10n/app_fr.arb').readAsBytesSync();

      expect(runtime, orderedEquals(approved));
      expect(plan['runtimeCatalog'], 'lib/l10n/app_fr.arb');
      expect(plan['exceptionalGates'], {
        'rightToLeft': false,
        'fontCoverage': false,
        'physicalScreenReader': false,
        'physicalSpeechRecognition': false,
        'storePromotion': false,
      });
      expect(validation['messageCount'], 980);
      expect(validation['decisionCounts'], {
        'accepted': 654,
        'revised': 326,
        'blocked': 0,
      });
      expect(validation['personalDataIncluded'], isFalse);
      expect(validation['runtimeActivated'], isFalse);
      expect(validation['reviewApprovedSourceEqual'], hasLength(8));

      final french = FocusHavenLocales.production.singleWhere(
        (definition) => definition.languageCode == 'fr',
      );
      expect(french.nativeName, 'Français');
      expect(french.status, FocusHavenLocaleStatus.production);
      expect(FocusHavenLocales.productionLocales, contains(const Locale('fr')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('fr')));
      expect(FocusHavenLocales.integrationLocales, isEmpty);
    },
  );

  testWidgets('device French and explicit French preference render in French', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('fr');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const FocusHavenApp());
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue à FocusHaven'), findsOneWidget);
    expect(find.text('Commencer le focus'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final french = FocusHavenLocales.production.singleWhere(
      (definition) => definition.languageCode == 'fr',
    );
    final localeService = LocaleService();
    await localeService.initialized;
    await localeService.setLanguage(
      FocusHavenLanguageChoice.forDefinition(french),
    );
    expect(localeService.selectedLocale, const Locale('fr'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleService.storageKey), 'fr');
  });

  test('French activation leaves optional and public release gates closed', () {
    final plan = _json('localization/plans/fr.json');
    final roadmap = File('docs/PRODUCT_ROADMAP.md').readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md',
    ).readAsStringSync();

    expect(
      (plan['exceptionalGates'] as Map<String, dynamic>).values,
      everyElement(isFalse),
    );
    expect(roadmap, contains('German and Brazilian Portuguese remain planned'));
    expect(policy, contains('In-app locale support and localized'));
    expect(policy, contains('store promotion are separate decisions'));
  });
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
