import 'dart:convert';
import 'dart:io';

const spanishReviewerAssignmentPhase = '215G-C2C';
const spanishReviewerAssignmentLocale = 'es';
const spanishReviewerAssignmentScope = 'general_international_spanish';
const spanishReviewerAssignmentPacket =
    'localization/reviews/es/packets/review-packet.json';
const spanishReviewerAssignmentPacketSha256 =
    '325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e';
const spanishReviewerAssignmentSourceSha256 =
    'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87';
const spanishReviewerAssignmentCandidateSha256 =
    '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f';
const spanishReviewerAssignmentQualification =
    'localization/reviews/es/qualification.json';
const spanishReviewerAssignmentPacketAudit =
    'localization/reviews/es/packet-audit.json';
const spanishReviewerAssignmentAuthorization =
    'localization/intake/es/reviewer-assignment.json';
const spanishReviewerAssignmentOutput =
    'localization/reviews/es/reviewer-assignment.json';

const _authorizationKeys = <String>{
  'schemaVersion',
  'phase',
  'locale',
  'packetSha256',
  'sourceCatalogSha256',
  'candidateCatalogSha256',
  'reviewScope',
  'reviewerName',
  'reviewerQualification',
  'independenceStatement',
  'acceptedAt',
  'assignmentAuthorized',
  'reviewStarted',
};

final class SpanishReviewerAssignmentResult {
  const SpanishReviewerAssignmentResult({
    required this.errors,
    required this.record,
  });

  final List<String> errors;
  final Map<String, dynamic>? record;

  bool get readyToWrite => errors.isEmpty && record != null;

  Map<String, Object?> toJson() => {
    'phase': spanishReviewerAssignmentPhase,
    'locale': spanishReviewerAssignmentLocale,
    'errors': errors,
    'readyToWrite': readyToWrite,
    'recordStatus': record?['status'],
    'reviewPacketAssigned': record?['reviewPacketAssigned'] ?? false,
    'reviewStarted': record?['reviewStarted'] ?? false,
    'linguisticallyApproved': false,
    'runtimeActivated': false,
  };
}

SpanishReviewerAssignmentResult prepareSpanishReviewerAssignment({
  required Map<String, dynamic> authorization,
  required Map<String, dynamic> qualification,
  required Map<String, dynamic> packetAudit,
  required Map<String, dynamic> packet,
}) {
  final errors = <String>[];

  if (authorization.keys.toSet().difference(_authorizationKeys).isNotEmpty ||
      _authorizationKeys.difference(authorization.keys.toSet()).isNotEmpty) {
    errors.add('invalid_authorization_schema');
  }
  if (authorization['schemaVersion'] != 1 ||
      authorization['phase'] != spanishReviewerAssignmentPhase ||
      authorization['locale'] != spanishReviewerAssignmentLocale) {
    errors.add('invalid_authorization_identity');
  }
  if (authorization['packetSha256'] != spanishReviewerAssignmentPacketSha256 ||
      authorization['sourceCatalogSha256'] !=
          spanishReviewerAssignmentSourceSha256 ||
      authorization['candidateCatalogSha256'] !=
          spanishReviewerAssignmentCandidateSha256 ||
      authorization['reviewScope'] != spanishReviewerAssignmentScope) {
    errors.add('authorization_lock_mismatch');
  }
  if (authorization['assignmentAuthorized'] != true ||
      authorization['reviewStarted'] != false) {
    errors.add('assignment_not_explicit_or_review_already_started');
  }

  final reviewerName = authorization['reviewerName'];
  final reviewerQualification = authorization['reviewerQualification'];
  final independenceStatement = authorization['independenceStatement'];
  final acceptedAt = authorization['acceptedAt'];
  if (!_isSpecificHumanText(reviewerName, minLength: 3, maxLength: 80)) {
    errors.add('invalid_reviewer_name');
  }
  if (!_isSpecificHumanText(
    reviewerQualification,
    minLength: 30,
    maxLength: 500,
  )) {
    errors.add('invalid_reviewer_qualification');
  }
  if (!_isSpecificHumanText(
    independenceStatement,
    minLength: 30,
    maxLength: 500,
  )) {
    errors.add('invalid_independence_statement');
  }
  if (!_isOffsetDateTime(acceptedAt)) {
    errors.add('invalid_reviewer_acceptance_time');
  }

  if (qualification['phase'] != '215G-C1B' ||
      qualification['status'] != 'structurally_ready' ||
      qualification['reviewPacketCreationPhase'] != '215G-C2B' ||
      qualification['reviewPacketPresent'] != true ||
      qualification['reviewPacketSha256'] !=
          spanishReviewerAssignmentPacketSha256 ||
      qualification['reviewPacketAuditPassed'] != true) {
    errors.add('invalid_qualification_base');
  }
  if (qualification['reviewPacketAssigned'] != false ||
      qualification['reviewStarted'] != false ||
      qualification['humanReviewer'] != null ||
      qualification['reviewScope'] != null ||
      qualification['approvedAt'] != null ||
      qualification['linguisticallyApproved'] != false ||
      qualification['runtimeActivated'] != false) {
    errors.add('qualification_not_unassigned');
  }
  if (qualification['sourceCatalogSha256'] !=
          spanishReviewerAssignmentSourceSha256 ||
      qualification['candidateCatalogSha256'] !=
          spanishReviewerAssignmentCandidateSha256) {
    errors.add('qualification_catalog_lock_mismatch');
  }

  if (packetAudit['phase'] != '215G-C2B' ||
      packetAudit['status'] != 'packet_created_unassigned' ||
      packetAudit['packetSha256'] != spanishReviewerAssignmentPacketSha256 ||
      packetAudit['packetAuditPassed'] != true ||
      packetAudit['pendingDecisionCount'] != 980 ||
      packetAudit['completedDecisionCount'] != 0) {
    errors.add('invalid_packet_audit_base');
  }
  if (packetAudit['reviewPacketAssigned'] != false ||
      packetAudit['reviewStarted'] != false ||
      packetAudit['assignedReviewer'] != null ||
      packetAudit['reviewerQualification'] != null ||
      packetAudit['linguisticallyApproved'] != false ||
      packetAudit['runtimeActivated'] != false) {
    errors.add('packet_audit_not_unassigned');
  }
  if (packetAudit['sourceCatalogSha256'] !=
          spanishReviewerAssignmentSourceSha256 ||
      packetAudit['candidateCatalogSha256'] !=
          spanishReviewerAssignmentCandidateSha256 ||
      packetAudit['reviewScope'] != spanishReviewerAssignmentScope ||
      packetAudit['externalTranslationProviderUsed'] != false ||
      packetAudit['privateRuntimeDataIncluded'] != false) {
    errors.add('packet_audit_boundary_mismatch');
  }

  if (packet['schemaVersion'] != 1 ||
      packet['phase'] != '215G-C2A' ||
      packet['packetStatus'] != 'ready_for_reviewer_assignment' ||
      packet['locale'] != spanishReviewerAssignmentLocale ||
      packet['reviewScope'] != spanishReviewerAssignmentScope ||
      packet['sourceCatalogSha256'] != spanishReviewerAssignmentSourceSha256 ||
      packet['candidateCatalogSha256'] !=
          spanishReviewerAssignmentCandidateSha256 ||
      packet['messageCount'] != 980 ||
      packet['batchCount'] != 20) {
    errors.add('invalid_packet_base');
  }
  if (packet['reviewStarted'] != false ||
      packet['assignedReviewer'] != null ||
      packet['reviewerQualification'] != null ||
      packet['linguisticallyApproved'] != false ||
      packet['runtimeActivated'] != false ||
      packet['externalTranslationProviderUsed'] != false ||
      packet['privateRuntimeDataIncluded'] != false) {
    errors.add('packet_not_unassigned');
  }
  if (!_allPacketEntriesPending(packet)) {
    errors.add('packet_contains_review_work');
  }

  final uniqueErrors = errors.toSet().toList()..sort();
  if (uniqueErrors.isNotEmpty) {
    return SpanishReviewerAssignmentResult(errors: uniqueErrors, record: null);
  }

  return SpanishReviewerAssignmentResult(
    errors: const [],
    record: {
      'schemaVersion': 1,
      'phase': spanishReviewerAssignmentPhase,
      'status': 'assigned_not_started',
      'locale': spanishReviewerAssignmentLocale,
      'packet': spanishReviewerAssignmentPacket,
      'packetSha256': spanishReviewerAssignmentPacketSha256,
      'sourceCatalogSha256': spanishReviewerAssignmentSourceSha256,
      'candidateCatalogSha256': spanishReviewerAssignmentCandidateSha256,
      'reviewScope': spanishReviewerAssignmentScope,
      'reviewerName': reviewerName,
      'reviewerQualification': reviewerQualification,
      'independenceStatement': independenceStatement,
      'acceptedAt': acceptedAt,
      'assignmentAuthorized': true,
      'reviewPacketAssigned': true,
      'reviewStarted': false,
      'pendingDecisionCount': 980,
      'completedDecisionCount': 0,
      'linguisticallyApproved': false,
      'runtimeActivated': false,
      'externalTranslationProviderUsed': false,
      'privateRuntimeDataIncluded': false,
    },
  );
}

bool _isSpecificHumanText(
  Object? value, {
  required int minLength,
  required int maxLength,
}) {
  if (value is! String) return false;
  final normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) {
    return false;
  }
  const refused = {
    'pending',
    'tbd',
    'to be determined',
    'unknown',
    'reviewer',
    'qualified reviewer',
    'n/a',
    'none',
    'ai reviewer',
    'codex',
  };
  return !refused.contains(normalized.toLowerCase());
}

bool _isOffsetDateTime(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return false;
  }
  return DateTime.tryParse(value) != null;
}

bool _allPacketEntriesPending(Map<String, dynamic> packet) {
  final batches = packet['batches'];
  if (batches is! List<dynamic>) return false;
  var count = 0;
  for (final batch in batches) {
    if (batch is! Map<String, dynamic>) return false;
    final entries = batch['entries'];
    if (entries is! List<dynamic>) return false;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> ||
          entry['reviewState'] != 'pending' ||
          entry['decision'] != null ||
          entry['replacement'] != null ||
          entry['notes'] != null) {
        return false;
      }
      count += 1;
    }
  }
  return count == 980;
}

bool _isExactPath(String actual, String expected) =>
    File(actual).absolute.path == File(expected).absolute.path;

bool isLockedSpanishReviewerQualificationPath(String path) =>
    _isExactPath(path, spanishReviewerAssignmentQualification);

bool isLockedSpanishReviewerPacketAuditPath(String path) =>
    _isExactPath(path, spanishReviewerAssignmentPacketAudit);

bool isLockedSpanishReviewerPacketPath(String path) =>
    _isExactPath(path, spanishReviewerAssignmentPacket);

bool isIsolatedSpanishReviewerAuthorizationPath(String path) =>
    _isExactPath(path, spanishReviewerAssignmentAuthorization);

bool isIsolatedSpanishReviewerAssignmentOutput(String path) =>
    _isExactPath(path, spanishReviewerAssignmentOutput);

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
    throw StateError('Unable to calculate packet SHA-256.');
  }
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

void main(List<String> arguments) {
  if (arguments.length != 5) {
    stderr.writeln(
      'Usage: dart run tool/localization_spanish_reviewer_assignment.dart '
      'localization/reviews/es/qualification.json '
      'localization/reviews/es/packet-audit.json '
      'localization/reviews/es/packets/review-packet.json '
      'localization/intake/es/reviewer-assignment.json '
      'localization/reviews/es/reviewer-assignment.json',
    );
    exitCode = 64;
    return;
  }

  final qualificationPath = arguments[0];
  final auditPath = arguments[1];
  final packetPath = arguments[2];
  final authorizationPath = arguments[3];
  final outputPath = arguments[4];
  if (!isLockedSpanishReviewerQualificationPath(qualificationPath) ||
      !isLockedSpanishReviewerPacketAuditPath(auditPath) ||
      !isLockedSpanishReviewerPacketPath(packetPath) ||
      !isIsolatedSpanishReviewerAuthorizationPath(authorizationPath) ||
      !isIsolatedSpanishReviewerAssignmentOutput(outputPath)) {
    stderr.writeln(
      'Reviewer assignment path refused: use only locked C2C paths.',
    );
    exitCode = 73;
    return;
  }

  final authorizationFile = File(authorizationPath);
  final outputFile = File(outputPath);
  if (!authorizationFile.existsSync()) {
    stderr.writeln(
      'Reviewer assignment refused: explicit authorization is absent.',
    );
    exitCode = 66;
    return;
  }
  if (outputFile.existsSync()) {
    stderr.writeln(
      'Reviewer assignment output refused: $outputPath already exists.',
    );
    exitCode = 73;
    return;
  }

  try {
    if (_sha256File(packetPath) != spanishReviewerAssignmentPacketSha256) {
      stderr.writeln('Reviewer assignment refused: the packet lock changed.');
      exitCode = 66;
      return;
    }
    final result = prepareSpanishReviewerAssignment(
      authorization: _readJsonObject(authorizationPath),
      qualification: _readJsonObject(qualificationPath),
      packetAudit: _readJsonObject(auditPath),
      packet: _readJsonObject(packetPath),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    if (!result.readyToWrite) {
      stderr.writeln(
        'Reviewer assignment refused: authorization or locks failed.',
      );
      exitCode = 66;
      return;
    }
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(result.record)}\n',
    );
    stdout.writeln('Created isolated reviewer assignment: $outputPath');
  } on Object catch (error) {
    stderr.writeln('Spanish reviewer assignment failed: $error');
    exitCode = 65;
  }
}
