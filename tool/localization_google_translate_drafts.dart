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
const googleTranslationDraftMimeType = 'text/html';
const _googleTranslationIcuTokenPrefix = 'FHICU';

final class GoogleTranslationProtectedMessage {
  const GoogleTranslationProtectedMessage({
    required this.html,
    required this.syntaxTokens,
  });

  final String html;
  final List<String> syntaxTokens;
}

GoogleTranslationProtectedMessage protectGoogleTranslationIcu(String source) {
  if (source.contains(_googleTranslationIcuTokenPrefix)) {
    throw const GoogleTranslationDraftFailure('source_uses_reserved_icu_token');
  }
  return _GoogleTranslationIcuShield(source).build();
}

String restoreGoogleTranslationIcu({
  required GoogleTranslationProtectedMessage protected,
  required String providerHtml,
}) {
  var restored = providerHtml;
  for (var index = 0; index < protected.syntaxTokens.length; index += 1) {
    final marker = _googleTranslationIcuMarker(index);
    final span = RegExp(
      '<span\\b[^>]*>\\s*${RegExp.escape(marker)}\\s*</span>',
      caseSensitive: false,
    );
    if (span.allMatches(restored).length != 1) {
      throw const GoogleTranslationDraftFailure('provider_icu_marker_mismatch');
    }
    restored = restored.replaceFirst(span, protected.syntaxTokens[index]);
  }
  if (restored.contains(_googleTranslationIcuTokenPrefix) ||
      RegExp(r'</?[A-Za-z][^>]*>').hasMatch(restored)) {
    throw const GoogleTranslationDraftFailure('provider_html_mismatch');
  }
  return _decodeGoogleTranslationHtml(restored);
}

String _googleTranslationIcuMarker(int index) =>
    '$_googleTranslationIcuTokenPrefix${index.toString().padLeft(4, '0')}X';

final class _GoogleTranslationIcuShield {
  _GoogleTranslationIcuShield(this.source);

  final String source;
  final List<String> _syntaxTokens = [];

  GoogleTranslationProtectedMessage build() =>
      GoogleTranslationProtectedMessage(
        html: _shieldRange(0, source.length),
        syntaxTokens: List<String>.unmodifiable(_syntaxTokens),
      );

  String _shieldRange(int start, int end) {
    final result = StringBuffer();
    var cursor = start;
    while (cursor < end) {
      if (source.codeUnitAt(cursor) == 0x7b) {
        final argument = _shieldArgument(cursor, end);
        if (argument != null) {
          result.write(argument.html);
          cursor = argument.end;
          continue;
        }
      }
      final textStart = cursor;
      cursor += 1;
      while (cursor < end && source.codeUnitAt(cursor) != 0x7b) {
        cursor += 1;
      }
      result.write(
        _escapeGoogleTranslationHtml(source.substring(textStart, cursor)),
      );
    }
    return result.toString();
  }

  _ShieldedIcuArgument? _shieldArgument(int openingBrace, int end) {
    final closingBrace = _matchingBrace(openingBrace, end);
    if (closingBrace < 0) return null;
    final tokenCheckpoint = _syntaxTokens.length;

    var cursor = _skipWhitespace(openingBrace + 1, closingBrace);
    final nameStart = cursor;
    cursor = _scanIdentifier(cursor, closingBrace);
    if (cursor == nameStart) return null;
    cursor = _skipWhitespace(cursor, closingBrace);
    if (cursor == closingBrace) {
      return _protectWholeArgument(openingBrace, closingBrace, tokenCheckpoint);
    }
    if (source.codeUnitAt(cursor) != 0x2c) {
      return _protectWholeArgument(openingBrace, closingBrace, tokenCheckpoint);
    }

    cursor = _skipWhitespace(cursor + 1, closingBrace);
    final typeStart = cursor;
    cursor = _scanIdentifier(cursor, closingBrace);
    final type = source.substring(typeStart, cursor).toLowerCase();
    cursor = _skipWhitespace(cursor, closingBrace);
    if (cursor == closingBrace ||
        source.codeUnitAt(cursor) != 0x2c ||
        !const {'plural', 'selectordinal', 'select'}.contains(type)) {
      return _protectWholeArgument(openingBrace, closingBrace, tokenCheckpoint);
    }

    final result = StringBuffer()
      ..write(_protectSyntax(source.substring(openingBrace, cursor + 1)));
    cursor += 1;
    while (cursor < closingBrace) {
      final whitespaceStart = cursor;
      cursor = _skipWhitespace(cursor, closingBrace);
      result.write(
        _escapeGoogleTranslationHtml(source.substring(whitespaceStart, cursor)),
      );
      if (cursor >= closingBrace) break;

      if (source.startsWith('offset:', cursor)) {
        final offsetStart = cursor;
        cursor += 'offset:'.length;
        while (cursor < closingBrace &&
            !_isWhitespace(source.codeUnitAt(cursor))) {
          cursor += 1;
        }
        result.write(_protectSyntax(source.substring(offsetStart, cursor)));
        continue;
      }

      final selectorStart = cursor;
      while (cursor < closingBrace &&
          !_isWhitespace(source.codeUnitAt(cursor)) &&
          source.codeUnitAt(cursor) != 0x7b) {
        cursor += 1;
      }
      cursor = _skipWhitespace(cursor, closingBrace);
      if (selectorStart == cursor ||
          cursor >= closingBrace ||
          source.codeUnitAt(cursor) != 0x7b) {
        return _protectWholeArgument(
          openingBrace,
          closingBrace,
          tokenCheckpoint,
        );
      }
      final branchOpening = cursor;
      final branchClosing = _matchingBrace(branchOpening, closingBrace);
      if (branchClosing < 0) {
        return _protectWholeArgument(
          openingBrace,
          closingBrace,
          tokenCheckpoint,
        );
      }
      result.write(
        _protectSyntax(source.substring(selectorStart, branchOpening + 1)),
      );
      result.write(_shieldRange(branchOpening + 1, branchClosing));
      result.write(_protectSyntax('}'));
      cursor = branchClosing + 1;
    }
    result.write(_protectSyntax('}'));
    return _ShieldedIcuArgument(html: result.toString(), end: closingBrace + 1);
  }

  _ShieldedIcuArgument _protectWholeArgument(
    int openingBrace,
    int closingBrace,
    int tokenCheckpoint,
  ) {
    if (_syntaxTokens.length > tokenCheckpoint) {
      _syntaxTokens.removeRange(tokenCheckpoint, _syntaxTokens.length);
    }
    return _ShieldedIcuArgument(
      html: _protectSyntax(source.substring(openingBrace, closingBrace + 1)),
      end: closingBrace + 1,
    );
  }

  int _matchingBrace(int openingBrace, int end) {
    var depth = 0;
    for (var cursor = openingBrace; cursor < end; cursor += 1) {
      final codeUnit = source.codeUnitAt(cursor);
      if (codeUnit == 0x7b) {
        depth += 1;
      } else if (codeUnit == 0x7d) {
        depth -= 1;
        if (depth == 0) return cursor;
      }
    }
    return -1;
  }

  int _skipWhitespace(int cursor, int end) {
    while (cursor < end && _isWhitespace(source.codeUnitAt(cursor))) {
      cursor += 1;
    }
    return cursor;
  }

  int _scanIdentifier(int cursor, int end) {
    while (cursor < end) {
      final codeUnit = source.codeUnitAt(cursor);
      final valid =
          (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
          (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
          (codeUnit >= 0x30 && codeUnit <= 0x39) ||
          codeUnit == 0x5f;
      if (!valid) break;
      cursor += 1;
    }
    return cursor;
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;

  String _protectSyntax(String syntax) {
    final marker = _googleTranslationIcuMarker(_syntaxTokens.length);
    _syntaxTokens.add(syntax);
    return '<span translate="no">$marker</span>';
  }
}

final class _ShieldedIcuArgument {
  const _ShieldedIcuArgument({required this.html, required this.end});

  final String html;
  final int end;
}

String _escapeGoogleTranslationHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _decodeGoogleTranslationHtml(String value) {
  var result = value.replaceAllMapped(RegExp(r'&#(x[0-9A-Fa-f]+|[0-9]+);'), (
    match,
  ) {
    final raw = match.group(1)!;
    final codePoint = raw.startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  result = result
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  return result;
}

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
    final isPortugueseRegionalMapping =
        locale == 'pt-BR' && targetLanguageCode == 'pt';
    if (targetLanguageCode != locale && !isPortugueseRegionalMapping) {
      throw FormatException(
        '$locale targetLanguageCode must exactly match the review locale, '
        'except that pt-BR uses Google target code pt.',
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
  bool protectIcuForProvider = false,
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
    final content = protectIcuForProvider
        ? protectGoogleTranslationIcu(value).html
        : value;
    final length = content.runes.length;
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
    contents.add(content);
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
    protectIcuForProvider: true,
  );
  for (final chunk in chunks) {
    final translated = await sender(
      locale: localeConfig.targetLanguageCode,
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
      final providerValue = translated[index];
      final value = restoreGoogleTranslationIcu(
        protected: protectGoogleTranslationIcu(source[key] as String),
        providerHtml: providerValue,
      );
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
    final sourceChunks = buildGoogleTranslationDraftChunks(
      source: source,
      maxCodePointsPerRequest: config.maxCodePointsPerRequest,
    );
    final providerChunks = buildGoogleTranslationDraftChunks(
      source: source,
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
          'requestCountPerLocale': providerChunks.length,
          'codePointCountPerLocale': codePointCount,
          'providerCodePointCountPerLocale': providerCodePointCount,
          'providerMimeType': googleTranslationDraftMimeType,
          'icuPlaceholderShielding': true,
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
        ? GoogleTranslationRestClient(
            projectId: config.projectId,
            location: config.location,
            modelResource: config.modelResource,
            accessToken: await googleTranslationAccessToken(),
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
            requestCount: operation == 'translate' ? providerChunks.length : 0,
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
            requestCount: operation == 'translate' ? providerChunks.length : 0,
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
            requestCount: operation == 'translate' ? providerChunks.length : 0,
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
        'providerMimeType': googleTranslationDraftMimeType,
        'icuPlaceholderShielding': true,
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

final class GoogleTranslationRestClient {
  GoogleTranslationRestClient({
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
          'mimeType': googleTranslationDraftMimeType,
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

Future<String> googleTranslationAccessToken() async {
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
