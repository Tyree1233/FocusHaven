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

  test('six independently reviewed bases remain exact after activation', () {
    _expectReviewedRuntime(
      locale: 'id',
      accepted: 881,
      revised: 99,
      sourceEqualCount: 4,
      catalogSha:
          'df81de979339eac0ef515b946afdf2eb69e23e22c02309f6b7d2865b7b6367f2',
    );
    _expectReviewedRuntime(
      locale: 'tr',
      accepted: 832,
      revised: 148,
      sourceEqualCount: 4,
      catalogSha:
          '52faf4bd6af5afe9df40796682f8ea4f3642adb58a24daa7412a3ad6cfae02bd',
    );
    _expectReviewedRuntime(
      locale: 'sv',
      accepted: 901,
      revised: 79,
      sourceEqualCount: 2,
      catalogSha:
          'b1980634d25bd576116b339bdffd7d0f97f7e0368e066e23366a731c67076e39',
    );
    _expectReviewedRuntime(
      locale: 'nb',
      accepted: 865,
      revised: 115,
      sourceEqualCount: 6,
      catalogSha:
          '9ffc4be4da5057fbeebbc8b16c891e9589af066ee490686638ffe389817df789',
    );
    _expectReviewedRuntime(
      locale: 'da',
      accepted: 870,
      revised: 110,
      sourceEqualCount: 6,
      catalogSha:
          'd7ec3d67c9a438322828a533d68809f57cdcbcac86d7e266f2562fe39e6cd5c8',
    );
    _expectReviewedRuntime(
      locale: 'fi',
      accepted: 835,
      revised: 145,
      sourceEqualCount: 4,
      catalogSha:
          'd5c4e4c7d781954c45fa4d5d8493cca2bdbdf04738ec898ce26455bb520e3113',
    );

    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[
        Locale('id'),
        Locale('tr'),
        Locale('sv'),
        Locale('nb'),
        Locale('da'),
        Locale('fi'),
      ]),
    );
    for (final locale in const <Locale>[
      Locale('id'),
      Locale('tr'),
      Locale('sv'),
      Locale('nb'),
      Locale('da'),
      Locale('fi'),
    ]) {
      expect(AppLocalizations.supportedLocales, contains(locale));
    }
  });

  for (final localeCase
      in <({Locale locale, String tag, String title, String beginFocus})>[
        (
          locale: Locale('id'),
          tag: 'id',
          title: 'Selamat datang di FocusHaven',
          beginFocus: 'Mulai fokus',
        ),
        (
          locale: Locale('tr'),
          tag: 'tr',
          title: "FocusHaven'a hoş geldiniz.",
          beginFocus: 'Odaklanmaya başlayın',
        ),
        (
          locale: Locale('sv'),
          tag: 'sv',
          title: 'Välkommen till FocusHaven',
          beginFocus: 'Börja fokus',
        ),
        (
          locale: Locale('nb'),
          tag: 'nb',
          title: 'Velkommen til FocusHaven',
          beginFocus: 'Begynn fokus',
        ),
        (
          locale: Locale('da'),
          tag: 'da',
          title: 'Velkommen til FocusHaven',
          beginFocus: 'Begynd fokus',
        ),
        (
          locale: Locale('fi'),
          tag: 'fi',
          title: 'Tervetuloa FocusHaveniin',
          beginFocus: 'Aloita keskittyminen',
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

  test('six-language activation keeps every optional feature gate closed', () {
    for (final locale in ['id', 'tr', 'sv', 'nb', 'da', 'fi']) {
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
    expect(
      policy,
      contains(
        'Indonesian, Turkish, Swedish, Norwegian Bokmål, Danish, and Finnish',
      ),
    );
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
