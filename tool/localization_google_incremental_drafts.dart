import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'localization_google_translate_drafts.dart';
import 'localization_incremental_review.dart';

const googleIncrementalTranslationDraftWorkflow =
    'focus_haven_google_incremental_translation_drafts_v1';
const googleIncrementalTranslationQuarantineWorkflow =
    'focus_haven_google_incremental_translation_quarantine_v1';
const googleIncrementalProviderResponseWorkflow =
    'focus_haven_google_incremental_provider_response_v1';
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

Map<String, dynamic> buildGoogleIncrementalProviderResponse({
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, String> providerHtml,
}) => {
  'schemaVersion': 1,
  'workflow': googleIncrementalProviderResponseWorkflow,
  'deltaId': manifest.deltaId,
  'locale': entry.locale,
  'sourceProposalSha256': manifest.sourceProposalSha256,
  'provider': 'google_cloud_translation_advanced_v3',
  'projectId': config.projectId,
  'location': config.location,
  'model': config.model,
  'glossary': localeConfig.glossary,
  'targetLanguageCode': localeConfig.targetLanguageCode,
  'providerMimeType': googleTranslationDraftMimeType,
  'icuPlaceholderShielding': true,
  'providerHtml': providerHtml,
};

Map<String, String> verifyGoogleIncrementalProviderResponse({
  required Map<String, dynamic> response,
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> sourceProposal,
}) {
  _requireExactKeys(response, const {
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
    'targetLanguageCode',
    'providerMimeType',
    'icuPlaceholderShielding',
    'providerHtml',
  }, 'Google incremental provider response');
  if (response['schemaVersion'] != 1 ||
      response['workflow'] != googleIncrementalProviderResponseWorkflow ||
      response['deltaId'] != manifest.deltaId ||
      response['locale'] != entry.locale ||
      response['sourceProposalSha256'] != manifest.sourceProposalSha256 ||
      response['provider'] != 'google_cloud_translation_advanced_v3' ||
      response['projectId'] != config.projectId ||
      response['location'] != config.location ||
      response['model'] != config.model ||
      response['glossary'] != localeConfig.glossary ||
      response['targetLanguageCode'] != localeConfig.targetLanguageCode ||
      response['providerMimeType'] != googleTranslationDraftMimeType ||
      response['icuPlaceholderShielding'] != true) {
    throw const GoogleTranslationDraftFailure(
      'incremental_provider_response_binding_mismatch',
    );
  }
  final providerHtml = _strictStringMap(
    response['providerHtml'],
    'incremental provider response HTML',
  );
  final sourceKeys = sourceProposal.keys
      .where((key) => !key.startsWith('@'))
      .toSet();
  final responseKeys = providerHtml.keys.toSet();
  if (sourceKeys.length != responseKeys.length ||
      !sourceKeys.containsAll(responseKeys)) {
    throw const GoogleTranslationDraftFailure(
      'incremental_provider_response_key_mismatch',
    );
  }
  return providerHtml;
}

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
  const ordinaryOperations = {'preflight', 'translate', 'resume'};
  const repairOperations = {'repair-preflight', 'repair-translate'};
  if ((arguments.length != 4 ||
          !ordinaryOperations.contains(arguments.first)) &&
      (arguments.length != 5 || !repairOperations.contains(arguments.first))) {
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
    final targetLocale = repairOperations.contains(operation)
        ? arguments[4]
        : null;
    final makesProviderRequest =
        operation == 'translate' || operation == 'repair-translate';
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
    if (targetLocale != null) {
      verifyGoogleIncrementalTargetedRepairState(
        manifest: manifest,
        config: config,
        sourceProposal: sourceProposal,
        outputDirectory: outputDirectory,
        targetLocale: targetLocale,
      );
    } else if (operation == 'resume') {
      _requireResumableState(manifest, outputDirectory);
    } else {
      _refuseExistingState(manifest, outputDirectory);
    }

    final preflight = googleIncrementalTranslationPreflightSummary(
      manifest: manifest,
      config: config,
      sourceProposal: sourceProposal,
    );
    if (operation == 'preflight' || operation == 'repair-preflight') {
      stdout.writeln(
        _prettyJson(
          targetLocale == null
              ? preflight
              : {
                  ...preflight,
                  'operation': operation,
                  'localeCount': 1,
                  'targetLocale': targetLocale,
                  'existingBundleCount': manifest.locales.length - 1,
                },
        ),
      );
      return;
    }

    final providerChunks = buildGoogleTranslationDraftChunks(
      source: sourceProposal,
      maxCodePointsPerRequest: config.maxCodePointsPerRequest,
      protectIcuForProvider: true,
    );
    final requestCount = providerChunks.length;
    final codePointCount = preflight['codePointCountPerLocale'] as int;
    final client = makesProviderRequest
        ? GoogleTranslationRestClient(
            projectId: config.projectId,
            location: config.location,
            modelResource: config.modelResource,
            accessToken: await googleTranslationAccessToken(),
          )
        : null;
    final entries = targetLocale == null
        ? manifest.locales
        : [
            manifest.locales.singleWhere(
              (entry) => entry.locale == targetLocale,
            ),
          ];
    final results = await _concurrentMap(
      entries,
      googleIncrementalTranslationMaxParallelism,
      (entry) async {
        final outputPath = entry.bundlePath(outputDirectory);
        final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
        final providerResponsePath = _providerResponsePath(
          outputDirectory,
          entry.locale,
        );
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
          if (makesProviderRequest) {
            translations = await fetchGoogleTranslationDraftTranslations(
              plan: plan,
              localeConfig: localeConfig,
              source: sourceProposal,
              maxCodePointsPerRequest: config.maxCodePointsPerRequest,
              sender: client!.translate,
              onProviderHtml: (providerHtml) {
                final response = buildGoogleIncrementalProviderResponse(
                  manifest: manifest,
                  entry: entry,
                  config: config,
                  localeConfig: localeConfig,
                  providerHtml: providerHtml,
                );
                _writePrivateNew(providerResponsePath, _prettyJson(response));
              },
            );
          } else if (File(providerResponsePath).existsSync()) {
            final providerHtml = verifyGoogleIncrementalProviderResponse(
              response: _jsonObject(providerResponsePath),
              manifest: manifest,
              entry: entry,
              config: config,
              localeConfig: localeConfig,
              sourceProposal: sourceProposal,
            );
            translations = restoreGoogleTranslationDraftProviderHtml(
              source: sourceProposal,
              providerHtml: providerHtml,
            );
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
          try {
            if (File(providerResponsePath).existsSync()) {
              File(providerResponsePath).deleteSync();
            }
            if (File(quarantinePath).existsSync()) {
              File(quarantinePath).deleteSync();
            }
          } on Object {
            if (File(outputPath).existsSync()) File(outputPath).deleteSync();
            rethrow;
          }
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: true,
            requestCount: makesProviderRequest ? requestCount : 0,
            messageCount: translations.length,
            codePointCount: codePointCount,
            errorCode: null,
            quarantineState: 'consumed',
          );
        } on GoogleTranslationDraftFailure catch (error) {
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: false,
            requestCount: makesProviderRequest ? requestCount : 0,
            messageCount: sourceProposal.keys
                .where((key) => !key.startsWith('@'))
                .length,
            codePointCount: codePointCount,
            errorCode: error.code,
            diagnosticCodes: error.allCodes,
            quarantineState: _quarantineState(
              providerResponsePath,
              quarantinePath,
            ),
          );
        } on Object {
          return GoogleIncrementalTranslationDraftResult(
            locale: entry.locale,
            passed: false,
            requestCount: makesProviderRequest ? requestCount : 0,
            messageCount: sourceProposal.keys
                .where((key) => !key.startsWith('@'))
                .length,
            codePointCount: codePointCount,
            errorCode: 'unexpected_local_failure',
            diagnosticCodes: const ['unexpected_local_failure'],
            quarantineState: _quarantineState(
              providerResponsePath,
              quarantinePath,
            ),
          );
        }
      },
    );
    client?.close();
    final passed = results.every((result) => result.passed);
    final summary = <String, dynamic>{
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
      'requestCountPerLocale': makesProviderRequest ? requestCount : 0,
      'maxParallelism': googleIncrementalTranslationMaxParallelism,
      'locales': results.map((result) => result.toJson()).toList(),
      'humanReviewRequired': true,
      'runtimeActivated': false,
      'externalRequestMade': makesProviderRequest,
      'recoverablePrivateQuarantineEnabled': true,
      'providerMimeType': googleTranslationDraftMimeType,
      'icuPlaceholderShielding': true,
    };
    if (targetLocale != null) {
      summary['targetLocale'] = targetLocale;
      summary['existingBundleCount'] = manifest.locales.length - 1;
    }
    stdout.writeln(_prettyJson(summary));
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

String _providerResponsePath(String outputDirectory, String locale) =>
    '${Directory(outputDirectory).absolute.path}'
    '${Platform.pathSeparator}focushaven-$locale-incremental-provider-response.json';

String _quarantineState(String providerResponsePath, String quarantinePath) {
  if (File(providerResponsePath).existsSync()) {
    return 'provider_response_preserved';
  }
  if (File(quarantinePath).existsSync()) {
    return 'validated_response_preserved';
  }
  return 'not_created';
}

void verifyGoogleIncrementalTargetedRepairState({
  required IncrementalLocaleReviewManifest manifest,
  required GoogleTranslationDraftConfig config,
  required Map<String, dynamic> sourceProposal,
  required String outputDirectory,
  required String targetLocale,
}) {
  final targets = manifest.locales
      .where((entry) => entry.locale == targetLocale)
      .toList();
  if (targets.length != 1) {
    throw GoogleTranslationDraftFailure(
      'incremental_repair_unknown_target:$targetLocale',
    );
  }
  final target = targets.single;
  final targetOutputPath = target.bundlePath(outputDirectory);
  final targetQuarantinePath = _quarantinePath(outputDirectory, targetLocale);
  final targetProviderResponsePath = _providerResponsePath(
    outputDirectory,
    targetLocale,
  );
  if (FileSystemEntity.typeSync(targetOutputPath, followLinks: false) !=
          FileSystemEntityType.notFound ||
      FileSystemEntity.typeSync(targetQuarantinePath, followLinks: false) !=
          FileSystemEntityType.notFound ||
      FileSystemEntity.typeSync(
            targetProviderResponsePath,
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
    throw GoogleTranslationDraftFailure(
      'incremental_repair_target_not_empty:$targetLocale',
    );
  }
  final outputRoot = Directory(outputDirectory);
  final expectedPeerPaths = manifest.locales
      .where((entry) => entry.locale != targetLocale)
      .map((entry) => File(entry.bundlePath(outputDirectory)).absolute.path)
      .toSet();
  if (!outputRoot.existsSync()) {
    throw const GoogleTranslationDraftFailure(
      'incremental_repair_output_directory_missing',
    );
  }
  final actualEntries = outputRoot.listSync(followLinks: false);
  final actualPeerPaths = actualEntries
      .whereType<File>()
      .map((file) => file.absolute.path)
      .toSet();
  if (actualEntries.length != expectedPeerPaths.length ||
      actualPeerPaths.length != expectedPeerPaths.length ||
      !actualPeerPaths.containsAll(expectedPeerPaths)) {
    throw const GoogleTranslationDraftFailure(
      'incremental_repair_output_scope_mismatch',
    );
  }
  for (final entry in manifest.locales) {
    final outputPath = entry.bundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    final providerResponsePath = _providerResponsePath(
      outputDirectory,
      entry.locale,
    );
    if (Directory(outputPath).existsSync() ||
        Directory(quarantinePath).existsSync() ||
        Directory(providerResponsePath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'invalid_incremental_repair_state:${entry.locale}',
      );
    }
    final hasOutput = File(outputPath).existsSync();
    final hasQuarantine = File(quarantinePath).existsSync();
    final hasProviderResponse = File(providerResponsePath).existsSync();
    if (entry.locale == targetLocale) {
      continue;
    }
    if (!hasOutput || hasQuarantine || hasProviderResponse) {
      throw GoogleTranslationDraftFailure(
        'incremental_repair_existing_state_mismatch:${entry.locale}',
      );
    }
    final existing = _jsonObject(outputPath);
    final translations = _strictStringMap(
      existing['translations'],
      '${entry.locale} existing incremental bundle translations',
    );
    final expected = buildGoogleIncrementalTranslationDraftBundle(
      manifest: manifest,
      entry: entry,
      localeConfig: config.locales[entry.locale]!,
      sourceProposal: sourceProposal,
      translations: translations,
    );
    if (_prettyJson(existing) != _prettyJson(expected)) {
      throw GoogleTranslationDraftFailure(
        'incremental_repair_existing_bundle_lock_mismatch:${entry.locale}',
      );
    }
  }
}

void _refuseExistingState(
  IncrementalLocaleReviewManifest manifest,
  String outputDirectory,
) {
  for (final entry in manifest.locales) {
    final outputPath = entry.bundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    final providerResponsePath = _providerResponsePath(
      outputDirectory,
      entry.locale,
    );
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
    if (File(providerResponsePath).existsSync() ||
        Directory(providerResponsePath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'refusing_existing_incremental_provider_response:${entry.locale}',
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
    final providerResponsePath = _providerResponsePath(
      outputDirectory,
      entry.locale,
    );
    final hasOutput = File(outputPath).existsSync();
    final hasQuarantine = File(quarantinePath).existsSync();
    final hasProviderResponse = File(providerResponsePath).existsSync();
    if (Directory(outputPath).existsSync() ||
        Directory(quarantinePath).existsSync() ||
        Directory(providerResponsePath).existsSync() ||
        [
              hasOutput,
              hasQuarantine,
              hasProviderResponse,
            ].where((value) => value).length !=
            1) {
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
  dart run tool/localization_google_incremental_drafts.dart repair-preflight <incremental-manifest.json> <private-provider-config.json> <private-output-directory> <missing-locale>
  dart run tool/localization_google_incremental_drafts.dart repair-translate <incremental-manifest.json> <private-provider-config.json> <private-output-directory> <missing-locale>
''');
}
