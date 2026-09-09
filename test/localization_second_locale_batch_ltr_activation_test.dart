import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/main.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/localization_catalog_prefix.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Italian, Polish, and Dutch reviewed bases remain exact', () {
    _expectReviewedRuntime(
      locale: 'it',
      accepted: 596,
      revised: 384,
      sourceEqualCount: 7,
      catalogSha:
          '1426c4a8e9d9fb1acf973a5d822cb09fe32afd45ad31187aa7950838ca324605',
    );
    _expectReviewedRuntime(
      locale: 'pl',
      accepted: 620,
      revised: 360,
      sourceEqualCount: 4,
      catalogSha:
          '882b6204d7f2aa0f95f27e488e1f535193e67317e95d6db140e6763fb3bfbf37',
    );
    _expectReviewedRuntime(
      locale: 'nl',
      accepted: 753,
      revised: 227,
      sourceEqualCount: 5,
      catalogSha:
          '15568a1035d399f934bf8aeebbaafccff77e8c62271afaddfad997b4e99f5d6f',
    );

    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[Locale('it'), Locale('pl'), Locale('nl')]),
    );
    expect(AppLocalizations.supportedLocales, contains(const Locale('it')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('pl')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('nl')));
  });

  for (final localeCase
      in <({Locale locale, String tag, String title, String beginFocus})>[
        (
          locale: Locale('it'),
          tag: 'it',
          title: 'Benvenuto su FocusHaven',
          beginFocus: 'Inizia il focus',
        ),
        (
          locale: Locale('pl'),
          tag: 'pl',
          title: 'Witamy w FocusHaven',
          beginFocus: 'Rozpocznij skupienie',
        ),
        (
          locale: Locale('nl'),
          tag: 'nl',
          title: 'Welkom bij FocusHaven',
          beginFocus: 'Focus beginnen',
        ),
      ]) {
    testWidgets(
      '${localeCase.tag} device locale and explicit preference use the reviewed catalog',
      (tester) async {
        tester.platformDispatcher.localeTestValue = localeCase.locale;
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        tester.platformDispatcher.localesTestValue = <Locale>[
          localeCase.locale,
        ];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(const FocusHavenApp());
        await tester.pumpAndSettle();
        expect(find.text(localeCase.title), findsOneWidget);
        expect(find.text(localeCase.beginFocus), findsOneWidget);
        expect(tester.takeException(), isNull);

        final definition = FocusHavenLocales.production.singleWhere(
          (candidate) => candidate.languageTag == localeCase.tag,
        );
        final localeService = LocaleService();
        await localeService.initialized;
        await localeService.setLanguage(
          FocusHavenLanguageChoice.forDefinition(definition),
        );
        expect(localeService.selectedLocale, localeCase.locale);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(LocaleService.storageKey), localeCase.tag);
      },
    );
  }

  test('Latin-script activation keeps optional features closed', () {
    for (final locale in ['it', 'pl', 'nl']) {
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
    expect(policy, contains('Italian, Polish, and Dutch'));
    expect(policy, contains('Speech recognition'));
    expect(policy, contains('store promotion'));
    expect(policy, contains('country distribution'));
  });
}

void _expectReviewedRuntime({
  required String locale,
  required int accepted,
  required int revised,
  required int sourceEqualCount,
  required String catalogSha,
}) {
  final plan = _json('localization/plans/$locale.json');
  final validation = _json(
    'localization/reviews/$locale/private-human-validation.json',
  );
  final approved = File(
    'localization/reviews/$locale/app_$locale.approved.arb',
  ).readAsBytesSync();
  final runtime = catalogBytesBeforeAdaptiveFocus('lib/l10n/app_$locale.arb');

  expect(runtime, orderedEquals(approved));
  expect(plan['runtimeCatalog'], 'lib/l10n/app_$locale.arb');
  expect(plan['exceptionalGates'], {
    'rightToLeft': false,
    'fontCoverage': false,
    'physicalScreenReader': false,
    'physicalSpeechRecognition': false,
    'storePromotion': false,
  });
  expect(validation['approvedCatalogSha256'], catalogSha);
  expect(validation['messageCount'], 980);
  expect(validation['decisionCounts'], {
    'accepted': accepted,
    'revised': revised,
    'blocked': 0,
  });
  expect(validation['contentSafetyIssueCount'], 0);
  expect(validation['placeholderMismatchCount'], 0);
  expect(validation['sourceMutationCount'], 0);
  expect(validation['personalDataIncluded'], isFalse);
  expect(validation['runtimeActivated'], isFalse);
  expect(validation['reviewApprovedSourceEqual'], hasLength(sourceEqualCount));

  final definition = FocusHavenLocales.production.singleWhere(
    (candidate) => candidate.languageTag == locale,
  );
  expect(definition.status, FocusHavenLocaleStatus.production);
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
