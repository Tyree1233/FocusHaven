import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_android_system_assistant_native_review.arb';
  const integrationPath =
      'localization/integrations/android_system_assistant_native_copy_v1.json';
  const accessorPath =
      'android/app/src/main/kotlin/com/focushaven/app/'
      'HavenSystemAssistantAndroidNativeCopy.kt';
  const acceptanceLockSha256 =
      'fb6bdbab93be4298b806c2c6058129c35b83c753c205df379ba5f3956745cfc1';
  const expectedQualifiers = <String, String>{
    'en': 'values',
    'es': 'values-es',
    'fr': 'values-fr',
    'de': 'values-de',
    'pt-BR': 'values-pt-rBR',
    'pt': 'values-pt',
    'ja': 'values-ja',
    'ko': 'values-ko',
    'it': 'values-it',
    'pl': 'values-pl',
    'nl': 'values-nl',
    'id': 'values-in',
    'tr': 'values-tr',
    'sv': 'values-sv',
    'nb': 'values-nb',
    'da': 'values-da',
    'fi': 'values-fi',
  };

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) => arb.keys
      .where((key) => key != '@@locale' && !key.startsWith('@'))
      .toSet();

  test('integration provenance locks the accepted Android review set', () {
    final integration = readJson(integrationPath);

    expect(integration['schemaVersion'], 1);
    expect(
      integration['workflow'],
      'focus_haven_phase217i_android_native_copy_resource_integration_v1',
    );
    expect(integration['deltaId'], 'android-system-assistant-native-copy-v1');
    expect(integration['messageCount'], 28);
    expect(integration['placeholderMessageCount'], 0);
    expect(integration['acceptanceLockSha256'], acceptanceLockSha256);
    expect(integration['reviewDecisionCounts'], {
      'accepted': 208,
      'revised': 212,
      'blocked': 0,
    });
    expect(
      (integration['independentlyReviewedLocales'] as List<dynamic>).toSet(),
      expectedQualifiers.keys
          .where((locale) => locale != 'en' && locale != 'pt')
          .toSet(),
    );
    expect(integration['derivedFallbacks'], [
      {'reviewedLocale': 'pt-BR', 'fallbackLocale': 'pt'},
    ]);
    expect(
      (integration['resourceLocalizations'] as List<dynamic>).toSet(),
      expectedQualifiers.keys.toSet(),
    );
    expect(integration['flutterRuntimeCatalogChanged'], isFalse);
    expect(integration['shortcutsXmlCreated'], isFalse);
    expect(integration['capabilityMetadataCreated'], isFalse);
    expect(integration['queryPatternsCreated'], isFalse);
    expect(integration['manifestRegistrationEnabled'], isFalse);
    expect(integration['appActionRegistrationEnabled'], isFalse);
    expect(integration['havenActionExecutionEnabled'], isFalse);
  });

  test('all seventeen Android resource files are exact and complete', () {
    final proposal = readJson(proposalPath);
    final sourceKeys = messageKeys(proposal);
    final expectedResourceNames = sourceKeys.map(_snakeCase).toSet();
    final integration = readJson(integrationPath);
    final files = integration['androidResourceFiles'] as Map<String, dynamic>;

    expect(sourceKeys, hasLength(28));
    expect(files.keys.toSet(), expectedQualifiers.keys.toSet());

    for (final entry in expectedQualifiers.entries) {
      final record = files[entry.key] as Map<String, dynamic>;
      final path = record['path'] as String;
      final values = _readAndroidStrings(path);

      expect(record['qualifier'], entry.value, reason: entry.key);
      expect(
        path,
        'android/app/src/main/res/${entry.value}/'
        'android_system_assistant_native_copy.xml',
        reason: entry.key,
      );
      expect(record['sha256'], _sha256(path), reason: entry.key);
      expect(values.keys.toSet(), expectedResourceNames, reason: entry.key);
      expect(values, hasLength(28), reason: entry.key);
      expect(
        values.values.every(
          (value) =>
              value.trim() == value &&
              value.isNotEmpty &&
              !value.contains('%') &&
              !RegExp(r'\{[^}]+\}').hasMatch(value),
        ),
        isTrue,
        reason: entry.key,
      );
    }

    final english = _readAndroidStrings(
      (files['en'] as Map<String, dynamic>)['path'] as String,
    );
    for (final key in sourceKeys) {
      expect(english[_snakeCase(key)], proposal[key], reason: key);
    }
  });

  test('base Portuguese is byte-identical to reviewed Brazilian copy', () {
    final integration = readJson(integrationPath);
    final files = integration['androidResourceFiles'] as Map<String, dynamic>;
    final brazilPath =
        (files['pt-BR'] as Map<String, dynamic>)['path'] as String;
    final fallbackPath =
        (files['pt'] as Map<String, dynamic>)['path'] as String;

    expect(
      File(fallbackPath).readAsBytesSync(),
      File(brazilPath).readAsBytesSync(),
    );
    expect(
      (files['pt'] as Map<String, dynamic>)['sha256'],
      (files['pt-BR'] as Map<String, dynamic>)['sha256'],
    );
  });

  test('typed accessor maps all keys but owns no public authority', () {
    final sourceKeys = messageKeys(readJson(proposalPath));
    final accessor = File(accessorPath).readAsStringSync();

    for (final key in sourceKeys) {
      expect(accessor, contains('R.string.${_snakeCase(key)}'), reason: key);
    }
    expect(
      accessor,
      contains('HavenSystemAssistantAndroidRoute.nativeCopyKeys'),
    );
    expect(accessor, contains('MAXIMUM_TEXT_UTF8_LENGTH = 1024'));
    expect(accessor, contains('Resources.NotFoundException'));
    expect(accessor, isNot(contains('ShortcutInfo')));
    expect(accessor, isNot(contains('shortcuts.xml')));
    expect(accessor, isNot(contains('queryPatterns')));
    expect(accessor, isNot(contains('Intent(')));
    expect(accessor, isNot(contains('FlutterMethodChannel')));
    expect(accessor, isNot(contains('.submit(')));
  });

  test('Flutter catalogs and Android public registration remain closed', () {
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

    expect(
      Directory('android/app/src/main')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.uri.pathSegments.last == 'shortcuts.xml'),
      isEmpty,
    );
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('android.app.shortcuts')));
    expect(manifest, isNot(contains('actions.intent')));
    final resources = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.xml'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(resources, isNot(contains('app:queryPatterns')));
    expect(resources, isNot(contains('<capability')));
    expect(resources, isNot(contains('<shortcut')));
  });
}

Map<String, String> _readAndroidStrings(String path) {
  final source = File(path).readAsStringSync();
  final matches = RegExp(
    r'<string name="([^"]+)" formatted="false">(.*?)</string>',
  ).allMatches(source);
  return <String, String>{
    for (final match in matches)
      match.group(1)!: _decodeAndroidXml(match.group(2)!),
  };
}

String _decodeAndroidXml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\\', r'\');

String _snakeCase(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    )
    .toLowerCase();

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}
