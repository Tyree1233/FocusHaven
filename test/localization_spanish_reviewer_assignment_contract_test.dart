import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

void main() {
  test('C2C prepares assignment safeguards without assigning a reviewer', () {
    final review = _json('localization/reviews/es/qualification.json');

    expect(review['reviewerAssignmentPreparationPhase'], '215G-C2C');
    expect(review['reviewerAssignmentPreparationReady'], isTrue);
    expect(
      review['reviewerAssignmentTool'],
      'tool/localization_spanish_reviewer_assignment.dart',
    );
    expect(
      review['reviewerAssignmentAuthorization'],
      'localization/intake/es/reviewer-assignment.json',
    );
    expect(review['reviewerAssignmentAuthorizationPresent'], isFalse);
    expect(
      review['reviewerAssignmentRecord'],
      'localization/reviews/es/reviewer-assignment.json',
    );
    expect(review['reviewerAssignmentRecordPresent'], isFalse);
    expect(review['reviewPacketAssigned'], isFalse);
    expect(review['reviewStarted'], isFalse);
    expect(review['humanReviewer'], isNull);
    expect(review['reviewScope'], isNull);
    expect(review['linguisticallyApproved'], isTrue);
    expect(review['runtimeActivated'], isTrue);

    expect(
      File('localization/intake/es/reviewer-assignment.json').existsSync(),
      isFalse,
    );
    expect(
      File('localization/reviews/es/reviewer-assignment.json').existsSync(),
      isFalse,
    );
  });

  test(
    'C2C documentation requires a real reviewer and separate review start',
    () {
      final docs = [
        File('README.md').readAsStringSync(),
        File(
          'docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md',
        ).readAsStringSync(),
        File(
          'docs/LOCALIZATION_SPANISH_HUMAN_REVIEW_PACKET.md',
        ).readAsStringSync(),
        File(
          'docs/LOCALIZATION_SPANISH_REVIEWER_ASSIGNMENT.md',
        ).readAsStringSync(),
        File(
          'docs/LOCALIZATION_SPANISH_REVIEW_WORKSHEET.md',
        ).readAsStringSync(),
        File(
          'docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md',
        ).readAsStringSync(),
        File('docs/PRODUCT_ROADMAP.md').readAsStringSync(),
      ].map(_normalize).toList();

      for (final document in docs) {
        expect(document, contains('Phase 215G-C2C'));
      }
      final combined = docs.join(' ');
      expect(combined, contains('real qualified reviewer'));
      expect(combined, contains('assignment record does not exist'));
      expect(combined, contains('review has not started'));
      expect(combined, contains('all 980'));
      expect(combined, contains('Spanish remains'));
      expect(combined, contains('runtime inactive'));
    },
  );

  test('C2C preserves packet locks and English-only production runtime', () {
    final packet = _json('localization/reviews/es/packets/review-packet.json');
    final audit = _json('localization/reviews/es/packet-audit.json');

    expect(packet['packetStatus'], 'ready_for_reviewer_assignment');
    expect(packet['reviewStarted'], isFalse);
    expect(packet['assignedReviewer'], isNull);
    expect(
      audit['packetSha256'],
      '325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e',
    );
    expect(audit['pendingDecisionCount'], 980);
    expect(audit['completedDecisionCount'], 0);
    expect(File('lib/l10n/app_es.arb').existsSync(), isTrue);
    expect(FocusHavenLocales.productionLocales, const [
      Locale('en'),
      Locale('es'),
    ]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.production,
    );
  });
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
