import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'localization_google_translate_drafts.dart';
import 'localization_incremental_review.dart';

const googleIncrementalTranslationDraftWorkflow =
    'focus_haven_google_incremental_translation_drafts_v1';
const googleIncrementalTranslationQuarantineWorkflow =
    'focus_haven_google_incremental_translation_quarantine_v1';
const googleIncrementalTranslationMaxParallelism = 3;

final class GoogleIncrementalTranslationDraftResult {
  const GoogleIncrementalTranslationDraftResult({
    required this.locale,
    required this.passed,
    required this.requestCount,
    required this.messageCount,
    required this.codePointCount,
    required this.errorCode,
    required this.quarantineState,
    this.diagnosticCodes = const [],
    this.reusedExistingBundle = false,
  });

  final String locale;
  final bool passed;
  final int requestCount;
  final int messageCount;
  final int codePointCount;
  final String? errorCode;
  final List<String> diagnosticCodes;
  final String quarantineState;
  final bool reusedExistingBundle;

  Map<String, dynamic> toJson() => {
    'locale': locale,
    'passed': passed,
    'requestCount': requestCount,
    'messageCount': messageCount,
    'codePointCount': codePointCount,
    if (errorCode != null) 'errorCode': errorCode,
    if (diagnosticCodes.isNotEmpty) 'diagnosticCodes': diagnosticCodes,
    'quarantineState': quarantineState,
    'reusedExistingBundle': reusedExistingBundle,
  };
}

void verifyGoogleIncrementalTranslationDraftConfiguration({
  required IncrementalLocaleReviewManifest manifest,
  required GoogleTranslationDraftConfig config,
}) {
  final manifestLocales = manifest.locales.map((entry) => entry.locale).toSet();
  final configuredLocales = config.locales.keys.toSet();
  if (manifestLocales.length != configuredLocales.length ||
      !manifestLocales.containsAll(configuredLocales)) {
    throw const FormatException(
      'The provider config locale set must exactly match the incremental '
      'review manifest.',
    );
  }
}

Map<String, dynamic> buildGoogleIncrementalTranslationDraftBundle({
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> sourceProposal,
  required Map<String, String> translations,
}) {
  final plan = incrementalLocalePlanFor(manifest, entry);
  final ordinaryBundle = buildGoogleTranslationDraftBundleFromTranslations(
    plan: plan,
    localeConfig: localeConfig,
    source: sourceProposal,
    translations: translations,
  );
  final incrementalBundle = <String, dynamic>{
    'schemaVersion': 1,
    'workflow': incrementalLocaleBundleWorkflow,
    'deltaId': manifest.deltaId,
    'locale': entry.locale,
    'sourceProposalSha256': manifest.sourceProposalSha256,
    'translations': ordinaryBundle['translations'],
    'approvedSourceEqual': ordinaryBundle['approvedSourceEqual'],
  };
  final prepared = prepareIncrementalLocaleReview(
    manifest: manifest,
    entry: entry,
    sourceProposal: sourceProposal,
    translationBundle: incrementalBundle,
  );
  if (!prepared.passed) {
    throw GoogleTranslationDraftFailure.withDiagnostics([
      for (final error in prepared.errors)
        'incremental_draft_safety_refused:${error.replaceAll(':', '_')}',
    ]);
  }
  return incrementalBundle;
}

Map<String, dynamic> buildGoogleIncrementalTranslationQuarantine({
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, String> translations,
}) => {
  'schemaVersion': 1,
  'workflow': googleIncrementalTranslationQuarantineWorkflow,
  'deltaId': manifest.deltaId,
  'locale': entry.locale,
  'sourceProposalSha256': manifest.sourceProposalSha256,
  'provider': 'google_cloud_translation_advanced_v3',
  'projectId': config.projectId,
  'location': config.location,
  'model': config.model,
  'glossary': localeConfig.glossary,
  'translations': translations,
};

Map<String, String> verifyGoogleIncrementalTranslationQuarantine({
  required Map<String, dynamic> quarantine,
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> sourceProposal,
}) {
  _requireExactKeys(quarantine, const {
    'schemaVersion',
    'workflow',
    'deltaId',
    'locale',
    'sourceProposalSha256',
    'provider',
    'projectId',
    'location',
    'model',
    'glossary',
    'translations',
  }, 'Google incremental translation quarantine');
  if (quarantine['schemaVersion'] != 1 ||
      quarantine['workflow'] !=
          googleIncrementalTranslationQuarantineWorkflow ||
      quarantine['deltaId'] != manifest.deltaId ||
      quarantine['locale'] != entry.locale ||
      quarantine['sourceProposalSha256'] != manifest.sourceProposalSha256 ||
      quarantine['provider'] != 'google_cloud_translation_advanced_v3' ||
      quarantine['projectId'] != config.projectId ||
      quarantine['location'] != config.location ||
      quarantine['model'] != config.model ||
      quarantine['glossary'] != localeConfig.glossary) {
    throw const GoogleTranslationDraftFailure(
      'incremental_quarantine_binding_mismatch',
    );
  }
  final translations = _strictStringMap(
    quarantine['translations'],
    'incremental quarantine translations',
  );
  final sourceKeys = sourceProposal.keys
      .where((key) => !key.startsWith('@'))
      .toSet();
  if (translations.keys.toSet().length != sourceKeys.length ||
      !sourceKeys.containsAll(translations.keys) ||
      translations.values.any(
        (value) => value.trim().isEmpty || value.contains('\u0000'),
      )) {
    throw const GoogleTranslationDraftFailure(
      'incremental_quarantine_translation_schema_mismatch',
    );
  }
  return translations;
}

Map<String, dynamic> googleIncrementalTranslationPreflightSummary({
  required IncrementalLocaleReviewManifest manifest,
  required GoogleTranslationDraftConfig config,
  required Map<String, dynamic> sourceProposal,
}) {
  verifyGoogleIncrementalTranslationDraftConfiguration(
    manifest: manifest,
    config: config,
  );
  _verifyConfiguredSourceEqualKeys(
    manifest: manifest,
    config: config,
    sourceProposal: sourceProposal,
  );
  final sourceChunks = buildGoogleTranslationDraftChunks(
    source: sourceProposal,
    maxCodePointsPerRequest: config.maxCodePointsPerRequest,
  );
  final providerChunks = buildGoogleTranslationDraftChunks(
    source: sourceProposal,
    maxCodePointsPerRequest: config.maxCodePointsPerRequest,
    protectIcuForProvider: true,
  );
  final codePointCount = sourceChunks.fold<int>(
    0,
    (sum, chunk) => sum + chunk.codePointCount,
  );
  final providerCodePointCount = providerChunks.fold<int>(
    0,
    (sum, chunk) => sum + chunk.codePointCount,
  );
  return {
    'schemaVersion': 1,
    'workflow': googleIncrementalTranslationDraftWorkflow,
    'operation': 'preflight',
    'passed': true,
    'deltaId': manifest.deltaId,
    'provider': 'google_cloud_translation_advanced_v3',
    'model': config.model,
    'location': config.location,
    'localeCount': manifest.locales.length,
    'messageCountPerLocale': sourceProposal.keys
        .where((key) => !key.startsWith('@'))
        .length,
    'requestCountPerLocale': providerChunks.length,
    'codePointCountPerLocale': codePointCount,
    'providerCodePointCountPerLocale': providerCodePointCount,
    'maxParallelism': googleIncrementalTranslationMaxParallelism,
    'providerMimeType': googleTranslationDraftMimeType,
    'icuPlaceholderShielding': true,
    'glossaryRequiredPerLocale': true,
    'humanReviewRequired': true,
    'runtimeActivated': false,
    'externalRequestMade': false,
    'recoverablePrivateQuarantineEnabled': true,
  };
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4 ||
      !const {'preflight', 'translate', 'resume'}.contains(arguments.first)) {
    _usage();
    exitCode = 64;
    return;
  }
  try {
    final operation = arguments[0];
    final manifest = IncrementalLocaleReviewManifest.fromJson(
      _jsonObject(arguments[1]),
    );
    final config = GoogleTranslationDraftConfig.fromJson(
      _jsonObject(arguments[2]),
    );
    final outputDirectory = arguments[3];
    _requirePrivateFile(arguments[2]);
    _requirePrivateDirectory(outputDirectory);
    verifyGoogleIncrementalTranslationDraftConfiguration(
      manifest: manifest,
      config: config,
    );
    final sourceProposal = _jsonObject(manifest.sourceProposal);
    if (_sha256File(manifest.sourceProposal) != manifest.sourceProposalSha256) {
      throw const GoogleTranslationDraftFailure(
        'incremental_source_lock_mismatch',
      );
    }
    _verifyIncrementalManifestState(manifest, sourceProposal);
    _verifyConfiguredSourceEqualKeys(
      manifest: manifest,
      config: config,
      sourceProposal: sourceProposal,
    );
    if (operation == 'resume') {
      _requireResumableState(manifest, outputDirectory);
    } else {
      _refuseExistingState(manifest, outputDirectory);
    }

    final preflight = googleIncrementalTranslationPreflightSummary(
      manifest: manifest,
      config: config,
      sourceProposal: sourceProposal,
    );
    if (operation == 'preflight') {
      stdout.writeln(_prettyJson(preflight));
      return;
    }

    final providerChunks = buildGoogleTranslationDraftChunks(
      source: sourceProposal,
      maxCodePointsPerRequest: config.maxCodePointsPerRequest,
      protectIcuForProvider: true,
    );
    final requestCount = providerChunks.length;
    final codePointCount = preflight['codePointCountPerLocale'] as int;
    final client = operation == 'translate'
        ? GoogleTranslationRestClient(
            projectId: config.projectId,
            location: config.location,
            modelResource: config.modelResource,
            accessToken: await googleTranslationAccessToken(),
          )
        : null;
    final results = await _concurrentMap(
      manifest.locales,
      googleIncrementalTranslationMaxParallelism,
      (entry) async {
        final outputPath = entry.bundlePath(outputDirectory);
        final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
        final localeConfig = config.locales[entry.locale]!;
        final plan = incrementalLocalePlanFor(manifest, entry);
        try {
          if (operation == 'resume' && File(outputPath).existsSync()) {
            final existing = _jsonObject(outputPath);
            final translations = _strictStringMap(
              existing['translations'],
              '${entry.locale} existing incremental bundle translations',
            );
            final expected = buildGoogleIncrementalTranslationDraftBundle(
              manifest: manifest,
              entry: entry,
              localeConfig: localeConfig,
              sourceProposal: sourceProposal,
              translations: translations,
            );
            if (_prettyJson(existing) != _prettyJson(expected)) {
              throw const GoogleTranslationDraftFailure(
                'incremental_existing_bundle_lock_mismatch',
              );
            }
            return GoogleIncrementalTranslationDraftResult(
              locale: entry.locale,
              passed: true,
              requestCount: 0,
              messageCount: translations.length,
              codePointCount: codePointCount,
              errorCode: null,
              quarantineState: 'not_present',
              reusedExistingBundle: true,
            );
          }

          late final Map<String, String> translations;
          if (operation == 'translate') {
            translations = await fetchGoogleTranslationDraftTranslations(
              plan: plan,
              localeConfig: localeConfig,
              source: sourceProposal,
              maxCodePointsPerRequest: config.maxCodePointsPerRequest,
              sender: client!.translate,
            );
            final quarantine = buildGoogleIncrementalTranslationQuarantine(
              manifest: manifest,
              entry: entry,
              config: config,
              localeConfig: localeConfig,
              translations: translations,
            );
            _writePrivateNew(quarantinePath, _prettyJson(quarantine));
          } else {
            translations = verifyGoogleIncrementalTranslationQuarantine(
              quarantine: _jsonObject(quarantinePath),
              manifest: manifest,
              entry: entry,
              config: config,
              localeConfig: localeConfig,
              sourceProposal: sourceProposal,
            );
          }
          final bundle = buildGoogleIncrementalTranslationDraftBundle(
            manifest: manifest,
            entry: entry,
            localeConfig: localeConfig,
            sourceProposal: sourceProposal,
            translations: translations,
          );
          _writePrivateNew(outputPath, _prettyJson(bundle));
          File(quarantinePath).deleteSync();
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: true,
            requestCount: operation == 'translate' ? requestCount : 0,
            messageCount: translations.length,
            codePointCount: codePointCount,
            errorCode: null,
            quarantineState: 'consumed',
          );
        } on GoogleTranslationDraftFailure catch (error) {
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: false,
            requestCount: operation == 'translate' ? requestCount : 0,
            messageCount: sourceProposal.keys
                .where((key) => !key.startsWith('@'))
                .length,
            codePointCount: codePointCount,
            errorCode: error.code,
            diagnosticCodes: error.allCodes,
            quarantineState: File(quarantinePath).existsSync()
                ? 'preserved'
                : 'not_created',
          );
        } on Object {
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: false,
            requestCount: operation == 'translate' ? requestCount : 0,
            messageCount: sourceProposal.keys
                .where((key) => !key.startsWith('@'))
                .length,
            codePointCount: codePointCount,
            errorCode: 'unexpected_local_failure',
            diagnosticCodes: const ['unexpected_local_failure'],
            quarantineState: File(quarantinePath).existsSync()
                ? 'preserved'
                : 'not_created',
          );
        }
      },
    );
    client?.close();
    final passed = results.every((result) => result.passed);
    stdout.writeln(
      _prettyJson({
        'schemaVersion': 1,
        'workflow': googleIncrementalTranslationDraftWorkflow,
        'operation': operation,
        'passed': passed,
        'deltaId': manifest.deltaId,
        'provider': 'google_cloud_translation_advanced_v3',
        'localeCount': results.length,
        'passedCount': results.where((result) => result.passed).length,
        'failedCount': results.where((result) => !result.passed).length,
        'messageCountPerLocale': preflight['messageCountPerLocale'],
        'requestCountPerLocale': operation == 'translate' ? requestCount : 0,
        'maxParallelism': googleIncrementalTranslationMaxParallelism,
        'locales': results.map((result) => result.toJson()).toList(),
        'humanReviewRequired': true,
        'runtimeActivated': false,
        'externalRequestMade': operation == 'translate',
        'recoverablePrivateQuarantineEnabled': true,
        'providerMimeType': googleTranslationDraftMimeType,
        'icuPlaceholderShielding': true,
      }),
    );
    if (!passed) exitCode = 65;
  } on GoogleTranslationDraftFailure catch (error) {
    stderr.writeln(
      'Google incremental translation draft failed: '
      '${error.allCodes.join(',')}',
    );
    exitCode = 65;
  } on Object {
    stderr.writeln(
      'Google incremental translation draft failed: invalid_local_input',
    );
    exitCode = 66;
  }
}

void _verifyConfiguredSourceEqualKeys({
  required IncrementalLocaleReviewManifest manifest,
  required GoogleTranslationDraftConfig config,
  required Map<String, dynamic> sourceProposal,
}) {
  final sourceKeys = sourceProposal.keys
      .where((key) => !key.startsWith('@'))
      .toSet();
  final errors = <String>[];
  for (final entry in manifest.locales) {
    final localeConfig = config.locales[entry.locale]!;
    for (final key
        in localeConfig.approvedSourceEqual.keys
            .toSet()
            .difference(sourceKeys)
            .toList()
          ..sort()) {
      errors.add('unknown_source_equal_key:${entry.locale}:$key');
    }
  }
  if (errors.isNotEmpty) {
    throw GoogleTranslationDraftFailure.withDiagnostics(errors);
  }
}

void _verifyIncrementalManifestState(
  IncrementalLocaleReviewManifest manifest,
  Map<String, dynamic> sourceProposal,
) {
  final runtimeCatalogs = <String, Map<String, dynamic>>{};
  final runtimeDigests = <String, String>{};
  for (final path in {
    ...manifest.locales.map((entry) => entry.runtimeCatalog),
    ...manifest.derivedFallbacks.map((entry) => entry.runtimeCatalog),
  }) {
    runtimeCatalogs[path] = _jsonObject(path);
    runtimeDigests[path] = _sha256File(path);
  }
  final result = verifyIncrementalLocaleReview(
    manifest: manifest,
    sourceProposal: sourceProposal,
    runtimeCatalogs: runtimeCatalogs,
    runtimeCatalogDigests: runtimeDigests,
  );
  if (!result.passed) {
    throw GoogleTranslationDraftFailure.withDiagnostics([
      for (final error in result.errors)
        'incremental_preflight_refused:${error.replaceAll(':', '_')}',
    ]);
  }
}

void _requirePrivateDirectory(String path) {
  final repository = Directory.current.absolute.path;
  final absolute = Directory(path).absolute.path;
  if (absolute == repository ||
      absolute.startsWith('$repository${Platform.pathSeparator}')) {
    throw const GoogleTranslationDraftFailure(
      'private_output_must_be_outside_repository',
    );
  }
}

void _requirePrivateFile(String path) {
  final repository = Directory.current.absolute.path;
  final absolute = File(path).absolute.path;
  if (absolute == repository ||
      absolute.startsWith('$repository${Platform.pathSeparator}')) {
    throw const GoogleTranslationDraftFailure(
      'private_config_must_be_outside_repository',
    );
  }
}

String _quarantinePath(String outputDirectory, String locale) =>
    '${Directory(outputDirectory).absolute.path}'
    '${Platform.pathSeparator}focushaven-$locale-incremental-quarantine.json';

void _refuseExistingState(
  IncrementalLocaleReviewManifest manifest,
  String outputDirectory,
) {
  for (final entry in manifest.locales) {
    final outputPath = entry.bundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    if (File(outputPath).existsSync() || Directory(outputPath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'refusing_existing_incremental_output:${entry.locale}',
      );
    }
    if (File(quarantinePath).existsSync() ||
        Directory(quarantinePath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'refusing_existing_incremental_quarantine:${entry.locale}',
      );
    }
  }
}

void _requireResumableState(
  IncrementalLocaleReviewManifest manifest,
  String outputDirectory,
) {
  for (final entry in manifest.locales) {
    final outputPath = entry.bundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    final hasOutput = File(outputPath).existsSync();
    final hasQuarantine = File(quarantinePath).existsSync();
    if (Directory(outputPath).existsSync() ||
        Directory(quarantinePath).existsSync() ||
        hasOutput == hasQuarantine) {
      throw GoogleTranslationDraftFailure(
        'invalid_incremental_resume_state:${entry.locale}',
      );
    }
  }
}

void _writePrivateNew(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.createSync(exclusive: true);
  try {
    file.writeAsStringSync(contents, flush: true);
    final result = Process.runSync('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw const GoogleTranslationDraftFailure(
        'private_output_permission_failure',
      );
    }
  } on Object {
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}

Future<List<R>> _concurrentMap<T, R>(
  List<T> values,
  int parallelism,
  Future<R> Function(T) action,
) async {
  final results = List<R?>.filled(values.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (nextIndex < values.length) {
      final index = nextIndex;
      nextIndex += 1;
      results[index] = await action(values[index]);
    }
  }

  await Future.wait(
    List.generate(math.min(parallelism, values.length), (_) => worker()),
  );
  return results.cast<R>();
}

Map<String, dynamic> _jsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$path must contain one JSON object.');
  }
  return decoded;
}

Map<String, String> _strictStringMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw FormatException('$label must contain only string pairs.');
    }
    result[entry.key as String] = entry.value as String;
  }
  return result;
}

void _requireExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
  String label,
) {
  final actual = value.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$label has an invalid schema.');
  }
}

String _sha256File(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) throw StateError('Unable to hash $path.');
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _usage() {
  stderr.writeln('''
Usage:
  dart run tool/localization_google_incremental_drafts.dart preflight <incremental-manifest.json> <private-provider-config.json> <private-output-directory>
  dart run tool/localization_google_incremental_drafts.dart translate <incremental-manifest.json> <private-provider-config.json> <private-output-directory>
  dart run tool/localization_google_incremental_drafts.dart resume <incremental-manifest.json> <private-provider-config.json> <private-output-directory>
''');
}
