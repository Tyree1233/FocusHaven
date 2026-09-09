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

  test('Japanese and Korean physical CJK records remain exact', () {
    _expectPhysicalAcceptance(
      locale: 'ja',
      catalogSha:
          '27eab8db2974e3be9f3603cc9d7f874914fe4a7aad3dec72d00ebc6cf842a3e8',
      androidArtifactSha:
          'e1c11c66bf18a7df63cccec17bb1885fdf231eedd9fcfc20fb94bba331e97eb0',
      iosManifestSha:
          '174b204302e6dfcc637f3637b0d74f49ddd74b8ebb14ae396c3987aafa987263',
    );
    _expectPhysicalAcceptance(
      locale: 'ko',
      catalogSha:
          'd1d7651493465c83f0d51c0a394c0e4629e91b5c11ae595ad1b7ffd9a7f19302',
      androidArtifactSha:
          '4995707f3edf2515b0ef5d41da3348ee4ddc4081f6d53b53390e1ec1c3310f9a',
      iosManifestSha:
          '60e4302cf1668043752d09d70d91f3639915fddba3d230b9381c0a3c28ec0a60',
    );

    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[Locale('ja'), Locale('ko')]),
    );
    expect(AppLocalizations.supportedLocales, contains(const Locale('ja')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
  });

  for (final localeCase
      in <({Locale locale, String tag, String title, String beginFocus})>[
        (
          locale: Locale('ja'),
          tag: 'ja',
          title: 'FocusHavenへようこそ',
          beginFocus: 'フォーカスを始めましょう',
        ),
        (
          locale: Locale('ko'),
          tag: 'ko',
          title: 'FocusHaven에 오신 것을 환영합니다',
          beginFocus: '시작 초점',
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

  test('CJK activation keeps unqualified optional features closed', () {
    final voice = File(
      'lib/services/voice_transcription_service.dart',
    ).readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(voice, contains("supportedLocaleIds = <String>{'en', 'es'}"));
    expect(policy, contains('Japanese and Korean'));
    expect(policy, contains('speech recognition remains fail-closed'));
    expect(policy, contains('store and country promotion remain separate'));
    expect(pubspec, isNot(contains('\n  fonts:')));
  });
}

void _expectPhysicalAcceptance({
  required String locale,
  required String catalogSha,
  required String androidArtifactSha,
  required String iosManifestSha,
}) {
  final plan = _json('localization/plans/$locale.json');
  final validation = _json(
    'localization/reviews/$locale/private-human-validation.json',
  );
  final physical = _json(
    'localization/reviews/$locale/physical-cjk-coverage.json',
  );
  final approved = File(
    'localization/reviews/$locale/app_$locale.approved.arb',
  ).readAsBytesSync();
  final runtime = catalogBytesBeforeAdaptiveFocus('lib/l10n/app_$locale.arb');

  expect(runtime, orderedEquals(approved));
  expect(validation['approvedCatalogSha256'], catalogSha);
  expect(validation['contentSafetyIssueCount'], 0);
  expect(validation['personalDataIncluded'], isFalse);
  expect(plan['exceptionalGates'], {
    'rightToLeft': false,
    'fontCoverage': true,
    'physicalScreenReader': false,
    'physicalSpeechRecognition': false,
    'storePromotion': false,
  });
  expect(physical['status'], 'physical_font_coverage_complete');
  expect(physical['reviewedCatalogSha256'], catalogSha);
  expect(physical['physicalFontCoverageQualified'], isTrue);
  expect(physical['runtimeActivatedByThisChange'], isTrue);
  expect(physical['physicalScreenReaderQualified'], isFalse);
  expect(physical['physicalSpeechRecognitionQualified'], isFalse);
  expect(physical['storePromotionQualified'], isFalse);
  expect(physical['personalDataIncluded'], isFalse);

  final android = physical['android'] as Map<String, dynamic>;
  expect(android['result'], 'PASS');
  expect(android['artifactSha256'], androidArtifactSha);
  expect(android['normalRestorationResult'], 'PASS');

  final ios = physical['ios'] as Map<String, dynamic>;
  expect(ios['result'], 'PASS');
  expect(ios['buildMode'], 'profile');
  expect(ios['artifactManifestSha256'], iosManifestSha);
  expect(ios['normalRestorationResult'], 'PASS');

  final correction =
      physical['profileEntrypointCorrection'] as Map<String, dynamic>;
  expect(correction['translationChanged'], isFalse);
  expect(correction['androidDebugBehaviorChanged'], isFalse);
  expect(correction['releaseBuildRemainsFailClosed'], isTrue);

  final definition = FocusHavenLocales.production.singleWhere(
    (candidate) => candidate.languageTag == locale,
  );
  expect(definition.status, FocusHavenLocaleStatus.production);
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
