import 'dart:convert';
import 'dart:io';

const _sourcePath = 'ios/Runner/AppleSystemAssistantNativeCopy.xcstrings';
const _outputRoot = 'ios/Runner';
const _legacyOutputPath = 'ios/Runner/AppShortcuts.xcstrings';
const _phraseKeys = <String>[
  'appleSystemAssistantNativeReadTimerStatusPhrase',
  'appleSystemAssistantNativeStartFocusTimerPhrase',
  'appleSystemAssistantNativePauseTimerPhrase',
  'appleSystemAssistantNativeResumeTimerPhrase',
  'appleSystemAssistantNativeOpenFocusQueuePhrase',
];

void main(List<String> arguments) {
  if (arguments.length > 1 ||
      (arguments.isNotEmpty && arguments.single != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/apple_system_assistant_app_shortcuts_catalog.dart '
      '[--check]',
    );
    exitCode = 64;
    return;
  }

  final generated = _buildCatalogs();
  if (arguments.contains('--check')) {
    final existing = Directory(_outputRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('/AppShortcuts.strings'))
        .map((file) => file.path)
        .toSet();
    final expected = generated.keys.toSet();
    final contentsMatch = expected.every(
      (path) =>
          File(path).existsSync() &&
          File(path).readAsStringSync() == generated[path],
    );
    if (File(_legacyOutputPath).existsSync() ||
        existing.length != expected.length ||
        !existing.containsAll(expected) ||
        !contentsMatch) {
      stderr.writeln(
        'The localized AppShortcuts.strings family is missing, contains an '
        'unexpected member, or differs from the reviewed Apple-native phrase '
        'catalog.',
      );
      exitCode = 1;
    }
    return;
  }
  if (File(_legacyOutputPath).existsSync()) {
    stderr.writeln(
      'Remove the iOS-17-only AppShortcuts.xcstrings resource before '
      'generating the iOS-16-compatible strings family.',
    );
    exitCode = 1;
    return;
  }
  for (final entry in generated.entries) {
    final output = File(entry.key);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(entry.value);
  }
}

Map<String, String> _buildCatalogs() {
  final source =
      jsonDecode(File(_sourcePath).readAsStringSync()) as Map<String, Object?>;
  if (source['sourceLanguage'] != 'en' || source['version'] != '1.0') {
    throw const FormatException('Unexpected reviewed catalog header.');
  }
  final strings = source['strings'] as Map<String, Object?>;
  if (!_phraseKeys.every(strings.containsKey)) {
    throw const FormatException('A reviewed invocation phrase is missing.');
  }

  Set<String>? expectedLocales;
  final localizedPhrases = <String, List<MapEntry<String, String>>>{};
  for (final phraseKey in _phraseKeys) {
    final sourceEntry = strings[phraseKey] as Map<String, Object?>;
    final localizations = sourceEntry['localizations'] as Map<String, Object?>;
    if (localizations.length != 17 || !localizations.containsKey('en')) {
      throw FormatException(
        '$phraseKey must contain exactly seventeen localizations.',
      );
    }
    final locales = localizations.keys.toSet();
    if (expectedLocales != null &&
        (!expectedLocales.containsAll(locales) ||
            !locales.containsAll(expectedLocales))) {
      throw FormatException('$phraseKey has an inconsistent locale set.');
    }
    expectedLocales ??= locales;

    final english =
        ((localizations['en'] as Map<String, Object?>)['stringUnit']
                as Map<String, Object?>)['value']
            as String;
    final sourcePhrase = english.replaceAll('%@', r'${applicationName}');
    for (final locale in localizations.keys.toList()..sort()) {
      final localization = localizations[locale] as Map<String, Object?>;
      final stringUnit = localization['stringUnit'] as Map<String, Object?>;
      final value = stringUnit['value'] as String;
      if (stringUnit['state'] != 'translated' ||
          RegExp(r'%@').allMatches(value).length != 1 ||
          value.replaceAll('%@', '').contains('%')) {
        throw FormatException('$locale:$phraseKey has an invalid placeholder.');
      }
      localizedPhrases
          .putIfAbsent(locale, () => [])
          .add(
            MapEntry(
              sourcePhrase,
              value.replaceAll('%@', r'${applicationName}'),
            ),
          );
    }
  }

  return <String, String>{
    for (final locale in localizedPhrases.keys.toList()..sort())
      '$_outputRoot/$locale.lproj/AppShortcuts.strings': _encodeStrings(
        localizedPhrases[locale]!,
      ),
  };
}

String _encodeStrings(List<MapEntry<String, String>> phrases) {
  final output = StringBuffer(
    '/* Generated from the reviewed Phase 217F Apple-native phrase catalog. '
    'Do not edit. */\n\n',
  );
  for (final phrase in phrases) {
    output
      ..write('"')
      ..write(_escapeStringsValue(phrase.key))
      ..write('" = "')
      ..write(_escapeStringsValue(phrase.value))
      ..writeln('";');
  }
  return output.toString();
}

String _escapeStringsValue(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');
