import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_apple_system_assistant_native_review.arb';
  const integrationPath =
      'localization/integrations/apple_system_assistant_native_copy_v1.json';
  const catalogPath = 'ios/Runner/AppleSystemAssistantNativeCopy.xcstrings';
  const accessorPath = 'ios/Runner/HavenSystemAssistantAppleNativeCopy.swift';
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

  Set<String> messageKeys(Map<String, dynamic> arb) => arb.keys
      .where((key) => key != '@@locale' && !key.startsWith('@'))
      .toSet();

  test('integration provenance locks the exact accepted review set', () {
    final integration = readJson(integrationPath);

    expect(integration['schemaVersion'], 1);
    expect(
      integration['workflow'],
      'focus_haven_phase217f_apple_native_copy_catalog_integration_v1',
    );
    expect(integration['deltaId'], 'apple-system-assistant-native-copy-v1');
    expect(integration['messageCount'], 28);
    expect(integration['applicationNamePlaceholderMessageCount'], 5);
    expect(
      integration['acceptanceLockSha256'],
      '1302385ae655f6c466eae74eafb2c51f4a8e44875dd410c18618b47b65d3ed9c',
    );
    expect(integration['reviewDecisionCounts'], {
      'accepted': 189,
      'revised': 231,
      'blocked': 0,
    });
    final approvedDeltaSha256 =
        integration['approvedDeltaSha256'] as Map<String, dynamic>;
    expect(approvedDeltaSha256, hasLength(15));
    expect(
      approvedDeltaSha256.keys,
      containsAll(<String>[
        'es',
        'fr',
        'de',
        'pt-BR',
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
      ]),
    );
    expect(integration['derivedFallbacks'], [
      {'reviewedLocale': 'pt-BR', 'fallbackLocale': 'pt'},
    ]);
    expect(
      (integration['catalogLocalizations'] as List<dynamic>).toSet(),
      expectedLocales,
    );
    expect(integration['catalogSha256'], _sha256(catalogPath));
    expect(integration['flutterRuntimeCatalogChanged'], isFalse);
    expect(integration['publicNativeRegistrationEnabled'], isFalse);
    expect(integration['havenActionExecutionEnabled'], isFalse);
  });

  test('catalog maps every reviewed key into all seventeen Apple locales', () {
    final proposal = readJson(proposalPath);
    final sourceKeys = messageKeys(proposal);
    final catalog = readJson(catalogPath);
    final strings = catalog['strings'] as Map<String, dynamic>;

    expect(catalog['sourceLanguage'], 'en');
    expect(catalog['version'], '1.0');
    expect(sourceKeys, hasLength(28));
    expect(strings.keys.toSet(), sourceKeys);

    for (final key in sourceKeys) {
      final entry = strings[key] as Map<String, dynamic>;
      final localizations = entry['localizations'] as Map<String, dynamic>;
      expect(entry['extractionState'], 'manual', reason: key);
      expect(entry['comment'], isNotEmpty, reason: key);
      expect(localizations.keys.toSet(), expectedLocales, reason: key);

      for (final locale in expectedLocales) {
        final localization = localizations[locale] as Map<String, dynamic>;
        final unit = localization['stringUnit'] as Map<String, dynamic>;
        final value = unit['value'] as String;
        expect(unit['state'], 'translated', reason: '$locale:$key');
        expect(value.trim(), isNotEmpty, reason: '$locale:$key');
        expect(
          value,
          isNot(contains(RegExp(r'\{[^}]+\}'))),
          reason: '$locale:$key',
        );
        final placeholderCount = RegExp(r'%@').allMatches(value).length;
        expect(
          placeholderCount,
          key.endsWith('Phrase') ? 1 : 0,
          reason: '$locale:$key',
        );
        expect(
          value.replaceAll('%@', ''),
          isNot(contains('%')),
          reason: '$locale:$key',
        );
      }

      expect(
        ((localizations['en'] as Map<String, dynamic>)['stringUnit']
            as Map<String, dynamic>)['value'],
        (proposal[key] as String).replaceAll('{applicationName}', '%@'),
        reason: key,
      );
    }
  });

  test('base Portuguese is derived exactly from approved Brazilian copy', () {
    final strings = (readJson(catalogPath)['strings'] as Map<String, dynamic>);

    for (final entry in strings.entries) {
      final localizations =
          (entry.value as Map<String, dynamic>)['localizations']
              as Map<String, dynamic>;
      expect(localizations['pt'], localizations['pt-BR'], reason: entry.key);
    }
  });

  test('typed accessor contains every key and no execution authority', () {
    final proposal = readJson(proposalPath);
    final accessor = File(accessorPath).readAsStringSync();

    for (final key in messageKeys(proposal)) {
      expect(accessor, contains('"$key"'), reason: key);
    }
    expect(
      accessor,
      contains('static let tableName = "AppleSystemAssistantNativeCopy"'),
    );
    expect(accessor, contains('maximumApplicationNameUTF8Length = 128'));
    expect(accessor, contains('return nil'));
    expect(accessor, isNot(contains('import AppIntents')));
    expect(accessor, isNot(contains('AppShortcutsProvider')));
    expect(accessor, isNot(contains('FlutterMethodChannel')));
    expect(accessor, isNot(contains('.submit(')));
  });

  test(
    'project preserves the catalog foundation beside reviewed registration',
    () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(
        project,
        contains('AppleSystemAssistantNativeCopy.xcstrings in Resources'),
      );
      expect(
        project,
        contains('HavenSystemAssistantAppleNativeCopy.swift in Sources'),
      );
      expect(
        project,
        contains('HavenSystemAssistantAppleNativeCopyTests.swift in Sources'),
      );
      for (final locale in expectedLocales.where((locale) => locale != 'en')) {
        expect(project, contains(locale), reason: locale);
      }
      expect(
        project,
        contains('HavenSystemAssistantAppleAppIntents.swift in Sources'),
      );
      expect(project, contains('AppShortcuts.strings in Resources'));
      expect(project, isNot(contains('AppShortcuts.xcstrings')));
      expect(project, isNot(contains('Siri')));
    },
  );

  test('Flutter runtime localization remains isolated from Apple copy', () {
    final sourceKeys = messageKeys(readJson(proposalPath));
    final runtimeCatalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);

    expect(runtimeCatalogs, hasLength(17));
    for (final catalog in runtimeCatalogs) {
      final runtimeKeys = readJson(catalog.path).keys.toSet();
      expect(
        runtimeKeys.intersection(sourceKeys),
        isEmpty,
        reason: catalog.path,
      );
    }
  });
}

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}
