import 'dart:convert';
import 'dart:io';

import 'localization_streamlined_pipeline.dart';

const incrementalLocaleReviewWorkflow =
    'focus_haven_incremental_locale_review_v1';
const incrementalLocaleBundleWorkflow =
    'focus_haven_incremental_translation_bundle_v1';

final class IncrementalLocaleReviewEntry {
  const IncrementalLocaleReviewEntry({
    required this.locale,
    required this.englishName,
    required this.nativeName,
    required this.reviewScope,
    required this.runtimeCatalog,
    required this.runtimeCatalogSha256,
    required this.exceptionalGates,
  });

  factory IncrementalLocaleReviewEntry.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'locale',
      'englishName',
      'nativeName',
      'reviewScope',
      'runtimeCatalog',
      'runtimeCatalogSha256',
      'exceptionalGates',
    }, 'incremental locale');
    final locale = _requiredString(json, 'locale');
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(locale) ||
        locale == 'en') {
      throw const FormatException(
        'Incremental review locales must be canonical non-English tags.',
      );
    }
    final arbLocale = locale.replaceAll('-', '_');
    final runtimeCatalog = _requiredString(json, 'runtimeCatalog');
    if (runtimeCatalog != 'lib/l10n/app_$arbLocale.arb') {
      throw FormatException(
        '$locale runtimeCatalog must be lib/l10n/app_$arbLocale.arb.',
      );
    }
    return IncrementalLocaleReviewEntry(
      locale: locale,
      englishName: _requiredString(json, 'englishName'),
      nativeName: _requiredString(json, 'nativeName'),
      reviewScope: _requiredString(json, 'reviewScope'),
      runtimeCatalog: runtimeCatalog,
      runtimeCatalogSha256: _requiredDigest(json, 'runtimeCatalogSha256'),
      exceptionalGates: parseStreamlinedLocaleExceptionalGates(
        json['exceptionalGates'],
      ),
    );
  }

  final String locale;
  final String englishName;
  final String nativeName;
  final String reviewScope;
  final String runtimeCatalog;
  final String runtimeCatalogSha256;
  final Map<String, bool> exceptionalGates;

  String get arbLocale => locale.replaceAll('-', '_');

  String bundlePath(String directory) =>
      _join(directory, 'focushaven-$locale-incremental-translations.json');

  String reviewPath(String directory) =>
      _join(directory, 'focushaven-$locale-incremental-review.csv');

  String approvedPath(String directory) =>
      _join(directory, 'app_$arbLocale.incremental.approved.arb');

  String validationPath(String directory) =>
      _join(directory, '$locale.incremental-validation.json');
}

final class IncrementalDerivedFallback {
  const IncrementalDerivedFallback({
    required this.reviewedLocale,
    required this.fallbackLocale,
    required this.runtimeCatalog,
    required this.runtimeCatalogSha256,
  });

  factory IncrementalDerivedFallback.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'reviewedLocale',
      'fallbackLocale',
      'runtimeCatalog',
      'runtimeCatalogSha256',
    }, 'derived fallback');
    final reviewedLocale = _requiredString(json, 'reviewedLocale');
    final fallbackLocale = _requiredString(json, 'fallbackLocale');
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(reviewedLocale) ||
        !RegExp(r'^[a-z]{2,3}$').hasMatch(fallbackLocale) ||
        reviewedLocale == fallbackLocale) {
      throw const FormatException(
        'Derived fallback locale identity is invalid.',
      );
    }
    final runtimeCatalog = _requiredString(json, 'runtimeCatalog');
    if (runtimeCatalog != 'lib/l10n/app_$fallbackLocale.arb') {
      throw FormatException(
        '$fallbackLocale fallback runtimeCatalog must be '
        'lib/l10n/app_$fallbackLocale.arb.',
      );
    }
    return IncrementalDerivedFallback(
      reviewedLocale: reviewedLocale,
      fallbackLocale: fallbackLocale,
      runtimeCatalog: runtimeCatalog,
      runtimeCatalogSha256: _requiredDigest(json, 'runtimeCatalogSha256'),
    );
  }

  final String reviewedLocale;
  final String fallbackLocale;
  final String runtimeCatalog;
  final String runtimeCatalogSha256;
}

final class IncrementalLocaleReviewManifest {
  const IncrementalLocaleReviewManifest({
    required this.deltaId,
    required this.sourceProposal,
    required this.sourceProposalSha256,
    required this.locales,
    required this.derivedFallbacks,
  });

  factory IncrementalLocaleReviewManifest.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'schemaVersion',
      'workflow',
      'deltaId',
      'sourceProposal',
      'sourceProposalSha256',
      'locales',
      'derivedFallbacks',
    }, 'incremental manifest');
    if (json['schemaVersion'] != 1 ||
        json['workflow'] != incrementalLocaleReviewWorkflow) {
      throw const FormatException('Unsupported incremental locale review.');
    }
    final deltaId = _requiredString(json, 'deltaId');
    if (!RegExp(r'^[a-z][a-z0-9-]{2,63}$').hasMatch(deltaId)) {
      throw const FormatException('deltaId is not canonical.');
    }
    final sourceProposal = _requiredString(json, 'sourceProposal');
    if (!sourceProposal.startsWith('localization/proposals/') ||
        !sourceProposal.endsWith('.arb') ||
        sourceProposal.contains('..')) {
      throw const FormatException(
        'sourceProposal must be an isolated localization/proposals ARB.',
      );
    }
    final localeValues = json['locales'];
    if (localeValues is! List ||
        localeValues.isEmpty ||
        localeValues.length > 20) {
      throw const FormatException(
        'Incremental review must contain from one through twenty locales.',
      );
    }
    final locales = <IncrementalLocaleReviewEntry>[];
    final localeTags = <String>{};
    for (final value in localeValues) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException(
          'Every incremental locale must be an object.',
        );
      }
      final entry = IncrementalLocaleReviewEntry.fromJson(value);
      if (!localeTags.add(entry.locale)) {
        throw FormatException('Duplicate incremental locale: ${entry.locale}.');
      }
      locales.add(entry);
    }
    final fallbackValues = json['derivedFallbacks'];
    if (fallbackValues is! List || fallbackValues.length > 10) {
      throw const FormatException('derivedFallbacks must be a bounded array.');
    }
    final derivedFallbacks = <IncrementalDerivedFallback>[];
    final fallbackTags = <String>{};
    for (final value in fallbackValues) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException(
          'Every derived fallback must be an object.',
        );
      }
      final fallback = IncrementalDerivedFallback.fromJson(value);
      if (!localeTags.contains(fallback.reviewedLocale) ||
          !fallbackTags.add(fallback.fallbackLocale)) {
        throw const FormatException(
          'Derived fallback must reference one reviewed locale exactly once.',
        );
      }
      derivedFallbacks.add(fallback);
    }
    return IncrementalLocaleReviewManifest(
      deltaId: deltaId,
      sourceProposal: sourceProposal,
      sourceProposalSha256: _requiredDigest(json, 'sourceProposalSha256'),
      locales: List.unmodifiable(locales),
      derivedFallbacks: List.unmodifiable(derivedFallbacks),
    );
  }

  final String deltaId;
  final String sourceProposal;
  final String sourceProposalSha256;
  final List<IncrementalLocaleReviewEntry> locales;
  final List<IncrementalDerivedFallback> derivedFallbacks;
}

final class IncrementalLocalePreflightResult {
  const IncrementalLocalePreflightResult({
    required this.errors,
    required this.messageCount,
    required this.metadataCount,
    required this.runtimeCatalogCount,
  });

  final List<String> errors;
  final int messageCount;
  final int metadataCount;
  final int runtimeCatalogCount;

  bool get passed => errors.isEmpty;

  Map<String, dynamic> summary(IncrementalLocaleReviewManifest manifest) => {
    'schemaVersion': 1,
    'workflow': incrementalLocaleReviewWorkflow,
    'operation': 'preflight',
    'passed': passed,
    'deltaId': manifest.deltaId,
    'localeCount': manifest.locales.length,
    'derivedFallbackCount': manifest.derivedFallbacks.length,
    'messageCountPerLocale': messageCount,
    'metadataCount': metadataCount,
    'runtimeCatalogCount': runtimeCatalogCount,
    'errors': errors,
    'providerRequestMade': false,
    'reviewWorkbookCreated': false,
    'runtimeActivated': false,
  };
}

IncrementalLocalePreflightResult verifyIncrementalLocaleReview({
  required IncrementalLocaleReviewManifest manifest,
  required Map<String, dynamic> sourceProposal,
  required Map<String, Map<String, dynamic>> runtimeCatalogs,
  required Map<String, String> runtimeCatalogDigests,
}) {
  final errors = <String>[];
  final messageKeys = _messageKeys(sourceProposal);
  final metadataKeys = sourceProposal.keys
      .where((key) => key.startsWith('@') && key != '@@locale')
      .map((key) => key.substring(1))
      .toSet();
  if (sourceProposal['@@locale'] != 'en') {
    errors.add('invalid_source_proposal_locale');
  }
  if (messageKeys.isEmpty || messageKeys.length != metadataKeys.length) {
    errors.add('source_proposal_message_metadata_mismatch');
  }
  for (final key in messageKeys) {
    final value = sourceProposal[key];
    final metadata = sourceProposal['@$key'];
    if (value is! String ||
        value.trim().isEmpty ||
        metadata is! Map<String, dynamic> ||
        metadata['description'] is! String ||
        (metadata['description'] as String).trim().isEmpty) {
      errors.add('invalid_source_proposal_entry:$key');
    }
  }
  for (final entry in manifest.locales) {
    final catalog = runtimeCatalogs[entry.runtimeCatalog];
    if (catalog == null) {
      errors.add('missing_runtime_catalog:${entry.locale}');
      continue;
    }
    if (runtimeCatalogDigests[entry.runtimeCatalog] !=
        entry.runtimeCatalogSha256) {
      errors.add('runtime_catalog_lock_mismatch:${entry.locale}');
    }
    if (catalog['@@locale'] != entry.arbLocale) {
      errors.add('runtime_catalog_locale_mismatch:${entry.locale}');
    }
    final overlap = _messageKeys(catalog).intersection(messageKeys).toList()
      ..sort();
    for (final key in overlap) {
      errors.add('runtime_already_contains_delta:${entry.locale}:$key');
    }
  }
  for (final fallback in manifest.derivedFallbacks) {
    final catalog = runtimeCatalogs[fallback.runtimeCatalog];
    if (catalog == null) {
      errors.add('missing_fallback_catalog:${fallback.fallbackLocale}');
      continue;
    }
    if (runtimeCatalogDigests[fallback.runtimeCatalog] !=
        fallback.runtimeCatalogSha256) {
      errors.add('fallback_catalog_lock_mismatch:${fallback.fallbackLocale}');
    }
    if (catalog['@@locale'] != fallback.fallbackLocale) {
      errors.add('fallback_catalog_locale_mismatch:${fallback.fallbackLocale}');
    }
    final overlap = _messageKeys(catalog).intersection(messageKeys).toList()
      ..sort();
    for (final key in overlap) {
      errors.add(
        'fallback_already_contains_delta:${fallback.fallbackLocale}:$key',
      );
    }
  }
  return IncrementalLocalePreflightResult(
    errors: errors.toSet().toList()..sort(),
    messageCount: messageKeys.length,
    metadataCount: metadataKeys.length,
    runtimeCatalogCount:
        manifest.locales.length + manifest.derivedFallbacks.length,
  );
}

StreamlinedPreparationResult prepareIncrementalLocaleReview({
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required Map<String, dynamic> sourceProposal,
  required Map<String, dynamic> translationBundle,
}) {
  final errors = <String>[];
  const expectedKeys = {
    'schemaVersion',
    'workflow',
    'deltaId',
    'locale',
    'sourceProposalSha256',
    'translations',
    'approvedSourceEqual',
  };
  if (translationBundle.keys.toSet().difference(expectedKeys).isNotEmpty ||
      expectedKeys.difference(translationBundle.keys.toSet()).isNotEmpty) {
    errors.add('incremental_bundle_schema_mismatch');
  }
  if (translationBundle['schemaVersion'] != 1 ||
      translationBundle['workflow'] != incrementalLocaleBundleWorkflow ||
      translationBundle['deltaId'] != manifest.deltaId ||
      translationBundle['locale'] != entry.locale ||
      translationBundle['sourceProposalSha256'] !=
          manifest.sourceProposalSha256) {
    errors.add('incremental_bundle_identity_mismatch');
  }
  final normalizedBundle = <String, dynamic>{
    'schemaVersion': 1,
    'workflow': streamlinedLocaleWorkflow,
    'locale': entry.locale,
    'sourceCatalogSha256': manifest.sourceProposalSha256,
    'translations': translationBundle['translations'],
    'approvedSourceEqual': translationBundle['approvedSourceEqual'],
  };
  final result = prepareStreamlinedLocale(
    plan: incrementalLocalePlanFor(manifest, entry),
    source: sourceProposal,
    translationBundle: normalizedBundle,
  );
  return StreamlinedPreparationResult(
    errors: {...errors, ...result.errors}.toList()..sort(),
    candidate: result.candidate,
    qualification: result.qualification,
    contentSafety: result.contentSafety,
    reviewRows: result.reviewRows,
    approvedSourceEqual: result.approvedSourceEqual,
  );
}

StreamlinedAcceptanceResult acceptIncrementalLocaleReview({
  required IncrementalLocaleReviewManifest manifest,
  required IncrementalLocaleReviewEntry entry,
  required Map<String, dynamic> sourceProposal,
  required Map<String, dynamic> translationBundle,
  required List<Map<String, String>> reviewRows,
}) {
  final prepared = prepareIncrementalLocaleReview(
    manifest: manifest,
    entry: entry,
    sourceProposal: sourceProposal,
    translationBundle: translationBundle,
  );
  if (!prepared.passed) {
    return StreamlinedAcceptanceResult(
      errors: prepared.errors,
      approvedCatalog: prepared.candidate,
      qualification: prepared.qualification,
      contentSafety: prepared.contentSafety,
      decisionCounts: const {'accepted': 0, 'revised': 0, 'blocked': 0},
      riskCounts: const {'critical': 0, 'elevated': 0, 'standard': 0},
      reviewApprovedSourceEqual: const [],
    );
  }
  return acceptStreamlinedLocaleReview(
    plan: incrementalLocalePlanFor(manifest, entry),
    source: sourceProposal,
    candidate: prepared.candidate,
    approvedSourceEqual: prepared.approvedSourceEqual,
    reviewRows: reviewRows,
  );
}

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2 ||
      !const {'preflight', 'prepare', 'accept'}.contains(arguments.first)) {
    _usage();
    exitCode = 64;
    return;
  }
  try {
    final operation = arguments.first;
    final manifest = IncrementalLocaleReviewManifest.fromJson(
      _jsonObject(arguments[1]),
    );
    final source = _jsonObject(manifest.sourceProposal);
    final runtimeCatalogs = <String, Map<String, dynamic>>{};
    final runtimeDigests = <String, String>{};
    for (final path in {
      ...manifest.locales.map((entry) => entry.runtimeCatalog),
      ...manifest.derivedFallbacks.map((entry) => entry.runtimeCatalog),
    }) {
      runtimeCatalogs[path] = _jsonObject(path);
      runtimeDigests[path] = _sha256File(path);
    }
    if (_sha256File(manifest.sourceProposal) != manifest.sourceProposalSha256) {
      throw const FormatException('Source proposal lock mismatch.');
    }
    final preflight = verifyIncrementalLocaleReview(
      manifest: manifest,
      sourceProposal: source,
      runtimeCatalogs: runtimeCatalogs,
      runtimeCatalogDigests: runtimeDigests,
    );
    if (!preflight.passed) {
      stdout.write(_prettyJson(preflight.summary(manifest)));
      exitCode = 65;
      return;
    }
    if (operation == 'preflight') {
      if (arguments.length != 2) {
        _usage();
        exitCode = 64;
        return;
      }
      stdout.write(_prettyJson(preflight.summary(manifest)));
      return;
    }
    if ((operation == 'prepare' && arguments.length != 4) ||
        (operation == 'accept' && arguments.length != 5)) {
      _usage();
      exitCode = 64;
      return;
    }
    final bundleDirectory = arguments[2];
    final reviewDirectory = arguments[3];
    final approvalDirectory = operation == 'accept' ? arguments[4] : '';
    _requirePrivateDirectory(bundleDirectory);
    _requirePrivateDirectory(reviewDirectory);
    if (operation == 'accept') {
      _requirePrivateDirectory(approvalDirectory);
    }

    final summaries = <Map<String, dynamic>>[];
    var allPassed = true;
    for (final entry in manifest.locales) {
      final bundle = _jsonObject(entry.bundlePath(bundleDirectory));
      if (operation == 'prepare') {
        final result = prepareIncrementalLocaleReview(
          manifest: manifest,
          entry: entry,
          sourceProposal: source,
          translationBundle: bundle,
        );
        if (!result.passed) {
          allPassed = false;
        } else {
          _writePrivateNew(
            entry.reviewPath(reviewDirectory),
            encodePrivateReviewCsv(result.reviewRows),
          );
        }
        summaries.add({
          'locale': entry.locale,
          'passed': result.passed,
          'errors': result.errors,
          'messageCount': result.reviewRows.length,
          'contentSafety': result.contentSafety.summary(),
        });
      } else {
        final reviewRows = decodePrivateReviewCsv(
          File(entry.reviewPath(reviewDirectory)).readAsStringSync(),
        );
        final result = acceptIncrementalLocaleReview(
          manifest: manifest,
          entry: entry,
          sourceProposal: source,
          translationBundle: bundle,
          reviewRows: reviewRows,
        );
        if (!result.passed) {
          allPassed = false;
        } else {
          _writePrivateNew(
            entry.approvedPath(approvalDirectory),
            _prettyJson(result.approvedCatalog),
          );
          _writePrivateNew(
            entry.validationPath(approvalDirectory),
            _prettyJson({
              'schemaVersion': 1,
              'workflow': incrementalLocaleReviewWorkflow,
              'operation': 'accept',
              'deltaId': manifest.deltaId,
              'locale': entry.locale,
              'sourceProposalSha256': manifest.sourceProposalSha256,
              'messageCount': result.qualification.sourceMessageCount,
              'decisionCounts': result.decisionCounts,
              'riskCounts': result.riskCounts,
              'reviewApprovedSourceEqual': result.reviewApprovedSourceEqual,
              'contentSafety': result.contentSafety.summary(),
              'reviewerIdentityRecorded': false,
              'runtimeActivated': false,
            }),
          );
        }
        summaries.add({
          'locale': entry.locale,
          'passed': result.passed,
          'errors': result.errors,
          'messageCount': result.qualification.sourceMessageCount,
          'decisionCounts': result.decisionCounts,
          'contentSafety': result.contentSafety.summary(),
        });
      }
    }
    stdout.write(
      _prettyJson({
        'schemaVersion': 1,
        'workflow': incrementalLocaleReviewWorkflow,
        'operation': operation,
        'passed': allPassed,
        'deltaId': manifest.deltaId,
        'localeCount': manifest.locales.length,
        'passedCount': summaries.where((item) => item['passed'] == true).length,
        'failedCount': summaries.where((item) => item['passed'] != true).length,
        'messageCountPerLocale': preflight.messageCount,
        'locales': summaries,
        'providerRequestMade': false,
        'reviewerIdentityRecorded': false,
        'runtimeActivated': false,
      }),
    );
    if (!allPassed) exitCode = 65;
  } on Object catch (error) {
    stderr.writeln('Incremental locale review failed: $error');
    exitCode = 66;
  }
}

StreamlinedLocalePlan incrementalLocalePlanFor(
  IncrementalLocaleReviewManifest manifest,
  IncrementalLocaleReviewEntry entry,
) => StreamlinedLocalePlan(
  locale: entry.locale,
  englishName: entry.englishName,
  nativeName: entry.nativeName,
  reviewScope: entry.reviewScope,
  sourceCatalog: manifest.sourceProposal,
  sourceCatalogSha256: manifest.sourceProposalSha256,
  candidateCatalog: 'private/${manifest.deltaId}/${entry.locale}/candidate.arb',
  structuralAudit:
      'private/${manifest.deltaId}/${entry.locale}/structural-audit.json',
  approvedCatalog: 'private/${manifest.deltaId}/${entry.locale}/approved.arb',
  validationRecord:
      'private/${manifest.deltaId}/${entry.locale}/validation.json',
  runtimeCatalog: entry.runtimeCatalog,
  exceptionalGates: entry.exceptionalGates,
);

Set<String> _messageKeys(Map<String, dynamic> catalog) =>
    catalog.keys.where((key) => !key.startsWith('@')).toSet();

Map<String, dynamic> _jsonObject(String path) {
  final value = jsonDecode(File(path).readAsStringSync());
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must contain one JSON object.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String _requiredDigest(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$key must be a lowercase SHA-256 digest.');
  }
  return value;
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw FormatException('$label has an invalid schema.');
  }
}

String _sha256File(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) throw StateError('Unable to hash $path.');
  return (result.stdout as String).trim().split(RegExp(r'\s+')).first;
}

String _join(String directory, String filename) =>
    '${directory.endsWith(Platform.pathSeparator) ? directory.substring(0, directory.length - 1) : directory}${Platform.pathSeparator}$filename';

void _requirePrivateDirectory(String path) {
  final repository = Directory.current.absolute.path;
  final absolute = Directory(path).absolute.path;
  if (absolute == repository ||
      absolute.startsWith('$repository${Platform.pathSeparator}')) {
    throw const FormatException(
      'Incremental bundles, reviews, and approvals must remain private.',
    );
  }
}

void _writePrivateNew(String path, String contents) {
  final file = File(path);
  if (file.existsSync()) {
    throw StateError('Refusing to overwrite private output: $path');
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['600', file.path]);
  }
}

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _usage() {
  stderr.writeln(
    '''Usage:
  dart run tool/localization_incremental_review.dart preflight <incremental-manifest.json>
  dart run tool/localization_incremental_review.dart prepare <incremental-manifest.json> <private-bundle-directory> <private-review-directory>
  dart run tool/localization_incremental_review.dart accept <incremental-manifest.json> <private-bundle-directory> <pipeline-ready-private-review-directory> <private-approval-directory>''',
  );
}
