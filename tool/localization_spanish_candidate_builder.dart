import 'dart:convert';
import 'dart:io';

import 'localization_catalog_qualification.dart';

const spanishCandidatePhase = '215G-C1A';
const spanishCandidateLocale = 'es';
const spanishSourceCommit = 'fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc';
const spanishSourceCatalogSha256 =
    'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87';
const spanishSourceCatalog = 'lib/l10n/app_en.arb';
const spanishCandidateOutput = 'localization/candidates/app_es.arb';

final class SpanishCandidatePreparationResult {
  const SpanishCandidatePreparationResult({
    required this.phaseMatches,
    required this.localeMatches,
    required this.sourceCommitMatches,
    required this.sourceCatalogSha256Matches,
    required this.missingTranslations,
    required this.extraTranslations,
    required this.invalidTranslations,
    required this.invalidSourceEqualDecisions,
    required this.qualification,
    required this.candidate,
  });

  final bool phaseMatches;
  final bool localeMatches;
  final bool sourceCommitMatches;
  final bool sourceCatalogSha256Matches;
  final List<String> missingTranslations;
  final List<String> extraTranslations;
  final List<String> invalidTranslations;
  final List<String> invalidSourceEqualDecisions;
  final CatalogQualificationResult qualification;
  final Map<String, dynamic> candidate;

  bool get readyToWrite =>
      phaseMatches &&
      localeMatches &&
      sourceCommitMatches &&
      sourceCatalogSha256Matches &&
      missingTranslations.isEmpty &&
      extraTranslations.isEmpty &&
      invalidTranslations.isEmpty &&
      invalidSourceEqualDecisions.isEmpty &&
      qualification.readyForHumanReview(
        expectedCandidateLocale: spanishCandidateLocale,
      );

  Map<String, Object?> toJson() => {
    'phase': spanishCandidatePhase,
    'candidateLocale': spanishCandidateLocale,
    'phaseMatches': phaseMatches,
    'localeMatches': localeMatches,
    'sourceCommitMatches': sourceCommitMatches,
    'sourceCatalogSha256Matches': sourceCatalogSha256Matches,
    'missingTranslations': missingTranslations,
    'extraTranslations': extraTranslations,
    'invalidTranslations': invalidTranslations,
    'invalidSourceEqualDecisions': invalidSourceEqualDecisions,
    'qualification': qualification.toJson(
      expectedCandidateLocale: spanishCandidateLocale,
    ),
    'readyToWrite': readyToWrite,
  };
}

SpanishCandidatePreparationResult prepareSpanishCandidate({
  required Map<String, dynamic> source,
  required Map<String, dynamic> translationBundle,
}) {
  final sourceKeys = source.keys.where((key) => !key.startsWith('@')).toSet();
  final translations = _stringMap(translationBundle['translations']);
  final sourceEqualDecisions = _stringMap(
    translationBundle['approvedSourceEqual'],
  );
  final translationKeys = translations.keys.toSet();
  final missingTranslations = sourceKeys.difference(translationKeys).toList()
    ..sort();
  final extraTranslations = translationKeys.difference(sourceKeys).toList()
    ..sort();
  final invalidTranslations = <String>[];
  final invalidSourceEqualDecisions = <String>[];

  for (final key in translationKeys.intersection(sourceKeys).toList()..sort()) {
    final value = translations[key];
    if (value == null || value.trim().isEmpty || value.contains('\u0000')) {
      invalidTranslations.add(key);
    }
  }

  for (final entry in sourceEqualDecisions.entries) {
    final sourceValue = source[entry.key];
    final translatedValue = translations[entry.key];
    if (!sourceKeys.contains(entry.key) ||
        sourceValue is! String ||
        translatedValue != sourceValue ||
        entry.value.trim().isEmpty) {
      invalidSourceEqualDecisions.add(entry.key);
    }
  }
  invalidSourceEqualDecisions.sort();

  final candidate = <String, dynamic>{'@@locale': spanishCandidateLocale};
  for (final key in sourceKeys.toList()..sort()) {
    candidate[key] = translations[key] ?? '';
    final metadata = source['@$key'];
    if (metadata != null) {
      candidate['@$key'] = _copyJson(metadata);
    }
  }

  final qualification = auditLocalizationCandidate(
    source: source,
    candidate: candidate,
    approvedSourceEqualKeys: sourceEqualDecisions.keys.toSet(),
  );

  return SpanishCandidatePreparationResult(
    phaseMatches: translationBundle['phase'] == spanishCandidatePhase,
    localeMatches: translationBundle['locale'] == spanishCandidateLocale,
    sourceCommitMatches:
        translationBundle['sourceCommit'] == spanishSourceCommit,
    sourceCatalogSha256Matches:
        translationBundle['sourceCatalogSha256'] == spanishSourceCatalogSha256,
    missingTranslations: missingTranslations,
    extraTranslations: extraTranslations,
    invalidTranslations: invalidTranslations..sort(),
    invalidSourceEqualDecisions: invalidSourceEqualDecisions,
    qualification: qualification,
    candidate: candidate,
  );
}

bool isIsolatedSpanishCandidateOutput(String outputPath) =>
    File(outputPath).absolute.path ==
    File(spanishCandidateOutput).absolute.path;

bool isLockedEnglishSourcePath(String sourcePath) =>
    File(sourcePath).absolute.path == File(spanishSourceCatalog).absolute.path;

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return <String, String>{
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

Object? _copyJson(Object? value) => jsonDecode(jsonEncode(value));

Map<String, dynamic> _readJsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON root must be an object.');
  }
  return decoded;
}

String _sha256File(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) {
    throw StateError('Unable to calculate the source catalog SHA-256.');
  }
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/localization_spanish_candidate_builder.dart '
      '<source.arb> <translation-bundle.json> '
      'localization/candidates/app_es.arb',
    );
    exitCode = 64;
    return;
  }

  final sourcePath = arguments[0];
  final bundlePath = arguments[1];
  final outputPath = arguments[2];

  if (!isLockedEnglishSourcePath(sourcePath)) {
    stderr.writeln('Source catalog refused: use only $spanishSourceCatalog.');
    exitCode = 73;
    return;
  }

  if (!isIsolatedSpanishCandidateOutput(outputPath)) {
    stderr.writeln(
      'Candidate output refused: use only $spanishCandidateOutput.',
    );
    exitCode = 73;
    return;
  }

  final output = File(outputPath);
  if (output.existsSync()) {
    stderr.writeln(
      'Candidate output refused: $spanishCandidateOutput already exists.',
    );
    exitCode = 73;
    return;
  }

  try {
    if (_sha256File(sourcePath) != spanishSourceCatalogSha256) {
      stderr.writeln(
        'Source catalog refused: the locked SHA-256 does not match.',
      );
      exitCode = 66;
      return;
    }
    final result = prepareSpanishCandidate(
      source: _readJsonObject(sourcePath),
      translationBundle: _readJsonObject(bundlePath),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    if (!result.readyToWrite) {
      stderr.writeln(
        'Candidate output refused: the translation bundle is not structurally ready.',
      );
      exitCode = 66;
      return;
    }

    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(result.candidate)}\n',
    );
    stdout.writeln('Created isolated candidate: $spanishCandidateOutput');
  } on Object catch (error) {
    stderr.writeln('Spanish candidate preparation failed: $error');
    exitCode = 65;
  }
}
