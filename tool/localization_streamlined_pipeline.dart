import 'dart:convert';
import 'dart:io';

import 'localization_catalog_qualification.dart';

const streamlinedLocaleWorkflow = 'focus_haven_streamlined_locale_v1';
const streamlinedLocaleSourceCatalog = 'lib/l10n/app_en.arb';

enum LocaleReviewRisk { critical, elevated, standard }

extension on LocaleReviewRisk {
  String get label => name;

  int get order => switch (this) {
    LocaleReviewRisk.critical => 0,
    LocaleReviewRisk.elevated => 1,
    LocaleReviewRisk.standard => 2,
  };
}

final class StreamlinedLocalePlan {
  const StreamlinedLocalePlan({
    required this.locale,
    required this.englishName,
    required this.nativeName,
    required this.reviewScope,
    required this.sourceCatalog,
    required this.sourceCatalogSha256,
    required this.candidateCatalog,
    required this.structuralAudit,
    required this.approvedCatalog,
    required this.validationRecord,
    required this.runtimeCatalog,
    required this.exceptionalGates,
  });

  factory StreamlinedLocalePlan.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['workflow'] != streamlinedLocaleWorkflow) {
      throw const FormatException('Unsupported streamlined-locale plan.');
    }

    final locale = _requiredString(json, 'locale');
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(locale)) {
      throw const FormatException('Locale must be a canonical language tag.');
    }

    final exceptionalGatesValue = json['exceptionalGates'];
    if (exceptionalGatesValue is! Map<String, dynamic>) {
      throw const FormatException('exceptionalGates must be an object.');
    }
    const exceptionalGateNames = {
      'rightToLeft',
      'fontCoverage',
      'physicalScreenReader',
      'physicalSpeechRecognition',
      'storePromotion',
    };
    if (exceptionalGatesValue.keys
            .toSet()
            .difference(exceptionalGateNames)
            .isNotEmpty ||
        exceptionalGateNames
            .difference(exceptionalGatesValue.keys.toSet())
            .isNotEmpty ||
        exceptionalGatesValue.values.any((value) => value is! bool)) {
      throw const FormatException('exceptionalGates has an invalid schema.');
    }

    final plan = StreamlinedLocalePlan(
      locale: locale,
      englishName: _requiredString(json, 'englishName'),
      nativeName: _requiredString(json, 'nativeName'),
      reviewScope: _requiredString(json, 'reviewScope'),
      sourceCatalog: _requiredString(json, 'sourceCatalog'),
      sourceCatalogSha256: _requiredDigest(json, 'sourceCatalogSha256'),
      candidateCatalog: _requiredString(json, 'candidateCatalog'),
      structuralAudit: _requiredString(json, 'structuralAudit'),
      approvedCatalog: _requiredString(json, 'approvedCatalog'),
      validationRecord: _requiredString(json, 'validationRecord'),
      runtimeCatalog: _requiredString(json, 'runtimeCatalog'),
      exceptionalGates: exceptionalGatesValue.map(
        (key, value) => MapEntry(key, value as bool),
      ),
    );
    plan._validatePaths();
    return plan;
  }

  final String locale;
  final String englishName;
  final String nativeName;
  final String reviewScope;
  final String sourceCatalog;
  final String sourceCatalogSha256;
  final String candidateCatalog;
  final String structuralAudit;
  final String approvedCatalog;
  final String validationRecord;
  final String runtimeCatalog;
  final Map<String, bool> exceptionalGates;

  String get arbLocale => locale.replaceAll('-', '_');
  String get arbSuffix => arbLocale;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'workflow': streamlinedLocaleWorkflow,
    'locale': locale,
    'englishName': englishName,
    'nativeName': nativeName,
    'reviewScope': reviewScope,
    'sourceCatalog': sourceCatalog,
    'sourceCatalogSha256': sourceCatalogSha256,
    'candidateCatalog': candidateCatalog,
    'structuralAudit': structuralAudit,
    'approvedCatalog': approvedCatalog,
    'validationRecord': validationRecord,
    'runtimeCatalog': runtimeCatalog,
    'exceptionalGates': exceptionalGates,
  };

  void _validatePaths() {
    final expected = {
      'sourceCatalog': streamlinedLocaleSourceCatalog,
      'candidateCatalog': 'localization/candidates/app_$arbSuffix.arb',
      'structuralAudit': 'localization/reviews/$locale/structural-audit.json',
      'approvedCatalog':
          'localization/reviews/$locale/app_$arbSuffix.approved.arb',
      'validationRecord':
          'localization/reviews/$locale/private-human-validation.json',
      'runtimeCatalog': 'lib/l10n/app_$arbSuffix.arb',
    };
    final actual = {
      'sourceCatalog': sourceCatalog,
      'candidateCatalog': candidateCatalog,
      'structuralAudit': structuralAudit,
      'approvedCatalog': approvedCatalog,
      'validationRecord': validationRecord,
      'runtimeCatalog': runtimeCatalog,
    };
    for (final entry in expected.entries) {
      if (actual[entry.key] != entry.value) {
        throw FormatException('${entry.key} must be ${entry.value}.');
      }
    }
  }
}

final class StreamlinedPreparationResult {
  const StreamlinedPreparationResult({
    required this.errors,
    required this.candidate,
    required this.qualification,
    required this.reviewRows,
    required this.approvedSourceEqual,
  });

  final List<String> errors;
  final Map<String, dynamic> candidate;
  final CatalogQualificationResult qualification;
  final List<Map<String, String>> reviewRows;
  final Map<String, String> approvedSourceEqual;

  bool get passed => errors.isEmpty;

  Map<String, dynamic> summary(StreamlinedLocalePlan plan) => {
    'workflow': streamlinedLocaleWorkflow,
    'operation': 'prepare',
    'locale': plan.locale,
    'passed': passed,
    'errors': errors,
    'messageCount': qualification.sourceMessageCount,
    'placeholderMessageCount': qualification.sourcePlaceholderMessageCount,
    'sourceEqualInvariantCount': approvedSourceEqual.length,
    'riskCounts': _riskCounts(reviewRows),
  };
}

StreamlinedPreparationResult prepareStreamlinedLocale({
  required StreamlinedLocalePlan plan,
  required Map<String, dynamic> source,
  required Map<String, dynamic> translationBundle,
}) {
  final errors = <String>[];
  const bundleKeys = {
    'schemaVersion',
    'workflow',
    'locale',
    'sourceCatalogSha256',
    'translations',
    'approvedSourceEqual',
  };
  if (translationBundle.keys.toSet().difference(bundleKeys).isNotEmpty ||
      bundleKeys.difference(translationBundle.keys.toSet()).isNotEmpty) {
    errors.add('translation_bundle_schema_mismatch');
  }
  if (translationBundle['schemaVersion'] != 1 ||
      translationBundle['workflow'] != streamlinedLocaleWorkflow ||
      translationBundle['locale'] != plan.locale) {
    errors.add('translation_bundle_identity_mismatch');
  }
  if (translationBundle['sourceCatalogSha256'] != plan.sourceCatalogSha256) {
    errors.add('translation_bundle_source_lock_mismatch');
  }
  if (source['@@locale'] != 'en') {
    errors.add('invalid_source_locale');
  }

  final sourceKeys = _messageKeys(source);
  final translations = _strictStringMap(
    translationBundle['translations'],
    errors,
    'translations',
  );
  final approvedSourceEqual = _strictStringMap(
    translationBundle['approvedSourceEqual'],
    errors,
    'approvedSourceEqual',
  );
  final translationKeys = translations.keys.toSet();
  for (final key in sourceKeys.difference(translationKeys).toList()..sort()) {
    errors.add('missing_translation:$key');
  }
  for (final key in translationKeys.difference(sourceKeys).toList()..sort()) {
    errors.add('extra_translation:$key');
  }

  for (final key in translationKeys.intersection(sourceKeys).toList()..sort()) {
    final value = translations[key]!;
    if (value.trim().isEmpty || value.contains('\u0000')) {
      errors.add('invalid_translation:$key');
    }
  }
  for (final entry in approvedSourceEqual.entries) {
    if (source[entry.key] != translations[entry.key] ||
        entry.value.trim().isEmpty) {
      errors.add('invalid_source_equal_decision:${entry.key}');
    }
  }

  final candidate = <String, dynamic>{'@@locale': plan.arbLocale};
  for (final key in sourceKeys.toList()..sort()) {
    candidate[key] = translations[key] ?? '';
    final metadata = source['@$key'];
    if (metadata != null) candidate['@$key'] = _copyJson(metadata);
  }
  final qualification = auditLocalizationCandidate(
    source: source,
    candidate: candidate,
    approvedSourceEqualKeys: approvedSourceEqual.keys.toSet(),
  );
  if (!qualification.readyForHumanReview(
    expectedCandidateLocale: plan.arbLocale,
  )) {
    errors.add('candidate_not_structurally_ready');
  }

  final rows = <Map<String, String>>[];
  for (final key in sourceKeys) {
    final sourceText = source[key];
    final candidateText = candidate[key];
    final metadata = source['@$key'];
    if (sourceText is! String ||
        candidateText is! String ||
        metadata is! Map<String, dynamic>) {
      errors.add('invalid_review_row:$key');
      continue;
    }
    rows.add({
      'sequence': '0',
      'risk': _riskFor(key, sourceText, metadata).label,
      'key': key,
      'source': sourceText,
      'candidate': candidateText,
      'description': metadata['description'] is String
          ? metadata['description'] as String
          : '',
      'placeholders': (_placeholderNames(metadata).toList()..sort()).join('|'),
      'decision': '',
      'replacement': '',
    });
  }
  rows.sort((left, right) {
    final risk = _riskFromLabel(
      left['risk']!,
    ).order.compareTo(_riskFromLabel(right['risk']!).order);
    return risk != 0 ? risk : left['key']!.compareTo(right['key']!);
  });
  for (var index = 0; index < rows.length; index += 1) {
    rows[index]['sequence'] = '${index + 1}';
  }

  return StreamlinedPreparationResult(
    errors: errors.toSet().toList()..sort(),
    candidate: candidate,
    qualification: qualification,
    reviewRows: rows,
    approvedSourceEqual: approvedSourceEqual,
  );
}

final class StreamlinedAcceptanceResult {
  const StreamlinedAcceptanceResult({
    required this.errors,
    required this.approvedCatalog,
    required this.qualification,
    required this.decisionCounts,
    required this.riskCounts,
    required this.reviewApprovedSourceEqual,
  });

  final List<String> errors;
  final Map<String, dynamic> approvedCatalog;
  final CatalogQualificationResult qualification;
  final Map<String, int> decisionCounts;
  final Map<String, int> riskCounts;
  final List<String> reviewApprovedSourceEqual;

  bool get passed => errors.isEmpty;

  Map<String, dynamic> summary(StreamlinedLocalePlan plan) => {
    'workflow': streamlinedLocaleWorkflow,
    'operation': 'accept',
    'locale': plan.locale,
    'passed': passed,
    'errors': errors,
    'messageCount': qualification.sourceMessageCount,
    'decisionCounts': decisionCounts,
    'riskCounts': riskCounts,
    'reviewApprovedSourceEqualCount': reviewApprovedSourceEqual.length,
  };
}

StreamlinedAcceptanceResult acceptStreamlinedLocaleReview({
  required StreamlinedLocalePlan plan,
  required Map<String, dynamic> source,
  required Map<String, dynamic> candidate,
  required Map<String, String> approvedSourceEqual,
  required List<Map<String, String>> reviewRows,
}) {
  final errors = <String>[];
  final sourceKeys = _messageKeys(source);
  final candidateKeys = _messageKeys(candidate);
  final seen = <String>{};
  final replacements = <String, String>{};
  final reviewApprovedSourceEqual = <String>{};
  final orderedKeys = sourceKeys.toList()
    ..sort((left, right) {
      final leftMetadata =
          source['@$left'] as Map<String, dynamic>? ?? const {};
      final rightMetadata =
          source['@$right'] as Map<String, dynamic>? ?? const {};
      final leftRisk = _riskFor(
        left,
        source[left] as String? ?? '',
        leftMetadata,
      );
      final rightRisk = _riskFor(
        right,
        source[right] as String? ?? '',
        rightMetadata,
      );
      final riskComparison = leftRisk.order.compareTo(rightRisk.order);
      return riskComparison != 0 ? riskComparison : left.compareTo(right);
    });
  final expectedSequence = {
    for (var index = 0; index < orderedKeys.length; index += 1)
      orderedKeys[index]: '${index + 1}',
  };
  final decisions = <String, int>{'accepted': 0, 'revised': 0, 'blocked': 0};
  final risks = <String, int>{
    for (final risk in LocaleReviewRisk.values) risk.label: 0,
  };

  if (candidate['@@locale'] != plan.arbLocale ||
      !_setEqual(sourceKeys, candidateKeys)) {
    errors.add('candidate_identity_or_key_mismatch');
  }

  for (final row in reviewRows) {
    final key = row['key'] ?? '';
    if (!sourceKeys.contains(key) || !seen.add(key)) {
      errors.add('unexpected_or_duplicate_review_key:$key');
      continue;
    }
    if (row['source'] != source[key] || row['candidate'] != candidate[key]) {
      errors.add('review_copy_changed:$key');
    }
    if (row['sequence'] != expectedSequence[key]) {
      errors.add('review_sequence_changed:$key');
    }
    final expectedMetadata = source['@$key'];
    final expectedDescription =
        expectedMetadata is Map<String, dynamic> &&
            expectedMetadata['description'] is String
        ? expectedMetadata['description'] as String
        : '';
    final expectedPlaceholders = expectedMetadata is Map<String, dynamic>
        ? (_placeholderNames(expectedMetadata).toList()..sort()).join('|')
        : '';
    final expectedRisk =
        source[key] is String && expectedMetadata is Map<String, dynamic>
        ? _riskFor(key, source[key] as String, expectedMetadata).label
        : '';
    if (row['description'] != expectedDescription ||
        row['placeholders'] != expectedPlaceholders ||
        row['risk'] != expectedRisk) {
      errors.add('review_context_changed:$key');
    }
    if (risks.containsKey(expectedRisk)) {
      risks[expectedRisk] = risks[expectedRisk]! + 1;
    }

    final decision = (row['decision'] ?? '').trim().toUpperCase();
    final replacement = row['replacement'] ?? '';
    switch (decision) {
      case 'ACCEPT':
        decisions['accepted'] = decisions['accepted']! + 1;
        if (replacement.trim().isNotEmpty) {
          errors.add('accepted_row_has_replacement:$key');
        }
        break;
      case 'REVISE':
        decisions['revised'] = decisions['revised']! + 1;
        if (replacement.trim().isEmpty || replacement.contains('\u0000')) {
          errors.add('invalid_replacement:$key');
        } else {
          replacements[key] = replacement;
          if (replacement == source[key] &&
              !approvedSourceEqual.containsKey(key)) {
            reviewApprovedSourceEqual.add(key);
          }
        }
        break;
      case 'BLOCK':
        decisions['blocked'] = decisions['blocked']! + 1;
        errors.add('blocked_translation:$key');
        break;
      default:
        errors.add('missing_or_invalid_decision:$key');
    }
  }
  for (final key in sourceKeys.difference(seen).toList()..sort()) {
    errors.add('missing_review_decision:$key');
  }

  final approved = _copyJson(candidate) as Map<String, dynamic>;
  for (final replacement in replacements.entries) {
    approved[replacement.key] = replacement.value;
  }
  final qualification = auditLocalizationCandidate(
    source: source,
    candidate: approved,
    approvedSourceEqualKeys: {
      ...approvedSourceEqual.keys,
      ...reviewApprovedSourceEqual,
    },
  );
  if (!qualification.readyForHumanReview(
    expectedCandidateLocale: plan.arbLocale,
  )) {
    errors.add('reviewed_catalog_not_structurally_ready');
  }
  if (decisions['blocked'] != 0 ||
      decisions.values.fold<int>(0, (sum, value) => sum + value) !=
          sourceKeys.length) {
    errors.add('review_not_complete');
  }

  return StreamlinedAcceptanceResult(
    errors: errors.toSet().toList()..sort(),
    approvedCatalog: approved,
    qualification: qualification,
    decisionCounts: decisions,
    riskCounts: risks,
    reviewApprovedSourceEqual: reviewApprovedSourceEqual.toList()..sort(),
  );
}

const streamlinedReviewHeaders = <String>[
  'sequence',
  'risk',
  'key',
  'source',
  'candidate',
  'description',
  'placeholders',
  'decision',
  'replacement',
];

String encodePrivateReviewCsv(List<Map<String, String>> rows) {
  final lines = <String>[
    streamlinedReviewHeaders.map(_escapeCsv).join(','),
    for (final row in rows)
      streamlinedReviewHeaders
          .map((header) => _escapeCsv(row[header] ?? ''))
          .join(','),
  ];
  return '${lines.join('\r\n')}\r\n';
}

List<Map<String, String>> decodePrivateReviewCsv(String csv) {
  final normalized = csv.startsWith('\ufeff') ? csv.substring(1) : csv;
  final records = _parseCsv(normalized);
  if (records.isEmpty || !_listEqual(records.first, streamlinedReviewHeaders)) {
    throw const FormatException('Private review CSV headers are invalid.');
  }
  return [
    for (final record
        in records
            .skip(1)
            .where((record) => record.any((value) => value.isNotEmpty)))
      if (record.length == streamlinedReviewHeaders.length)
        {
          for (
            var index = 0;
            index < streamlinedReviewHeaders.length;
            index += 1
          )
            streamlinedReviewHeaders[index]: record[index],
        }
      else
        throw const FormatException('Private review CSV row width is invalid.'),
  ];
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    _usage();
    exitCode = 64;
    return;
  }
  try {
    switch (arguments.first) {
      case 'init':
        if (arguments.length != 5) {
          _badUsage();
          return;
        }
        _initializePlan(
          locale: arguments[1],
          englishName: arguments[2],
          nativeName: arguments[3],
          reviewScope: arguments[4],
        );
        return;
      case 'prepare':
        if (arguments.length != 4) {
          _badUsage();
          return;
        }
        _prepareCommand(arguments[1], arguments[2], arguments[3]);
        return;
      case 'accept':
        if (arguments.length != 3) {
          _badUsage();
          return;
        }
        _acceptCommand(arguments[1], arguments[2]);
        return;
      case 'verify':
        if (arguments.length != 2) {
          _badUsage();
          return;
        }
        _verifyCommand(arguments[1]);
        return;
      default:
        _badUsage();
        return;
    }
  } on Object catch (error) {
    stderr.writeln('Streamlined locale pipeline failed: $error');
    exitCode = 66;
  }
}

void _initializePlan({
  required String locale,
  required String englishName,
  required String nativeName,
  required String reviewScope,
}) {
  if (!RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(locale)) {
    throw const FormatException('Locale must look like fr or pt-BR.');
  }
  final arb = locale.replaceAll('-', '_');
  final source = File(streamlinedLocaleSourceCatalog);
  if (!source.existsSync()) {
    throw StateError('English source catalog is missing.');
  }
  final path = 'localization/plans/$locale.json';
  _refuseExisting(path);
  final plan = StreamlinedLocalePlan(
    locale: locale,
    englishName: englishName,
    nativeName: nativeName,
    reviewScope: reviewScope,
    sourceCatalog: streamlinedLocaleSourceCatalog,
    sourceCatalogSha256: _sha256File(source.path),
    candidateCatalog: 'localization/candidates/app_$arb.arb',
    structuralAudit: 'localization/reviews/$locale/structural-audit.json',
    approvedCatalog: 'localization/reviews/$locale/app_$arb.approved.arb',
    validationRecord:
        'localization/reviews/$locale/private-human-validation.json',
    runtimeCatalog: 'lib/l10n/app_$arb.arb',
    exceptionalGates: const {
      'rightToLeft': false,
      'fontCoverage': false,
      'physicalScreenReader': false,
      'physicalSpeechRecognition': false,
      'storePromotion': false,
    },
  );
  File(path).parent.createSync(recursive: true);
  File(path).writeAsStringSync(_prettyJson(plan.toJson()));
  stdout.writeln('Created streamlined locale plan: $path');
}

void _prepareCommand(String planPath, String bundlePath, String reviewPath) {
  final plan = StreamlinedLocalePlan.fromJson(_jsonObject(planPath));
  _verifySource(plan);
  _requirePrivatePath(reviewPath);
  for (final path in [
    plan.candidateCatalog,
    plan.structuralAudit,
    reviewPath,
  ]) {
    _refuseExisting(path);
  }
  final result = prepareStreamlinedLocale(
    plan: plan,
    source: _jsonObject(plan.sourceCatalog),
    translationBundle: _jsonObject(bundlePath),
  );
  stdout.writeln(_prettyJson(result.summary(plan)));
  if (!result.passed) {
    stderr.writeln('Preparation refused: fix the reported translation errors.');
    exitCode = 65;
    return;
  }

  _writeNew(plan.candidateCatalog, _prettyJson(result.candidate));
  final candidateDigest = _sha256File(plan.candidateCatalog);
  final audit = {
    'schemaVersion': 1,
    'workflow': streamlinedLocaleWorkflow,
    'locale': plan.locale,
    'status': 'structurally_ready_for_private_review',
    'sourceCatalog': plan.sourceCatalog,
    'sourceCatalogSha256': plan.sourceCatalogSha256,
    'candidateCatalog': plan.candidateCatalog,
    'candidateCatalogSha256': candidateDigest,
    'messageCount': result.qualification.sourceMessageCount,
    'placeholderMessageCount':
        result.qualification.sourcePlaceholderMessageCount,
    'approvedSourceEqual': result.approvedSourceEqual,
    'riskCounts': _riskCounts(result.reviewRows),
    'humanReviewRequired': true,
    'personalDataIncluded': false,
    'runtimeActivated': false,
  };
  _writeNew(plan.structuralAudit, _prettyJson(audit));
  _writeNew(reviewPath, encodePrivateReviewCsv(result.reviewRows));
  stdout.writeln('Created isolated candidate: ${plan.candidateCatalog}');
  stdout.writeln('Created structural audit: ${plan.structuralAudit}');
  stdout.writeln('Created private review worksheet outside Git: $reviewPath');
}

void _acceptCommand(String planPath, String reviewPath) {
  final plan = StreamlinedLocalePlan.fromJson(_jsonObject(planPath));
  _verifySource(plan);
  _requirePrivatePath(reviewPath);
  _refuseExisting(plan.approvedCatalog);
  _refuseExisting(plan.validationRecord);
  final audit = _jsonObject(plan.structuralAudit);
  final candidate = _jsonObject(plan.candidateCatalog);
  _verifyPreparationLocks(plan, audit);
  final approvedSourceEqual = _stringMap(audit['approvedSourceEqual']);
  final result = acceptStreamlinedLocaleReview(
    plan: plan,
    source: _jsonObject(plan.sourceCatalog),
    candidate: candidate,
    approvedSourceEqual: approvedSourceEqual,
    reviewRows: decodePrivateReviewCsv(File(reviewPath).readAsStringSync()),
  );
  stdout.writeln(_prettyJson(result.summary(plan)));
  if (!result.passed) {
    stderr.writeln('Acceptance refused: the private review is not complete.');
    exitCode = 65;
    return;
  }

  _writeNew(plan.approvedCatalog, _prettyJson(result.approvedCatalog));
  final record = {
    'schemaVersion': 1,
    'workflow': streamlinedLocaleWorkflow,
    'locale': plan.locale,
    'status': 'private_human_validation_complete',
    'validationMode': 'anonymous_private_fluent_review',
    'reviewScope': plan.reviewScope,
    'sourceCatalogSha256': plan.sourceCatalogSha256,
    'candidateCatalogSha256': _sha256File(plan.candidateCatalog),
    'approvedCatalogSha256': _sha256File(plan.approvedCatalog),
    'privateReviewPayloadSha256': _sha256File(reviewPath),
    'messageCount': result.qualification.sourceMessageCount,
    'decisionCounts': result.decisionCounts,
    'riskCounts': result.riskCounts,
    'reviewApprovedSourceEqual': result.reviewApprovedSourceEqual,
    'placeholderMismatchCount': 0,
    'sourceMutationCount': 0,
    'personalDataIncluded': false,
    'runtimeActivated': false,
  };
  _writeNew(plan.validationRecord, _prettyJson(record));
  stdout.writeln('Created reviewed catalog: ${plan.approvedCatalog}');
  stdout.writeln(
    'Created anonymous validation record: ${plan.validationRecord}',
  );
}

void _verifyCommand(String planPath) {
  final plan = StreamlinedLocalePlan.fromJson(_jsonObject(planPath));
  _verifySource(plan);
  final audit = _jsonObject(plan.structuralAudit);
  _verifyPreparationLocks(plan, audit);
  final record = _jsonObject(plan.validationRecord);
  final approved = _jsonObject(plan.approvedCatalog);
  final source = _jsonObject(plan.sourceCatalog);
  final approvedSourceEqual = _stringMap(audit['approvedSourceEqual']);
  final errors = <String>[];
  final reviewApprovedSourceEqualValue = record['reviewApprovedSourceEqual'];
  final reviewApprovedSourceEqual = <String>{};
  if (reviewApprovedSourceEqualValue is! List ||
      reviewApprovedSourceEqualValue.any((value) => value is! String)) {
    errors.add('review_source_equal_schema_mismatch');
  } else {
    final values = reviewApprovedSourceEqualValue.cast<String>();
    final sortedValues = values.toList()..sort();
    if (values.toSet().length != values.length ||
        !_listEqual(values, sortedValues)) {
      errors.add('review_source_equal_schema_mismatch');
    } else {
      reviewApprovedSourceEqual.addAll(values);
      for (final key in values) {
        if (!source.containsKey(key) ||
            key.startsWith('@') ||
            approvedSourceEqual.containsKey(key) ||
            approved[key] != source[key]) {
          errors.add('invalid_review_source_equal:$key');
        }
      }
    }
  }
  final qualification = auditLocalizationCandidate(
    source: source,
    candidate: approved,
    approvedSourceEqualKeys: {
      ...approvedSourceEqual.keys,
      ...reviewApprovedSourceEqual,
    },
  );
  if (!qualification.readyForHumanReview(
    expectedCandidateLocale: plan.arbLocale,
  )) {
    errors.add('approved_catalog_not_structurally_ready');
  }
  if (record['schemaVersion'] != 1 ||
      record['workflow'] != streamlinedLocaleWorkflow ||
      record['locale'] != plan.locale ||
      record['status'] != 'private_human_validation_complete' ||
      record['personalDataIncluded'] != false ||
      record['runtimeActivated'] != false) {
    errors.add('validation_record_identity_mismatch');
  }
  if (record['sourceCatalogSha256'] != plan.sourceCatalogSha256 ||
      record['candidateCatalogSha256'] != _sha256File(plan.candidateCatalog) ||
      record['approvedCatalogSha256'] != _sha256File(plan.approvedCatalog)) {
    errors.add('validation_record_lock_mismatch');
  }
  final runtime = File(plan.runtimeCatalog);
  final runtimeState = !runtime.existsSync()
      ? 'not_integrated'
      : _sha256File(runtime.path) == _sha256File(plan.approvedCatalog)
      ? 'integrated_exactly'
      : 'integrated_catalog_mismatch';
  if (runtimeState == 'integrated_catalog_mismatch') {
    errors.add(runtimeState);
  }
  stdout.writeln(
    _prettyJson({
      'workflow': streamlinedLocaleWorkflow,
      'operation': 'verify',
      'locale': plan.locale,
      'passed': errors.isEmpty,
      'errors': errors,
      'messageCount': qualification.sourceMessageCount,
      'runtimeState': runtimeState,
      'readyForIntegration': errors.isEmpty && runtimeState == 'not_integrated',
      'exceptionalGates': plan.exceptionalGates,
    }),
  );
  if (errors.isNotEmpty) exitCode = 65;
}

void _verifySource(StreamlinedLocalePlan plan) {
  if (plan.sourceCatalog != streamlinedLocaleSourceCatalog ||
      _sha256File(plan.sourceCatalog) != plan.sourceCatalogSha256) {
    throw StateError(
      'The English source catalog does not match the plan lock.',
    );
  }
}

void _verifyPreparationLocks(
  StreamlinedLocalePlan plan,
  Map<String, dynamic> audit,
) {
  if (audit['schemaVersion'] != 1 ||
      audit['workflow'] != streamlinedLocaleWorkflow ||
      audit['locale'] != plan.locale ||
      audit['status'] != 'structurally_ready_for_private_review' ||
      audit['sourceCatalogSha256'] != plan.sourceCatalogSha256 ||
      audit['candidateCatalogSha256'] != _sha256File(plan.candidateCatalog) ||
      audit['humanReviewRequired'] != true ||
      audit['personalDataIncluded'] != false ||
      audit['runtimeActivated'] != false) {
    throw StateError('The structural-audit locks do not match the plan.');
  }
}

void _requirePrivatePath(String path) {
  final repository = Directory.current.absolute.path;
  final absolute = File(path).absolute.path;
  if (absolute == repository ||
      absolute.startsWith('$repository${Platform.pathSeparator}')) {
    throw ArgumentError(
      'The private review worksheet must remain outside Git.',
    );
  }
}

void _writeNew(String path, String contents) {
  _refuseExisting(path);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _refuseExisting(String path) {
  if (File(path).existsSync() || Directory(path).existsSync()) {
    throw StateError('Refusing to overwrite existing path: $path');
  }
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

String _requiredDigest(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('$key must be a lowercase SHA-256 digest.');
  }
  return value;
}

Map<String, String> _strictStringMap(
  Object? value,
  List<String> errors,
  String field,
) {
  if (value is! Map) {
    errors.add('invalid_$field');
    return const {};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! String) {
      errors.add('invalid_$field');
    } else {
      result[entry.key as String] = entry.value as String;
    }
  }
  return result;
}

Map<String, String> _stringMap(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      }
    : const {};

Set<String> _messageKeys(Map<String, dynamic> catalog) =>
    catalog.keys.where((key) => !key.startsWith('@')).toSet();

Set<String> _placeholderNames(Map<String, dynamic> metadata) {
  final placeholders = metadata['placeholders'];
  return placeholders is Map<String, dynamic> ? placeholders.keys.toSet() : {};
}

LocaleReviewRisk _riskFor(
  String key,
  String source,
  Map<String, dynamic> metadata,
) {
  final description = metadata['description'] is String
      ? metadata['description'] as String
      : '';
  final haystack = '$key $source $description'.toLowerCase();
  if (_containsAny(haystack, const [
    'delete',
    'erase',
    'cloud backup',
    'cloud restore',
    'purchase',
    'subscription',
    'permission',
    'microphone',
    'safety',
    'crisis',
    'emergency',
    'privacy',
    'private',
    'enhanced ai',
    'focus coach',
    'confirm',
    'execute',
    'destructive',
  ])) {
    return LocaleReviewRisk.critical;
  }
  if (_placeholderNames(metadata).isNotEmpty ||
      _containsAny(haystack, const [
        'accessibility',
        'semantics',
        'tooltip',
        'planner',
        'forecast',
        'rhythm',
        'suggestion',
      ])) {
    return LocaleReviewRisk.elevated;
  }
  return LocaleReviewRisk.standard;
}

LocaleReviewRisk _riskFromLabel(String label) =>
    LocaleReviewRisk.values.firstWhere((risk) => risk.label == label);

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);

Map<String, int> _riskCounts(List<Map<String, String>> rows) {
  final counts = <String, int>{
    for (final risk in LocaleReviewRisk.values) risk.label: 0,
  };
  for (final row in rows) {
    final risk = row['risk'];
    if (risk != null && counts.containsKey(risk)) {
      counts[risk] = counts[risk]! + 1;
    }
  }
  return counts;
}

String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

List<List<String>> _parseCsv(String input) {
  final records = <List<String>>[];
  var record = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var index = 0;
  while (index < input.length) {
    final character = input[index];
    if (quoted) {
      if (character == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index += 2;
          continue;
        }
        quoted = false;
      } else if (character == '\r' &&
          index + 1 < input.length &&
          input[index + 1] == '\n') {
        field.write('\n');
        index += 1;
      } else {
        field.write(character);
      }
    } else if (character == '"' && field.isEmpty) {
      quoted = true;
    } else if (character == ',') {
      record.add(field.toString());
      field = StringBuffer();
    } else if (character == '\n' || character == '\r') {
      if (character == '\r' &&
          index + 1 < input.length &&
          input[index + 1] == '\n') {
        index += 1;
      }
      record.add(field.toString());
      field = StringBuffer();
      if (record.any((value) => value.isNotEmpty)) records.add(record);
      record = <String>[];
    } else {
      field.write(character);
    }
    index += 1;
  }
  if (quoted) throw const FormatException('Unterminated quoted CSV field.');
  if (field.isNotEmpty || record.isNotEmpty) {
    record.add(field.toString());
    if (record.any((value) => value.isNotEmpty)) records.add(record);
  }
  return records;
}

bool _setEqual<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

bool _listEqual<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Object? _copyJson(Object? value) => jsonDecode(jsonEncode(value));

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

String _sha256File(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) throw StateError('Unable to hash $path.');
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

void _badUsage() {
  _usage();
  exitCode = 64;
}

void _usage() {
  stderr.writeln('''
Usage:
  dart run tool/localization_streamlined_pipeline.dart init <locale> <English name> <native name> <review scope>
  dart run tool/localization_streamlined_pipeline.dart prepare <plan.json> <translations.json> <private-review.csv>
  dart run tool/localization_streamlined_pipeline.dart accept <plan.json> <completed-private-review.csv>
  dart run tool/localization_streamlined_pipeline.dart verify <plan.json>
''');
}
