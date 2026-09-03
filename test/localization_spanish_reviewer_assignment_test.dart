import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_spanish_reviewer_assignment.dart';

void main() {
  test('prepares an assignment record without starting review', () {
    final result = prepareSpanishReviewerAssignment(
      authorization: _validAuthorization(),
      qualification: _preAssignmentQualification(),
      packetAudit: _json('localization/reviews/es/packet-audit.json'),
      packet: _json('localization/reviews/es/packets/review-packet.json'),
    );

    expect(result.readyToWrite, isTrue);
    expect(result.errors, isEmpty);
    expect(result.record, isNotNull);
    expect(result.record!['status'], 'assigned_not_started');
    expect(result.record!['reviewerName'], 'María Example');
    expect(result.record!['reviewPacketAssigned'], isTrue);
    expect(result.record!['reviewStarted'], isFalse);
    expect(result.record!['pendingDecisionCount'], 980);
    expect(result.record!['completedDecisionCount'], 0);
    expect(result.record!['linguisticallyApproved'], isFalse);
    expect(result.record!['runtimeActivated'], isFalse);
  });

  test('rejects placeholders, extra fields, and implicit review start', () {
    final authorization = _validAuthorization()
      ..['reviewerName'] = 'TBD'
      ..['reviewerQualification'] = 'pending'
      ..['independenceStatement'] = 'n/a'
      ..['reviewStarted'] = true
      ..['reviewerEmail'] = 'must-not-be-committed@example.com';
    final result = prepareSpanishReviewerAssignment(
      authorization: authorization,
      qualification: _json('localization/reviews/es/qualification.json'),
      packetAudit: _json('localization/reviews/es/packet-audit.json'),
      packet: _json('localization/reviews/es/packets/review-packet.json'),
    );

    expect(result.readyToWrite, isFalse);
    expect(result.record, isNull);
    expect(result.errors, contains('invalid_authorization_schema'));
    expect(result.errors, contains('invalid_reviewer_name'));
    expect(result.errors, contains('invalid_reviewer_qualification'));
    expect(result.errors, contains('invalid_independence_statement'));
    expect(
      result.errors,
      contains('assignment_not_explicit_or_review_already_started'),
    );
  });

  test('rejects changed locks and pre-existing review work', () {
    final qualification = _json('localization/reviews/es/qualification.json')
      ..['reviewPacketAssigned'] = true;
    final audit = _json('localization/reviews/es/packet-audit.json')
      ..['packetSha256'] = 'changed';
    final packet = _json('localization/reviews/es/packets/review-packet.json');
    final firstBatch =
        (packet['batches'] as List<dynamic>).first as Map<String, dynamic>;
    final firstEntry =
        (firstBatch['entries'] as List<dynamic>).first as Map<String, dynamic>;
    firstEntry['decision'] = 'accept';

    final result = prepareSpanishReviewerAssignment(
      authorization: _validAuthorization(),
      qualification: qualification,
      packetAudit: audit,
      packet: packet,
    );

    expect(result.readyToWrite, isFalse);
    expect(result.errors, contains('qualification_not_unassigned'));
    expect(result.errors, contains('invalid_packet_audit_base'));
    expect(result.errors, contains('packet_contains_review_work'));
  });

  test('allows only the exact isolated assignment paths', () {
    expect(
      isLockedSpanishReviewerQualificationPath(
        'localization/reviews/es/qualification.json',
      ),
      isTrue,
    );
    expect(
      isLockedSpanishReviewerPacketAuditPath(
        'localization/reviews/es/packet-audit.json',
      ),
      isTrue,
    );
    expect(
      isLockedSpanishReviewerPacketPath(
        'localization/reviews/es/packets/review-packet.json',
      ),
      isTrue,
    );
    expect(
      isIsolatedSpanishReviewerAuthorizationPath(
        'localization/intake/es/reviewer-assignment.json',
      ),
      isTrue,
    );
    expect(
      isIsolatedSpanishReviewerAssignmentOutput(
        'localization/reviews/es/reviewer-assignment.json',
      ),
      isTrue,
    );
    expect(
      isIsolatedSpanishReviewerAssignmentOutput('lib/l10n/app_es.arb'),
      isFalse,
    );
  });
}

Map<String, dynamic> _validAuthorization() => {
  'schemaVersion': 1,
  'phase': '215G-C2C',
  'locale': 'es',
  'packetSha256': spanishReviewerAssignmentPacketSha256,
  'sourceCatalogSha256': spanishReviewerAssignmentSourceSha256,
  'candidateCatalogSha256': spanishReviewerAssignmentCandidateSha256,
  'reviewScope': 'general_international_spanish',
  'reviewerName': 'María Example',
  'reviewerQualification':
      'Professional Spanish-language editor with localization review experience.',
  'independenceStatement':
      'I can review this packet independently and have disclosed no conflict.',
  'acceptedAt': '2026-09-02T12:00:00-05:00',
  'assignmentAuthorized': true,
  'reviewStarted': false,
};

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _preAssignmentQualification() =>
    _json('localization/reviews/es/qualification.json')
      ..['status'] = 'structurally_ready'
      ..['humanReviewRequired'] = true
      ..['linguisticallyApproved'] = false
      ..['runtimeActivated'] = false;
