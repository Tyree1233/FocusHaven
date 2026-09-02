import 'dart:convert';
import 'dart:io';

import 'localization_catalog_qualification.dart';

const spanishReviewPacketPhase = '215G-C2A';
const spanishReviewPacketLocale = 'es';
const spanishReviewSourceCommit = 'fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc';
const spanishReviewSourceCatalog = 'lib/l10n/app_en.arb';
const spanishReviewSourceCatalogSha256 =
    'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87';
const spanishReviewCandidateCatalog = 'localization/candidates/app_es.arb';
const spanishReviewCandidateCatalogSha256 =
    '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f';
const spanishReviewStructuralAudit =
    'localization/reviews/es/structural-audit.json';
const spanishReviewPacketOutput =
    'localization/reviews/es/packets/review-packet.json';
const spanishReviewPacketBatchSize = 50;

enum SpanishReviewRisk { critical, elevated, standard }

extension on SpanishReviewRisk {
  String get label => switch (this) {
    SpanishReviewRisk.critical => 'critical',
    SpanishReviewRisk.elevated => 'elevated',
    SpanishReviewRisk.standard => 'standard',
  };

  int get order => switch (this) {
    SpanishReviewRisk.critical => 0,
    SpanishReviewRisk.elevated => 1,
    SpanishReviewRisk.standard => 2,
  };
}

final class SpanishReviewPacketPreparationResult {
  const SpanishReviewPacketPreparationResult({
    required this.errors,
    required this.qualification,
    required this.packet,
  });

  final List<String> errors;
  final CatalogQualificationResult qualification;
  final Map<String, dynamic> packet;

  bool get readyToWrite => errors.isEmpty;

  Map<String, Object?> toJson() => {
    'phase': spanishReviewPacketPhase,
    'locale': spanishReviewPacketLocale,
    'errors': errors,
    'qualification': qualification.toJson(
      expectedCandidateLocale: spanishReviewPacketLocale,
    ),
    'messageCount': packet['messageCount'],
    'placeholderMessageCount': packet['placeholderMessageCount'],
    'riskCounts': packet['riskCounts'],
    'batchCount': packet['batchCount'],
    'readyToWrite': readyToWrite,
  };
}

SpanishReviewPacketPreparationResult prepareSpanishReviewPacket({
  required Map<String, dynamic> source,
  required Map<String, dynamic> candidate,
  required Map<String, dynamic> structuralAudit,
  int batchSize = spanishReviewPacketBatchSize,
}) {
  final errors = <String>[];
  if (batchSize < 1 || batchSize > spanishReviewPacketBatchSize) {
    errors.add('invalid_batch_size');
  }

  final approvedSourceEqual = _approvedSourceEqualKeys(structuralAudit);
  final qualification = auditLocalizationCandidate(
    source: source,
    candidate: candidate,
    approvedSourceEqualKeys: approvedSourceEqual,
  );

  if (!qualification.readyForHumanReview(
    expectedCandidateLocale: spanishReviewPacketLocale,
  )) {
    errors.add('candidate_not_structurally_ready');
  }
  if (structuralAudit['phase'] != '215G-C1B' ||
      structuralAudit['status'] != 'structurally_ready' ||
      structuralAudit['readyForHumanReview'] != true) {
    errors.add('invalid_structural_audit_state');
  }
  if (structuralAudit['sourceCommit'] != spanishReviewSourceCommit ||
      structuralAudit['sourceCatalog'] != spanishReviewSourceCatalog ||
      structuralAudit['sourceCatalogSha256'] !=
          spanishReviewSourceCatalogSha256 ||
      structuralAudit['candidateCatalog'] != spanishReviewCandidateCatalog ||
      structuralAudit['candidateCatalogSha256'] !=
          spanishReviewCandidateCatalogSha256) {
    errors.add('structural_audit_lock_mismatch');
  }
  if (structuralAudit['humanReviewRequired'] != true ||
      structuralAudit['humanReviewer'] != null ||
      structuralAudit['linguisticallyApproved'] != false ||
      structuralAudit['runtimeActivated'] != false) {
    errors.add('invalid_human_review_boundary');
  }
  if (structuralAudit['externalTranslationProviderUsed'] != false ||
      structuralAudit['privateRuntimeDataUsed'] != false) {
    errors.add('invalid_review_data_boundary');
  }

  final messageKeys = source.keys.where((key) => !key.startsWith('@')).toList();
  final entries = <Map<String, dynamic>>[];
  for (final key in messageKeys) {
    final sourceText = source[key];
    final candidateText = candidate[key];
    final metadata = source['@$key'];
    if (sourceText is! String ||
        candidateText is! String ||
        metadata is! Map<String, dynamic>) {
      errors.add('invalid_review_entry:$key');
      continue;
    }
    entries.add(
      _reviewEntry(
        key: key,
        sourceText: sourceText,
        candidateText: candidateText,
        metadata: metadata,
        sourceEqualInvariant: approvedSourceEqual.contains(key),
      ),
    );
  }

  entries.sort((left, right) {
    final leftRisk = _riskFromLabel(left['riskTier'] as String);
    final rightRisk = _riskFromLabel(right['riskTier'] as String);
    final riskComparison = leftRisk.order.compareTo(rightRisk.order);
    if (riskComparison != 0) {
      return riskComparison;
    }
    return (left['key'] as String).compareTo(right['key'] as String);
  });

  for (var index = 0; index < entries.length; index += 1) {
    entries[index]['sequence'] = index + 1;
  }

  final effectiveBatchSize = batchSize < 1 ? 1 : batchSize;
  final batches = <Map<String, dynamic>>[];
  for (var start = 0; start < entries.length; start += effectiveBatchSize) {
    final proposedEnd = start + effectiveBatchSize;
    final end = proposedEnd < entries.length ? proposedEnd : entries.length;
    final batchEntries = entries.sublist(start, end);
    final batchNumber = batches.length + 1;
    batches.add({
      'id': 'es-review-${batchNumber.toString().padLeft(3, '0')}',
      'sequenceStart': start + 1,
      'sequenceEnd': end,
      'entryCount': batchEntries.length,
      'riskTiers':
          batchEntries.map((entry) => entry['riskTier']).toSet().toList()
            ..sort(),
      'entries': batchEntries,
    });
  }

  final riskCounts = <String, int>{
    for (final risk in SpanishReviewRisk.values) risk.label: 0,
  };
  for (final entry in entries) {
    final label = entry['riskTier'] as String;
    riskCounts[label] = (riskCounts[label] ?? 0) + 1;
  }

  final packet = <String, dynamic>{
    'schemaVersion': 1,
    'phase': spanishReviewPacketPhase,
    'packetStatus': 'ready_for_reviewer_assignment',
    'locale': spanishReviewPacketLocale,
    'reviewScope': 'general_international_spanish',
    'sourceCommit': spanishReviewSourceCommit,
    'sourceCatalog': spanishReviewSourceCatalog,
    'sourceCatalogSha256': spanishReviewSourceCatalogSha256,
    'candidateCatalog': spanishReviewCandidateCatalog,
    'candidateCatalogSha256': spanishReviewCandidateCatalogSha256,
    'structuralAudit': spanishReviewStructuralAudit,
    'messageCount': entries.length,
    'placeholderMessageCount': qualification.sourcePlaceholderMessageCount,
    'sourceEqualInvariantCount': approvedSourceEqual.length,
    'riskCounts': riskCounts,
    'batchSize': effectiveBatchSize,
    'batchCount': batches.length,
    'humanReviewRequired': true,
    'reviewStarted': false,
    'assignedReviewer': null,
    'reviewerQualification': null,
    'linguisticallyApproved': false,
    'runtimeActivated': false,
    'externalTranslationProviderUsed': false,
    'privateRuntimeDataIncluded': false,
    'batches': batches,
  };

  return SpanishReviewPacketPreparationResult(
    errors: errors.toSet().toList()..sort(),
    qualification: qualification,
    packet: packet,
  );
}

Map<String, dynamic> _reviewEntry({
  required String key,
  required String sourceText,
  required String candidateText,
  required Map<String, dynamic> metadata,
  required bool sourceEqualInvariant,
}) {
  final description = metadata['description'] as String? ?? '';
  final placeholders = _placeholderNames(metadata);
  final categories = _reviewCategories(
    key: key,
    sourceText: sourceText,
    description: description,
    hasPlaceholders: placeholders.isNotEmpty,
    sourceEqualInvariant: sourceEqualInvariant,
  );
  final risk = _riskForCategories(categories);
  return <String, dynamic>{
    'sequence': 0,
    'key': key,
    'riskTier': risk.label,
    'categories': categories,
    'source': sourceText,
    'candidate': candidateText,
    'description': description,
    'placeholders': placeholders,
    'requiredChecks': _requiredChecks(categories),
    'reviewState': 'pending',
    'decision': null,
    'replacement': null,
    'notes': null,
  };
}

List<String> _reviewCategories({
  required String key,
  required String sourceText,
  required String description,
  required bool hasPlaceholders,
  required bool sourceEqualInvariant,
}) {
  final haystack = '$key $sourceText $description'.toLowerCase();
  final categories = <String>{};

  if (_containsAny(haystack, const [
    'delete',
    'erase',
    'clear local',
    'cloud backup',
    'cloud restore',
    'export',
    'irreversible',
  ])) {
    categories.add('account_and_data');
  }
  if (_containsAny(haystack, const [
    'purchase',
    'subscription',
    'entitlement',
    'restore purchase',
    'price',
    'product unavailable',
    'unlock pro',
  ])) {
    categories.add('commerce_and_entitlements');
  }
  if (_containsAny(haystack, const [
    'permission',
    'microphone',
    'speech recognition',
    'notification',
    'calendar',
    'focus shield',
  ])) {
    categories.add('permissions_and_system_access');
  }
  if (_containsAny(haystack, const [
    'safety',
    'self-harm',
    'suicide',
    'crisis',
    'emergency',
    'medical',
    'professional help',
    'immediate danger',
  ])) {
    categories.add('safety_and_care');
  }
  if (_containsAny(haystack, const [
    'privacy',
    'private',
    'journal',
    'reflection',
    'transcript',
    'enhanced ai',
    'account identity',
    'focus coach',
    'coaching',
  ])) {
    categories.add('privacy_ai_and_coaching');
  }
  if (_containsAny(haystack, const [
    'confirm',
    'confirmation',
    'review action',
    'haven action',
    'replay',
    'execute',
    'destructive',
  ])) {
    categories.add('reviewed_actions_and_confirmation');
  }
  if (_containsAny(haystack, const [
    'forecast',
    'rhythm',
    'planner',
    'journey',
    'haven window',
    'smart reset',
    'suggestion',
    'advisory',
    'nothing changed automatically',
  ])) {
    categories.add('advisory_language_and_agency');
  }
  if (_containsAny(haystack, const [
    'semantics',
    'semantic',
    'accessibility',
    'tooltip',
    'button label',
    'screen reader',
  ])) {
    categories.add('accessibility_and_controls');
  }
  if (hasPlaceholders) {
    categories.add('placeholders_and_icu');
  }
  if (sourceEqualInvariant) {
    categories.add('source_equal_invariant');
  }
  if (categories.isEmpty) {
    categories.add('general_product_copy');
  }
  return categories.toList()..sort();
}

SpanishReviewRisk _riskForCategories(List<String> categories) {
  const critical = {
    'account_and_data',
    'commerce_and_entitlements',
    'permissions_and_system_access',
    'safety_and_care',
    'privacy_ai_and_coaching',
    'reviewed_actions_and_confirmation',
  };
  if (categories.any(critical.contains)) {
    return SpanishReviewRisk.critical;
  }
  if (categories.any(
    const {
      'advisory_language_and_agency',
      'accessibility_and_controls',
      'placeholders_and_icu',
      'source_equal_invariant',
    }.contains,
  )) {
    return SpanishReviewRisk.elevated;
  }
  return SpanishReviewRisk.standard;
}

List<String> _requiredChecks(List<String> categories) {
  final checks = <String>{
    'meaning_preserved',
    'natural_international_spanish',
    'calm_non_punitive_tone',
  };
  for (final category in categories) {
    switch (category) {
      case 'account_and_data':
        checks.addAll(const [
          'irreversibility_is_explicit',
          'data_scope_is_exact',
          'no_false_completion_claim',
        ]);
      case 'commerce_and_entitlements':
        checks.addAll(const [
          'price_and_entitlement_meaning_preserved',
          'purchase_state_not_overclaimed',
        ]);
      case 'permissions_and_system_access':
        checks.addAll(const [
          'permission_scope_is_exact',
          'optional_access_remains_optional',
        ]);
      case 'safety_and_care':
        checks.addAll(const [
          'care_boundary_preserved',
          'urgent_help_direction_preserved',
          'no_diagnosis_or_guarantee',
        ]);
      case 'privacy_ai_and_coaching':
        checks.addAll(const [
          'privacy_boundary_preserved',
          'local_and_remote_behavior_not_confused',
          'consent_boundary_preserved',
        ]);
      case 'reviewed_actions_and_confirmation':
        checks.addAll(const [
          'explicit_confirmation_preserved',
          'proposal_not_presented_as_completed',
          'replay_and_stale_boundaries_preserved',
        ]);
      case 'advisory_language_and_agency':
        checks.addAll(const [
          'uncertainty_preserved',
          'user_choice_preserved',
          'no_automatic_change_implied',
        ]);
      case 'accessibility_and_controls':
        checks.addAll(const [
          'control_action_is_exact',
          'screen_reader_meaning_is_complete',
        ]);
      case 'placeholders_and_icu':
        checks.addAll(const [
          'placeholder_names_unchanged',
          'plural_and_select_branches_reviewed',
          'grammar_agrees_with_runtime_values',
        ]);
      case 'source_equal_invariant':
        checks.add('source_equal_rationale_confirmed');
      case 'general_product_copy':
        break;
    }
  }
  return checks.toList()..sort();
}

List<String> _placeholderNames(Map<String, dynamic> metadata) {
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map<String, dynamic>) {
    return const [];
  }
  return placeholders.keys.toList()..sort();
}

Set<String> _approvedSourceEqualKeys(Map<String, dynamic> audit) {
  final approved = audit['approvedSourceEqual'];
  if (approved is! Map<String, dynamic>) {
    return const {};
  }
  return approved.keys.toSet();
}

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);

SpanishReviewRisk _riskFromLabel(String label) =>
    SpanishReviewRisk.values.firstWhere((risk) => risk.label == label);

bool _isExactPath(String actual, String expected) =>
    File(actual).absolute.path == File(expected).absolute.path;

bool isLockedSpanishReviewSourcePath(String path) =>
    _isExactPath(path, spanishReviewSourceCatalog);

bool isLockedSpanishReviewCandidatePath(String path) =>
    _isExactPath(path, spanishReviewCandidateCatalog);

bool isLockedSpanishStructuralAuditPath(String path) =>
    _isExactPath(path, spanishReviewStructuralAudit);

bool isIsolatedSpanishReviewPacketOutput(String path) =>
    _isExactPath(path, spanishReviewPacketOutput);

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
    throw StateError('Unable to calculate catalog SHA-256.');
  }
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

void main(List<String> arguments) {
  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/localization_spanish_review_packet_builder.dart '
      'lib/l10n/app_en.arb localization/candidates/app_es.arb '
      'localization/reviews/es/structural-audit.json '
      'localization/reviews/es/packets/review-packet.json',
    );
    exitCode = 64;
    return;
  }

  final sourcePath = arguments[0];
  final candidatePath = arguments[1];
  final auditPath = arguments[2];
  final outputPath = arguments[3];

  if (!isLockedSpanishReviewSourcePath(sourcePath) ||
      !isLockedSpanishReviewCandidatePath(candidatePath) ||
      !isLockedSpanishStructuralAuditPath(auditPath) ||
      !isIsolatedSpanishReviewPacketOutput(outputPath)) {
    stderr.writeln(
      'Review packet path refused: use only the locked C2A paths.',
    );
    exitCode = 73;
    return;
  }

  final output = File(outputPath);
  if (output.existsSync()) {
    stderr.writeln('Review packet output refused: $outputPath already exists.');
    exitCode = 73;
    return;
  }

  try {
    if (_sha256File(sourcePath) != spanishReviewSourceCatalogSha256 ||
        _sha256File(candidatePath) != spanishReviewCandidateCatalogSha256) {
      stderr.writeln('Review packet input refused: a catalog lock changed.');
      exitCode = 66;
      return;
    }

    final result = prepareSpanishReviewPacket(
      source: _readJsonObject(sourcePath),
      candidate: _readJsonObject(candidatePath),
      structuralAudit: _readJsonObject(auditPath),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    if (!result.readyToWrite ||
        result.qualification.sourceMessageCount != 980 ||
        result.qualification.sourcePlaceholderMessageCount != 148) {
      stderr.writeln(
        'Review packet output refused: the candidate is not ready for locked human-review intake.',
      );
      exitCode = 66;
      return;
    }

    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(result.packet)}\n',
    );
    stdout.writeln('Created isolated review packet: $outputPath');
  } on Object catch (error) {
    stderr.writeln('Spanish review packet preparation failed: $error');
    exitCode = 65;
  }
}
