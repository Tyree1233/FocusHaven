import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reviewed CJK catalogs are exact production runtime copies', () {
    _expectReviewedRuntime(
      locale: 'ja',
      accepted: 647,
      revised: 333,
      sourceEqualCount: 2,
    );
    _expectReviewedRuntime(
      locale: 'ko',
      accepted: 603,
      revised: 377,
      sourceEqualCount: 8,
    );

    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(FocusHavenLocales.cjkCoverageTestLocales, const <Locale>[
      Locale('en'),
      Locale('ja'),
      Locale('ko'),
    ]);
    expect(AppLocalizations.supportedLocales, contains(const Locale('ja')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[Locale('ja'), Locale('ko')]),
    );
  });

  test('Japanese and Korean text has clean Unicode and expected scripts', () {
    final japanese = _messageText('lib/l10n/app_ja.arb');
    final korean = _messageText('lib/l10n/app_ko.arb');

    for (final text in <String>[japanese, korean]) {
      expect(text.runes, isNot(contains(0xfffd)));
      expect(text.runes.where(_isForbiddenControl), isEmpty);
      expect(text.runes.where(_isPrivateUse), isEmpty);
      expect(text.runes.where(_isBidiOverride), isEmpty);
    }

    expect(japanese.runes.any(_isHiragana), isTrue);
    expect(japanese.runes.any(_isKatakana), isTrue);
    expect(japanese.runes.any(_isHan), isTrue);
    expect(japanese.runes.any(_isHangul), isFalse);

    expect(korean.runes.any(_isHangul), isTrue);
    expect(korean.runes.any(_isHiragana), isFalse);
    expect(korean.runes.any(_isKatakana), isFalse);
  });

  for (final localeCase in <({Locale locale, String title, String beginFocus})>[
    (
      locale: Locale('ja'),
      title: 'FocusHavenへようこそ',
      beginFocus: 'フォーカスを始めましょう',
    ),
    (
      locale: Locale('ko'),
      title: 'FocusHaven에 오신 것을 환영합니다',
      beginFocus: '시작 초점',
    ),
  ]) {
    testWidgets(
      '${localeCase.locale.languageCode} uses system fallback and wraps on a narrow large-text phone',
      (tester) async {
        _useNarrowPhone(tester);

        await tester.pumpWidget(
          FocusHavenApp(
            locale: localeCase.locale,
            supportedLocales: FocusHavenLocales.cjkCoverageTestLocales,
          ),
        );
        await tester.pumpAndSettle();

        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.locale, localeCase.locale);
        expect(find.text(localeCase.title), findsOneWidget);
        expect(find.text(localeCase.beginFocus), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('CJK entry point is non-release, explicit, and fail-closed', () {
    final entryPoint = File('lib/main_cjk_integration.dart').readAsStringSync();
    final productionMain = File('lib/main.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(entryPoint, contains("'FOCUSHAVEN_CJK_COVERAGE_TEST'"));
    expect(entryPoint, contains("'FOCUSHAVEN_CJK_LOCALE'"));
    expect(entryPoint, contains("<String>{'ja', 'ko'}"));
    expect(entryPoint, contains('if (kReleaseMode ||'));
    expect(
      entryPoint,
      contains('supportedLocales: FocusHavenLocales.cjkCoverageTestLocales'),
    );
    expect(
      productionMain,
      contains('supportedLocales: FocusHavenLocales.productionLocales'),
    );
    expect(productionMain, isNot(contains('fontFamily:')));
    expect(productionMain, isNot(contains('fontFamilyFallback:')));
    expect(pubspec, isNot(contains('\n  fonts:')));
  });
}

void _expectReviewedRuntime({
  required String locale,
  required int accepted,
  required int revised,
  required int sourceEqualCount,
}) {
  final plan = _json('localization/plans/$locale.json');
  final validation = _json(
    'localization/reviews/$locale/private-human-validation.json',
  );
  final approved = File(
    'localization/reviews/$locale/app_$locale.approved.arb',
  ).readAsBytesSync();
  final runtime = File('lib/l10n/app_$locale.arb').readAsBytesSync();

  expect(runtime, orderedEquals(approved));
  expect(plan['runtimeCatalog'], 'lib/l10n/app_$locale.arb');
  expect(plan['exceptionalGates'], {
    'rightToLeft': false,
    'fontCoverage': true,
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
  expect(validation['contentSafetyIssueCount'], 0);
  expect(validation['placeholderMismatchCount'], 0);
  expect(validation['sourceMutationCount'], 0);
  expect(validation['personalDataIncluded'], isFalse);
  expect(validation['runtimeActivated'], isFalse);
  expect(validation['reviewApprovedSourceEqual'], hasLength(sourceEqualCount));
}

String _messageText(String path) {
  final catalog = _json(path);
  return catalog.entries
      .where((entry) => !entry.key.startsWith('@') && entry.value is String)
      .map((entry) => entry.value as String)
      .join('\n');
}

bool _isForbiddenControl(int rune) =>
    (rune >= 0 && rune <= 8) ||
    rune == 11 ||
    rune == 12 ||
    (rune >= 14 && rune <= 31) ||
    (rune >= 127 && rune <= 159);

bool _isPrivateUse(int rune) =>
    (rune >= 0xe000 && rune <= 0xf8ff) ||
    (rune >= 0xf0000 && rune <= 0xffffd) ||
    (rune >= 0x100000 && rune <= 0x10fffd);

bool _isBidiOverride(int rune) =>
    (rune >= 0x202a && rune <= 0x202e) || (rune >= 0x2066 && rune <= 0x2069);

bool _isHiragana(int rune) => rune >= 0x3040 && rune <= 0x309f;
bool _isKatakana(int rune) => rune >= 0x30a0 && rune <= 0x30ff;
bool _isHan(int rune) => rune >= 0x4e00 && rune <= 0x9fff;
bool _isHangul(int rune) => rune >= 0xac00 && rune <= 0xd7a3;

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void _useNarrowPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
