import 'dart:convert';
import 'dart:io';

const privateHumanValidationPhase = '215G-C2D';
const privateHumanValidationMode = 'private_human_validation';

const _allowedRecordKeys = <String>{
  'schemaVersion',
  'phase',
  'locale',
  'status',
  'validationMode',
  'sourceCatalogSha256',
  'candidateCatalogSha256',
  'reviewPacketSha256',
  'validationPayloadSha256',
  'messageCount',
  'decisionCounts',
  'riskCounts',
  'sourceMutationCount',
  'invalidDecisionCount',
  'placeholderMismatchCount',
  'personalDataIncluded',
  'candidateChanged',
  'runtimeActivated',
  'voiceAndCoachingQualified',
  'nativeAndStoreQualified',
};

class PrivateHumanValidationResult {
  const PrivateHumanValidationResult(this.errors);

  final List<String> errors;

  bool get passed => errors.isEmpty;

  Map<String, dynamic> toJson() => {
    'phase': privateHumanValidationPhase,
    'passed': passed,
    'errors': errors,
  };
}

PrivateHumanValidationResult validatePrivateHumanValidation({
  required Map<String, dynamic> record,
  required String sourceCatalogSha256,
  required String candidateCatalogSha256,
  required String reviewPacketSha256,
}) {
  final errors = <String>[];

  final recordKeys = record.keys.toSet();
  if (!recordKeys.containsAll(_allowedRecordKeys) ||
      !_allowedRecordKeys.containsAll(recordKeys)) {
    errors.add('record_schema_mismatch');
  }

  if (record['schemaVersion'] != 1 ||
      record['phase'] != privateHumanValidationPhase ||
      record['locale'] != 'es' ||
      record['status'] != 'private_human_validation_complete' ||
      record['validationMode'] != privateHumanValidationMode) {
    errors.add('record_identity_mismatch');
  }

  if (record['sourceCatalogSha256'] != sourceCatalogSha256 ||
      record['candidateCatalogSha256'] != candidateCatalogSha256 ||
      record['reviewPacketSha256'] != reviewPacketSha256) {
    errors.add('catalog_or_packet_lock_mismatch');
  }

  final validationPayloadSha256 = record['validationPayloadSha256'];
  if (validationPayloadSha256 is! String ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(validationPayloadSha256)) {
    errors.add('invalid_validation_payload_lock');
  }

  final decisions = _exactIntegerMap(record['decisionCounts'], {
    'accepted',
    'revised',
    'blocked',
  });
  if (record['messageCount'] != 980 ||
      decisions == null ||
      decisions['accepted'] != 980 ||
      decisions['revised'] != 0 ||
      decisions['blocked'] != 0 ||
      decisions.values.fold<int>(0, (sum, value) => sum + value) != 980) {
    errors.add('incomplete_or_blocked_validation');
  }

  final risks = _exactIntegerMap(record['riskCounts'], {
    'critical',
    'elevated',
    'standard',
  });
  if (risks == null ||
      risks['critical'] != 433 ||
      risks['elevated'] != 251 ||
      risks['standard'] != 296 ||
      risks.values.fold<int>(0, (sum, value) => sum + value) != 980) {
    errors.add('risk_count_mismatch');
  }

  if (record['sourceMutationCount'] != 0 ||
      record['invalidDecisionCount'] != 0 ||
      record['placeholderMismatchCount'] != 0) {
    errors.add('validation_integrity_failure');
  }

  if (record['personalDataIncluded'] != false ||
      record['candidateChanged'] != false ||
      record['runtimeActivated'] != false ||
      record['voiceAndCoachingQualified'] != false ||
      record['nativeAndStoreQualified'] != false) {
    errors.add('privacy_or_release_boundary_failure');
  }

  return PrivateHumanValidationResult(errors);
}

Map<String, int>? _exactIntegerMap(Object? value, Set<String> expectedKeys) {
  if (value is! Map<String, dynamic> ||
      value.keys.toSet().difference(expectedKeys).isNotEmpty ||
      expectedKeys.difference(value.keys.toSet()).isNotEmpty ||
      value.values.any((entry) => entry is! int)) {
    return null;
  }
  return value.map((key, entry) => MapEntry(key, entry as int));
}

Map<String, dynamic> _jsonObject(String path) {
  final value = jsonDecode(File(path).readAsStringSync());
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) {
    throw StateError('Unable to calculate SHA-256 for $path.');
  }
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

void main(List<String> arguments) {
  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/localization_private_human_validation.dart '
      '<source-arb> <candidate-arb> <review-packet-json> '
      '<private-validation-json>',
    );
    exitCode = 64;
    return;
  }

  try {
    final result = validatePrivateHumanValidation(
      record: _jsonObject(arguments[3]),
      sourceCatalogSha256: _sha256(arguments[0]),
      candidateCatalogSha256: _sha256(arguments[1]),
      reviewPacketSha256: _sha256(arguments[2]),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    if (!result.passed) {
      exitCode = 65;
    }
  } catch (error) {
    stderr.writeln('Private human validation failed: $error');
    exitCode = 66;
  }
}
