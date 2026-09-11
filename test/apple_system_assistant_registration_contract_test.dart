import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const reviewedCatalogPath =
      'ios/Runner/AppleSystemAssistantNativeCopy.xcstrings';
  const appIntentsPath = 'ios/Runner/HavenSystemAssistantAppleAppIntents.swift';
  const phraseKeys = <String>[
    'appleSystemAssistantNativeReadTimerStatusPhrase',
    'appleSystemAssistantNativeStartFocusTimerPhrase',
    'appleSystemAssistantNativePauseTimerPhrase',
    'appleSystemAssistantNativeResumeTimerPhrase',
    'appleSystemAssistantNativeOpenFocusQueuePhrase',
  ];
  const registeredCopyKeys = <String>[
    'appleSystemAssistantNativeReadTimerStatusTitle',
    'appleSystemAssistantNativeReadTimerStatusDescription',
    'appleSystemAssistantNativeStartFocusTimerTitle',
    'appleSystemAssistantNativeStartFocusTimerDescription',
    'appleSystemAssistantNativePauseTimerTitle',
    'appleSystemAssistantNativePauseTimerDescription',
    'appleSystemAssistantNativeResumeTimerTitle',
    'appleSystemAssistantNativeResumeTimerDescription',
    'appleSystemAssistantNativeOpenFocusQueueTitle',
    'appleSystemAssistantNativeOpenFocusQueueDescription',
    'appleSystemAssistantNativeReviewRequiredResult',
    'appleSystemAssistantNativePendingRequestResult',
    'appleSystemAssistantNativeUnavailableResult',
  ];
  const expectedLocales = <String>{
    'en',
    'es',
    'fr',
    'de',
    'pt-BR',
    'pt',
    'ja',
    'ko',
    'it',
    'pl',
    'nl',
    'id',
    'tr',
    'sv',
    'nb',
    'da',
    'fi',
  };

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  String escapeStringsValue(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');

  test('shortcut phrases are derived exactly from reviewed native copy', () {
    final reviewed = readJson(reviewedCatalogPath);
    final reviewedStrings = reviewed['strings'] as Map<String, dynamic>;
    final expectedPaths = <String>{
      for (final locale in expectedLocales)
        'ios/Runner/$locale.lproj/AppShortcuts.strings',
    };
    final actualPaths = Directory('ios/Runner')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('/AppShortcuts.strings'))
        .map((file) => file.path)
        .toSet();

    expect(File('ios/Runner/AppShortcuts.xcstrings').existsSync(), isFalse);
    expect(actualPaths, expectedPaths);
    for (final locale in expectedLocales) {
      final expected = StringBuffer(
        '/* Generated from the reviewed Phase 217F Apple-native phrase '
        'catalog. Do not edit. */\n\n',
      );
      for (final phraseKey in phraseKeys) {
        final sourceLocalizations =
            (reviewedStrings[phraseKey]
                    as Map<String, dynamic>)['localizations']
                as Map<String, dynamic>;
        expect(sourceLocalizations.keys.toSet(), expectedLocales);
        final english =
            (sourceLocalizations['en'] as Map<String, dynamic>)['stringUnit']
                as Map<String, dynamic>;
        final sourceUnit =
            (sourceLocalizations[locale] as Map<String, dynamic>)['stringUnit']
                as Map<String, dynamic>;
        expect(sourceUnit['state'], 'translated', reason: '$locale:$phraseKey');
        final sourcePhrase = (english['value'] as String).replaceAll(
          '%@',
          r'${applicationName}',
        );
        final localizedPhrase = (sourceUnit['value'] as String).replaceAll(
          '%@',
          r'${applicationName}',
        );
        expect(
          RegExp(r'\$\{applicationName\}').allMatches(localizedPhrase),
          hasLength(1),
          reason: '$locale:$phraseKey',
        );
        expected
          ..write('"${escapeStringsValue(sourcePhrase)}" = "')
          ..write(escapeStringsValue(localizedPhrase))
          ..writeln('";');
      }
      expect(
        File(
          'ios/Runner/$locale.lproj/AppShortcuts.strings',
        ).readAsStringSync(),
        expected.toString(),
        reason: locale,
      );
    }
  });

  test('registration contains exactly five parameter-free review routes', () {
    final source = File(appIntentsPath).readAsStringSync();
    final reviewedStrings =
        readJson(reviewedCatalogPath)['strings'] as Map<String, dynamic>;

    expect(
      RegExp(r'struct Haven\w+AppIntent: AppIntent').allMatches(source),
      hasLength(5),
    );
    expect(RegExp(r'AppShortcut\(').allMatches(source), hasLength(5));
    expect(
      RegExp(r'shortTitle: LocalizedStringResource\(').allMatches(source),
      hasLength(5),
    );
    expect(
      source,
      isNot(matches(RegExp(r'shortTitle: Haven\w+AppIntent\.title'))),
    );
    expect(source, contains('struct HavenSystemAssistantAppleShortcuts: '));
    expect(source, contains('AppShortcutsProvider'));
    expect(source, contains('static let openAppWhenRun = true'));
    expect(
      RegExp(r'static let openAppWhenRun = true').allMatches(source),
      hasLength(5),
    );
    expect(
      RegExp(r'\.requiresAuthentication').allMatches(source),
      hasLength(5),
    );
    expect(source, isNot(contains('@Parameter')));
    expect(source, isNot(contains('IntentParameter')));
    expect(source, isNot(contains('transcript')));
    expect(source, isNot(contains('utterance')));
    expect(source, isNot(contains('duration')));
    expect(source, isNot(contains('taskTitle')));
    for (final key in registeredCopyKeys) {
      final localizations =
          (reviewedStrings[key] as Map<String, dynamic>)['localizations']
              as Map<String, dynamic>;
      final english =
          (localizations['en'] as Map<String, dynamic>)['stringUnit']
              as Map<String, dynamic>;
      expect(source, contains('"$key"'), reason: key);
      expect(source, contains('"${english['value']}"'), reason: key);
    }
  });

  test(
    'native submission stops at the existing single-slot review ingress',
    () {
      final source = File(appIntentsPath).readAsStringSync();

      expect(source, contains('HavenSystemAssistantApplePendingRequestStore'));
      expect(source, contains('(store ?? .shared).submit('));
      expect(source, contains('HavenSystemAssistantAppleRequest('));
      expect(source, contains('.readyForReview'));
      expect(source, contains('.pendingRequest'));
      expect(source, contains('.unavailable'));
      expect(source, isNot(contains('HavenActionEngine')));
      expect(source, isNot(contains('HavenSystemIntentReviewService')));
      expect(source, isNot(contains('confirm(')));
      expect(source, isNot(contains('execute(')));
      expect(source, isNot(contains('TimerService')));
      expect(source, isNot(contains('FocusQueueService')));
    },
  );

  test('registration is gated above unchanged iOS 15 app support', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(appDelegate, contains('if #available(iOS 16.0, *)'));
    expect(
      appDelegate,
      contains(
        'HavenSystemAssistantAppleAppShortcutRegistration.updateParameters()',
      ),
    );
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project),
      hasLength(6),
    );
    expect(project, contains('AppShortcuts.strings in Resources'));
    expect(project, contains('AppShortcuts.strings */ = {'));
    expect(
      RegExp(r'\.lproj/AppShortcuts\.strings').allMatches(project),
      hasLength(17),
    );
    expect(project, isNot(contains('AppShortcuts.xcstrings')));
    expect(
      project,
      contains('HavenSystemAssistantAppleAppIntents.swift in Sources'),
    );
    expect(
      project,
      contains('HavenSystemAssistantAppleAppIntentsTests.swift in Sources'),
    );
  });

  test(
    'Siri entitlement, Android registration, and Flutter copy stay closed',
    () {
      final info = File('ios/Runner/Info.plist').readAsStringSync();
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final reviewedStrings =
          readJson(reviewedCatalogPath)['strings'] as Map<String, dynamic>;
      final shortcutKeys = <String>{
        for (final phraseKey in phraseKeys)
          (((((reviewedStrings[phraseKey]
                                  as Map<String, dynamic>)['localizations']
                              as Map<String, dynamic>)['en']
                          as Map<String, dynamic>)['stringUnit']
                      as Map<String, dynamic>)['value']
                  as String)
              .replaceAll('%@', r'${applicationName}'),
      };

      expect(info, isNot(contains('INIntentsSupported')));
      expect(info, isNot(contains('NSSiriUsageDescription')));
      expect(entitlements, isNot(contains('com.apple.developer.siri')));
      expect(androidManifest, isNot(contains('actions.intent')));
      expect(
        androidManifest,
        isNot(contains('com.google.android.gms.actions')),
      );

      final flutterCatalogs = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'));
      for (final catalog in flutterCatalogs) {
        final runtimeKeys = readJson(catalog.path).keys.toSet();
        expect(
          runtimeKeys.intersection(shortcutKeys),
          isEmpty,
          reason: catalog.path,
        );
      }
    },
  );
}
