import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'localization_streamlined_batch.dart';
import 'localization_streamlined_pipeline.dart';

const googleTranslationDraftWorkflow =
    'focus_haven_google_translation_drafts_v1';
const googleTranslationDraftQuarantineWorkflow =
    'focus_haven_google_translation_quarantine_v1';
const googleTranslationDraftLocation = 'us-central1';
const googleTranslationDraftModel = 'general/nmt';
const googleTranslationRecommendedCodePointLimit = 5000;

final class GoogleTranslationDraftFailure implements Exception {
  const GoogleTranslationDraftFailure(this.code) : diagnosticCodes = const [];

  GoogleTranslationDraftFailure.withDiagnostics(List<String> codes)
    : assert(codes.isNotEmpty),
      code = codes.first,
      diagnosticCodes = List<String>.unmodifiable(codes);

  final String code;
  final List<String> diagnosticCodes;

  List<String> get allCodes =>
      diagnosticCodes.isEmpty ? <String>[code] : diagnosticCodes;

  @override
  String toString() => code;
}

final class GoogleTranslationDraftLocaleConfig {
  const GoogleTranslationDraftLocaleConfig({
    required this.targetLanguageCode,
    required this.glossary,
    required this.approvedSourceEqual,
  });

  factory GoogleTranslationDraftLocaleConfig.fromJson(
    String locale,
    Map<String, dynamic> json, {
    required String projectId,
    required String location,
  }) {
    _requireExactKeys(json, const {
      'targetLanguageCode',
      'glossary',
      'approvedSourceEqual',
    }, '$locale provider config');
    final targetLanguageCode = _requiredString(json, 'targetLanguageCode');
    if (targetLanguageCode != locale) {
      throw FormatException(
        '$locale targetLanguageCode must exactly match the batch locale.',
      );
    }
    final glossary = _requiredString(json, 'glossary');
    final expectedPrefix =
        'projects/$projectId/locations/$location/glossaries/';
    if (!glossary.startsWith(expectedPrefix) ||
        glossary.substring(expectedPrefix.length).isEmpty ||
        !RegExp(
          r'^[A-Za-z][A-Za-z0-9_-]{0,62}$',
        ).hasMatch(glossary.substring(expectedPrefix.length))) {
      throw FormatException(
        '$locale glossary must be a resource in the configured project and '
        'location.',
      );
    }
    final approvedSourceEqual = _strictStringMap(
      json['approvedSourceEqual'],
      '$locale approvedSourceEqual',
    );
    if (approvedSourceEqual.values.any((value) => value.trim().isEmpty)) {
      throw FormatException(
        '$locale approvedSourceEqual rationales must be non-empty.',
      );
    }
    return GoogleTranslationDraftLocaleConfig(
      targetLanguageCode: targetLanguageCode,
      glossary: glossary,
      approvedSourceEqual: approvedSourceEqual,
    );
  }

  final String targetLanguageCode;
  final String glossary;
  final Map<String, String> approvedSourceEqual;
}

final class GoogleTranslationDraftConfig {
  const GoogleTranslationDraftConfig({
    required this.projectId,
    required this.location,
    required this.model,
    required this.maxCodePointsPerRequest,
    required this.locales,
  });

  factory GoogleTranslationDraftConfig.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'schemaVersion',
      'workflow',
      'projectId',
      'location',
      'model',
      'maxCodePointsPerRequest',
      'locales',
    }, 'Google translation draft config');
    if (json['schemaVersion'] != 1 ||
        json['workflow'] != googleTranslationDraftWorkflow) {
      throw const FormatException(
        'Unsupported Google translation draft config.',
      );
    }
    final projectId = _requiredString(json, 'projectId');
    if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId)) {
      throw const FormatException('projectId is not a canonical project ID.');
    }
    final location = _requiredString(json, 'location');
    if (location != googleTranslationDraftLocation) {
      throw FormatException(
        'location must be $googleTranslationDraftLocation for glossaries.',
      );
    }
    final model = _requiredString(json, 'model');
    if (model != googleTranslationDraftModel) {
      throw FormatException('model must be $googleTranslationDraftModel.');
    }
    final maxCodePointsPerRequest = json['maxCodePointsPerRequest'];
    if (maxCodePointsPerRequest is! int ||
        maxCodePointsPerRequest < 1 ||
        maxCodePointsPerRequest > googleTranslationRecommendedCodePointLimit) {
      throw FormatException(
        'maxCodePointsPerRequest must be from 1 through '
        '$googleTranslationRecommendedCodePointLimit.',
      );
    }
    final localesValue = json['locales'];
    if (localesValue is! Map<String, dynamic> || localesValue.isEmpty) {
      throw const FormatException('locales must be a non-empty object.');
    }
    final locales = <String, GoogleTranslationDraftLocaleConfig>{};
    for (final entry in localesValue.entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw FormatException(
          '${entry.key} provider config must be an object.',
        );
      }
      locales[entry.key] = GoogleTranslationDraftLocaleConfig.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
        projectId: projectId,
        location: location,
      );
    }
    final glossaries = locales.values.map((value) => value.glossary).toSet();
    if (glossaries.length != locales.length) {
      throw const FormatException(
        'Each locale must use its own bilingual glossary.',
      );
    }
    return GoogleTranslationDraftConfig(
      projectId: projectId,
      location: location,
      model: model,
      maxCodePointsPerRequest: maxCodePointsPerRequest,
      locales: locales,
    );
  }

  final String projectId;
  final String location;
  final String model;
  final int maxCodePointsPerRequest;
  final Map<String, GoogleTranslationDraftLocaleConfig> locales;

  String get modelResource =>
      'projects/$projectId/locations/$location/models/$model';
}

final class GoogleTranslationDraftChunk {
  const GoogleTranslationDraftChunk({
    required this.keys,
    required this.contents,
    required this.codePointCount,
  });

  final List<String> keys;
  final List<String> contents;
  final int codePointCount;
}

final class GoogleTranslationDraftLocaleResult {
  const GoogleTranslationDraftLocaleResult({
    required this.locale,
    required this.passed,
    required this.requestCount,
    required this.messageCount,
    required this.codePointCount,
    required this.errorCode,
    this.diagnosticCodes = const [],
    this.quarantineState = 'not_created',
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

typedef GoogleTranslationDraftSender =
    Future<List<String>> Function({
      required String locale,
      required String glossary,
      required List<String> contents,
    });

List<GoogleTranslationDraftChunk> buildGoogleTranslationDraftChunks({
  required Map<String, dynamic> source,
  required int maxCodePointsPerRequest,
}) {
  if (source['@@locale'] != 'en') {
    throw const GoogleTranslationDraftFailure('invalid_source_locale');
  }
  final entries =
      source.entries.where((entry) => !entry.key.startsWith('@')).toList()
        ..sort((left, right) => left.key.compareTo(right.key));
  final chunks = <GoogleTranslationDraftChunk>[];
  var keys = <String>[];
  var contents = <String>[];
  var codePointCount = 0;

  void finishChunk() {
    if (keys.isEmpty) return;
    chunks.add(
      GoogleTranslationDraftChunk(
        keys: List<String>.unmodifiable(keys),
        contents: List<String>.unmodifiable(contents),
        codePointCount: codePointCount,
      ),
    );
    keys = <String>[];
    contents = <String>[];
    codePointCount = 0;
  }

  for (final entry in entries) {
    final value = entry.value;
    if (value is! String || value.isEmpty || value.contains('\u0000')) {
      throw GoogleTranslationDraftFailure(
        'invalid_source_message:${entry.key}',
      );
    }
    final length = value.runes.length;
    if (length > maxCodePointsPerRequest) {
      throw GoogleTranslationDraftFailure(
        'source_message_exceeds_request_limit:${entry.key}',
      );
    }
    if (contents.isNotEmpty &&
        (codePointCount + length > maxCodePointsPerRequest ||
            contents.length == 1024)) {
      finishChunk();
    }
    keys.add(entry.key);
    contents.add(value);
    codePointCount += length;
  }
  finishChunk();
  return chunks;
}

Future<Map<String, String>> fetchGoogleTranslationDraftTranslations({
  required StreamlinedLocalePlan plan,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> source,
  required int maxCodePointsPerRequest,
  required GoogleTranslationDraftSender sender,
}) async {
  final sourceKeys = source.keys.where((key) => !key.startsWith('@')).toSet();
  final unknownSourceEqualKeys =
      localeConfig.approvedSourceEqual.keys
          .toSet()
          .difference(sourceKeys)
          .toList()
        ..sort();
  if (unknownSourceEqualKeys.isNotEmpty) {
    throw GoogleTranslationDraftFailure.withDiagnostics([
      for (final key in unknownSourceEqualKeys) 'unknown_source_equal_key:$key',
    ]);
  }
  final translations = <String, String>{};
  final chunks = buildGoogleTranslationDraftChunks(
    source: source,
    maxCodePointsPerRequest: maxCodePointsPerRequest,
  );
  for (final chunk in chunks) {
    final translated = await sender(
      locale: plan.locale,
      glossary: localeConfig.glossary,
      contents: chunk.contents,
    );
    if (translated.length != chunk.keys.length) {
      throw const GoogleTranslationDraftFailure(
        'provider_response_count_mismatch',
      );
    }
    for (var index = 0; index < chunk.keys.length; index += 1) {
      final key = chunk.keys[index];
      final value = translated[index];
      if (value.trim().isEmpty || value.contains('\u0000')) {
        throw GoogleTranslationDraftFailure('invalid_provider_value:$key');
      }
      translations[key] = value;
    }
  }
  return translations;
}

Map<String, dynamic> buildGoogleTranslationDraftBundleFromTranslations({
  required StreamlinedLocalePlan plan,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> source,
  required Map<String, String> translations,
}) {
  final sourceKeys = source.keys.where((key) => !key.startsWith('@')).toSet();
  final translationKeys = translations.keys.toSet();
  final configuredSourceEqualKeys = localeConfig.approvedSourceEqual.keys
      .toSet();
  final diagnostics = <String>[
    for (final key
        in configuredSourceEqualKeys.difference(sourceKeys).toList()..sort())
      'unknown_source_equal_key:$key',
    for (final key in sourceKeys.difference(translationKeys).toList()..sort())
      'missing_provider_translation:$key',
    for (final key in translationKeys.difference(sourceKeys).toList()..sort())
      'extra_provider_translation:$key',
  ];

  for (final key in sourceKeys.toList()..sort()) {
    final sourceText = source[key];
    final translation = translations[key];
    if (translation == null) continue;
    if (translation.trim().isEmpty || translation.contains('\u0000')) {
      diagnostics.add('invalid_provider_value:$key');
      continue;
    }
    final configured = configuredSourceEqualKeys.contains(key);
    if (translation == sourceText && !configured) {
      diagnostics.add('unapproved_source_equal:$key');
    }
    if (translation != sourceText && configured) {
      diagnostics.add('stale_source_equal_approval:$key');
    }
  }
  if (diagnostics.isNotEmpty) {
    throw GoogleTranslationDraftFailure.withDiagnostics(diagnostics);
  }

  final bundle = <String, dynamic>{
    'schemaVersion': 1,
    'workflow': streamlinedLocaleWorkflow,
    'locale': plan.locale,
    'sourceCatalogSha256': plan.sourceCatalogSha256,
    'translations': translations,
    'approvedSourceEqual': localeConfig.approvedSourceEqual,
  };
  final prepared = prepareStreamlinedLocale(
    plan: plan,
    source: source,
    translationBundle: bundle,
  );
  if (!prepared.passed) {
    final errors = prepared.errors.isEmpty
        ? const ['draft_safety_refused:unknown']
        : [
            for (final error in prepared.errors)
              'draft_safety_refused:${error.replaceAll(':', '_')}',
          ];
    throw GoogleTranslationDraftFailure.withDiagnostics(errors);
  }
  return bundle;
}

Future<Map<String, dynamic>> buildGoogleTranslationDraftBundle({
  required StreamlinedLocalePlan plan,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> source,
  required int maxCodePointsPerRequest,
  required GoogleTranslationDraftSender sender,
}) async {
  final translations = await fetchGoogleTranslationDraftTranslations(
    plan: plan,
    localeConfig: localeConfig,
    source: source,
    maxCodePointsPerRequest: maxCodePointsPerRequest,
    sender: sender,
  );
  return buildGoogleTranslationDraftBundleFromTranslations(
    plan: plan,
    localeConfig: localeConfig,
    source: source,
    translations: translations,
  );
}

Map<String, dynamic> buildGoogleTranslationDraftQuarantine({
  required StreamlinedLocalePlan plan,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, String> translations,
}) => {
  'schemaVersion': 1,
  'workflow': googleTranslationDraftQuarantineWorkflow,
  'locale': plan.locale,
  'sourceCatalogSha256': plan.sourceCatalogSha256,
  'provider': 'google_cloud_translation_advanced_v3',
  'projectId': config.projectId,
  'location': config.location,
  'model': config.model,
  'glossary': localeConfig.glossary,
  'translations': translations,
};

Map<String, String> verifyGoogleTranslationDraftQuarantine({
  required Map<String, dynamic> quarantine,
  required StreamlinedLocalePlan plan,
  required GoogleTranslationDraftConfig config,
  required GoogleTranslationDraftLocaleConfig localeConfig,
  required Map<String, dynamic> source,
}) {
  _requireExactKeys(quarantine, const {
    'schemaVersion',
    'workflow',
    'locale',
    'sourceCatalogSha256',
    'provider',
    'projectId',
    'location',
    'model',
    'glossary',
    'translations',
  }, 'Google translation quarantine');
  if (quarantine['schemaVersion'] != 1 ||
      quarantine['workflow'] != googleTranslationDraftQuarantineWorkflow ||
      quarantine['locale'] != plan.locale ||
      quarantine['sourceCatalogSha256'] != plan.sourceCatalogSha256 ||
      quarantine['provider'] != 'google_cloud_translation_advanced_v3' ||
      quarantine['projectId'] != config.projectId ||
      quarantine['location'] != config.location ||
      quarantine['model'] != config.model ||
      quarantine['glossary'] != localeConfig.glossary) {
    throw const GoogleTranslationDraftFailure('quarantine_binding_mismatch');
  }
  final translations = _strictStringMap(
    quarantine['translations'],
    'quarantine translations',
  );
  final sourceKeys = source.keys.where((key) => !key.startsWith('@')).toSet();
  final translationKeys = translations.keys.toSet();
  if (sourceKeys.length != translationKeys.length ||
      !sourceKeys.containsAll(translationKeys) ||
      translations.values.any(
        (value) => value.trim().isEmpty || value.contains('\u0000'),
      )) {
    throw const GoogleTranslationDraftFailure(
      'quarantine_translation_schema_mismatch',
    );
  }
  return translations;
}

void verifyGoogleTranslationDraftConfiguration({
  required StreamlinedLocaleBatchManifest manifest,
  required GoogleTranslationDraftConfig config,
}) {
  final batchLocales = manifest.locales.map((entry) => entry.locale).toSet();
  final configuredLocales = config.locales.keys.toSet();
  if (batchLocales.length != configuredLocales.length ||
      !batchLocales.containsAll(configuredLocales)) {
    throw const FormatException(
      'The provider config locale set must exactly match the batch manifest.',
    );
  }
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
    final manifest = StreamlinedLocaleBatchManifest.fromJson(
      _jsonObject(arguments[1]),
    );
    final config = GoogleTranslationDraftConfig.fromJson(
      _jsonObject(arguments[2]),
    );
    final outputDirectory = arguments[3];
    _requirePrivateFile(arguments[2]);
    verifyGoogleTranslationDraftConfiguration(
      manifest: manifest,
      config: config,
    );
    _verifySourceAndPlans(manifest);
    _requirePrivateDirectory(outputDirectory);
    if (operation == 'resume') {
      _requireResumableDraftState(manifest, outputDirectory);
    } else {
      _refuseExistingDraftState(manifest, outputDirectory);
    }
    final source = _jsonObject(manifest.sourceCatalog);
    final chunks = buildGoogleTranslationDraftChunks(
      source: source,
      maxCodePointsPerRequest: config.maxCodePointsPerRequest,
    );
    final codePointCount = chunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.codePointCount,
    );

    if (operation == 'preflight') {
      stdout.writeln(
        _prettyJson({
          'schemaVersion': 1,
          'workflow': googleTranslationDraftWorkflow,
          'operation': operation,
          'passed': true,
          'provider': 'google_cloud_translation_advanced_v3',
          'model': config.model,
          'location': config.location,
          'localeCount': manifest.locales.length,
          'messageCountPerLocale': source.keys
              .where((key) => !key.startsWith('@'))
              .length,
          'requestCountPerLocale': chunks.length,
          'codePointCountPerLocale': codePointCount,
          'glossaryRequiredPerLocale': true,
          'humanReviewRequired': true,
          'runtimeActivated': false,
          'externalRequestMade': false,
          'recoverablePrivateQuarantineEnabled': true,
        }),
      );
      return;
    }

    final client = operation == 'translate'
        ? _GoogleTranslationRestClient(
            projectId: config.projectId,
            location: config.location,
            modelResource: config.modelResource,
            accessToken: await _googleAccessToken(),
          )
        : null;
    final results = await _concurrentMap(
      manifest.locales,
      manifest.maxParallelism,
      (entry) async {
        final outputPath = entry.translationBundlePath(outputDirectory);
        final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
        try {
          final plan = StreamlinedLocalePlan.fromJson(
            _jsonObject(entry.planPath),
          );
          final localeConfig = config.locales[entry.locale]!;
          if (operation == 'resume' && File(outputPath).existsSync()) {
            final existing = _jsonObject(outputPath);
            final translations = _strictStringMap(
              existing['translations'],
              '${entry.locale} existing bundle translations',
            );
            final expected = buildGoogleTranslationDraftBundleFromTranslations(
              plan: plan,
              localeConfig: localeConfig,
              source: source,
              translations: translations,
            );
            if (_prettyJson(existing) != _prettyJson(expected)) {
              throw const GoogleTranslationDraftFailure(
                'existing_bundle_lock_mismatch',
              );
            }
            return GoogleTranslationDraftLocaleResult(
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
              source: source,
              maxCodePointsPerRequest: config.maxCodePointsPerRequest,
              sender: client!.translate,
            );
            final quarantine = buildGoogleTranslationDraftQuarantine(
              plan: plan,
              config: config,
              localeConfig: localeConfig,
              translations: translations,
            );
            _writePrivateNew(quarantinePath, _prettyJson(quarantine));
          } else {
            translations = verifyGoogleTranslationDraftQuarantine(
              quarantine: _jsonObject(quarantinePath),
              plan: plan,
              config: config,
              localeConfig: localeConfig,
              source: source,
            );
          }
          final bundle = buildGoogleTranslationDraftBundleFromTranslations(
            plan: plan,
            localeConfig: localeConfig,
            source: source,
            translations: translations,
          );
          _writePrivateNew(outputPath, _prettyJson(bundle));
          File(quarantinePath).deleteSync();
          return GoogleTranslationDraftLocaleResult(
            locale: entry.locale,
            passed: true,
            requestCount: operation == 'translate' ? chunks.length : 0,
            messageCount: source.keys
                .where((key) => !key.startsWith('@'))
                .length,
            codePointCount: codePointCount,
            errorCode: null,
            quarantineState: 'consumed',
          );
        } on GoogleTranslationDraftFailure catch (error) {
          return GoogleTranslationDraftLocaleResult(
            locale: entry.locale,
            passed: false,
            requestCount: operation == 'translate' ? chunks.length : 0,
            messageCount: source.keys
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
          return GoogleTranslationDraftLocaleResult(
            locale: entry.locale,
            passed: false,
            requestCount: operation == 'translate' ? chunks.length : 0,
            messageCount: source.keys
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
        'workflow': googleTranslationDraftWorkflow,
        'operation': operation,
        'passed': passed,
        'provider': 'google_cloud_translation_advanced_v3',
        'localeCount': results.length,
        'passedCount': results.where((result) => result.passed).length,
        'failedCount': results.where((result) => !result.passed).length,
        'locales': results.map((result) => result.toJson()).toList(),
        'humanReviewRequired': true,
        'runtimeActivated': false,
        'externalRequestMade': operation == 'translate',
        'recoverablePrivateQuarantineEnabled': true,
      }),
    );
    if (!passed) exitCode = 65;
  } on GoogleTranslationDraftFailure catch (error) {
    stderr.writeln(
      'Google translation draft failed: ${error.allCodes.join(',')}',
    );
    exitCode = 65;
  } on Object {
    stderr.writeln('Google translation draft failed: invalid_local_input');
    exitCode = 66;
  }
}

final class _GoogleTranslationRestClient {
  _GoogleTranslationRestClient({
    required this.projectId,
    required this.location,
    required this.modelResource,
    required this.accessToken,
  });

  final String projectId;
  final String location;
  final String modelResource;
  final String accessToken;
  final HttpClient _client = HttpClient();

  Future<List<String>> translate({
    required String locale,
    required String glossary,
    required List<String> contents,
  }) async {
    try {
      final uri = Uri.https(
        'translation.googleapis.com',
        '/v3/projects/$projectId/locations/$location:translateText',
      );
      final request = await _client.postUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set('x-goog-user-project', projectId);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'sourceLanguageCode': 'en',
          'targetLanguageCode': locale,
          'mimeType': 'text/plain',
          'contents': contents,
          'model': modelResource,
          'glossaryConfig': {'glossary': glossary, 'ignoreCase': false},
          'labels': {'workflow': 'focushaven_locale_draft'},
        }),
      );
      final response = await request.close();
      final responseText = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GoogleTranslationDraftFailure(
          'provider_http_${response.statusCode}',
        );
      }
      final decoded = jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) {
        throw const GoogleTranslationDraftFailure(
          'provider_response_schema_mismatch',
        );
      }
      final values = decoded['glossaryTranslations'];
      if (values is! List) {
        throw const GoogleTranslationDraftFailure(
          'provider_glossary_response_missing',
        );
      }
      final translations = <String>[];
      for (final value in values) {
        if (value is! Map<String, dynamic> ||
            value['translatedText'] is! String) {
          throw const GoogleTranslationDraftFailure(
            'provider_response_schema_mismatch',
          );
        }
        translations.add(value['translatedText'] as String);
      }
      return translations;
    } on GoogleTranslationDraftFailure {
      rethrow;
    } on Object {
      throw const GoogleTranslationDraftFailure('provider_transport_failure');
    }
  }

  void close() => _client.close(force: true);
}

Future<String> _googleAccessToken() async {
  try {
    final result = await Process.run('gcloud', [
      'auth',
      'print-access-token',
      '--quiet',
    ]);
    final token = result.stdout.toString().trim();
    if (result.exitCode != 0 || token.isEmpty) {
      throw const GoogleTranslationDraftFailure('authentication_unavailable');
    }
    return token;
  } on GoogleTranslationDraftFailure {
    rethrow;
  } on Object {
    throw const GoogleTranslationDraftFailure('authentication_unavailable');
  }
}

void _verifySourceAndPlans(StreamlinedLocaleBatchManifest manifest) {
  final source = File(manifest.sourceCatalog);
  if (!source.existsSync() ||
      _sha256File(source.path) != manifest.sourceCatalogSha256) {
    throw const GoogleTranslationDraftFailure('source_lock_mismatch');
  }
  for (final entry in manifest.locales) {
    if (!File(entry.planPath).existsSync()) {
      throw GoogleTranslationDraftFailure('missing_plan:${entry.locale}');
    }
    final plan = StreamlinedLocalePlan.fromJson(_jsonObject(entry.planPath));
    if (plan.locale != entry.locale ||
        plan.sourceCatalogSha256 != manifest.sourceCatalogSha256) {
      throw GoogleTranslationDraftFailure(
        'plan_manifest_lock_mismatch:${entry.locale}',
      );
    }
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
    '${Platform.pathSeparator}focushaven-$locale-quarantine.json';

void _refuseExistingDraftState(
  StreamlinedLocaleBatchManifest manifest,
  String outputDirectory,
) {
  for (final entry in manifest.locales) {
    final outputPath = entry.translationBundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    if (File(outputPath).existsSync() || Directory(outputPath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'refusing_existing_output:${entry.locale}',
      );
    }
    if (File(quarantinePath).existsSync() ||
        Directory(quarantinePath).existsSync()) {
      throw GoogleTranslationDraftFailure(
        'refusing_existing_quarantine:${entry.locale}',
      );
    }
  }
}

void _requireResumableDraftState(
  StreamlinedLocaleBatchManifest manifest,
  String outputDirectory,
) {
  for (final entry in manifest.locales) {
    final outputPath = entry.translationBundlePath(outputDirectory);
    final quarantinePath = _quarantinePath(outputDirectory, entry.locale);
    final hasOutput = File(outputPath).existsSync();
    final hasQuarantine = File(quarantinePath).existsSync();
    if (Directory(outputPath).existsSync() ||
        Directory(quarantinePath).existsSync() ||
        hasOutput == hasQuarantine) {
      throw GoogleTranslationDraftFailure(
        'invalid_resume_state:${entry.locale}',
      );
    }
  }
}

void _writeNew(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.createSync(exclusive: true);
  try {
    file.writeAsStringSync(contents, flush: true);
  } on Object {
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}

void _writePrivateNew(String path, String contents) {
  _writeNew(path, contents);
  final result = Process.runSync('chmod', ['600', path]);
  if (result.exitCode != 0) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    throw const GoogleTranslationDraftFailure(
      'private_output_permission_failure',
    );
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
    throw FormatException('$path must contain a JSON object.');
  }
  return decoded;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
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
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  final actual = json.keys.toSet();
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
  dart run tool/localization_google_translate_drafts.dart preflight <batch.json> <private-provider-config.json> <private-output-directory>
  dart run tool/localization_google_translate_drafts.dart translate <batch.json> <private-provider-config.json> <private-output-directory>
  dart run tool/localization_google_translate_drafts.dart resume <batch.json> <private-provider-config.json> <private-output-directory>
''');
}
