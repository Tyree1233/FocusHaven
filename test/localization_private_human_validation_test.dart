import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_private_human_validation.dart';

void main() {
  test('accepts the exact anonymous completed Spanish validation', () {
    final result = _validate(_record());

    expect(result.passed, isTrue);
    expect(result.errors, isEmpty);
    expect(result.toJson(), {
      'phase': '215G-C2D',
      'passed': true,
      'errors': <String>[],
    });
  });

  test('rejects personal fields and changed catalog locks', () {
    final record = _record()
      ..['reviewerName'] = 'Must not be stored'
      ..['candidateCatalogSha256'] = 'changed';
    final result = _validate(record);

    expect(result.passed, isFalse);
    expect(result.errors, contains('record_schema_mismatch'));
    expect(result.errors, contains('catalog_or_packet_lock_mismatch'));
  });

  test('rejects incomplete decisions and placeholder failures', () {
    final record = _record();
    record['decisionCounts'] = {'accepted': 979, 'revised': 0, 'blocked': 1};
    record['placeholderMismatchCount'] = 1;
    final result = _validate(record);

    expect(result.passed, isFalse);
    expect(result.errors, contains('incomplete_or_blocked_validation'));
    expect(result.errors, contains('validation_integrity_failure'));
  });

  test('malformed aggregate values fail closed without throwing', () {
    final record = _record()
      ..['decisionCounts'] = {'accepted': '980', 'revised': 0, 'blocked': 0}
      ..['riskCounts'] = {'critical': 433, 'elevated': 251, 'standard': null};
    final result = _validate(record);

    expect(result.passed, isFalse);
    expect(result.errors, contains('incomplete_or_blocked_validation'));
    expect(result.errors, contains('risk_count_mismatch'));
  });

  test('rejects any release or personal-data claim', () {
    final record = _record()
      ..['personalDataIncluded'] = true
      ..['runtimeActivated'] = true;
    final result = _validate(record);

    expect(result.passed, isFalse);
    expect(result.errors, contains('privacy_or_release_boundary_failure'));
  });
}

PrivateHumanValidationResult _validate(Map<String, dynamic> record) =>
    validatePrivateHumanValidation(
      record: record,
      sourceCatalogSha256:
          'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87',
      candidateCatalogSha256:
          '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f',
      reviewPacketSha256:
          '325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e',
    );

Map<String, dynamic> _record() =>
    jsonDecode(
          File(
            'localization/reviews/es/private-human-validation.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
