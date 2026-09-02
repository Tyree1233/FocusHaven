import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

void main() {
  const packetPath = 'localization/reviews/es/packets/review-packet.json';
  const packetSha =
      '325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e';

  test('C2B locks the complete created packet and durable audit', () {
    final packetFile = File(packetPath);
    final packet = _json(packetPath);
    final review = _json('localization/reviews/es/qualification.json');
    final audit = _json('localization/reviews/es/packet-audit.json');

    expect(packetFile.existsSync(), isTrue);
    expect(packetFile.lengthSync(), 884241);
    expect(_sha256(packetPath), packetSha);
    expect(packet['schemaVersion'], 1);
    expect(packet['phase'], '215G-C2A');
    expect(packet['packetStatus'], 'ready_for_reviewer_assignment');
    expect(packet['locale'], 'es');
    expect(packet['reviewScope'], 'general_international_spanish');
    expect(packet['messageCount'], 980);
    expect(packet['placeholderMessageCount'], 148);
    expect(packet['sourceEqualInvariantCount'], 11);
    expect(packet['batchSize'], 50);
    expect(packet['batchCount'], 20);
    expect(packet['riskCounts'], {
      'critical': 433,
      'elevated': 251,
      'standard': 296,
    });

    expect(review['reviewPacketCreationPhase'], '215G-C2B');
    expect(review['reviewPacketPresent'], isTrue);
    expect(review['reviewPacketSha256'], packetSha);
    expect(review['reviewPacketBytes'], 884241);
    expect(review['reviewPacketAuditPassed'], isTrue);
    expect(
      review['reviewPacketAudit'],
      'localization/reviews/es/packet-audit.json',
    );

    expect(audit['phase'], '215G-C2B');
    expect(audit['status'], 'packet_created_unassigned');
    expect(audit['packetSha256'], packetSha);
    expect(audit['packetBytes'], 884241);
    expect(audit['packetAuditPassed'], isTrue);
    expect(audit['pendingDecisionCount'], 980);
    expect(audit['completedDecisionCount'], 0);
  });

  test('C2B packet keeps every reviewer field empty and pending', () {
    final packet = _json(packetPath);
    final batches = (packet['batches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final entries = [
      for (final batch in batches)
        ...(batch['entries'] as List<dynamic>).cast<Map<String, dynamic>>(),
    ];

    expect(batches, hasLength(20));
    expect(entries, hasLength(980));
    expect(entries.map((entry) => entry['key']).toSet(), hasLength(980));
    expect(packet['reviewStarted'], isFalse);
    expect(packet['assignedReviewer'], isNull);
    expect(packet['reviewerQualification'], isNull);
    expect(packet['linguisticallyApproved'], isFalse);
    expect(packet['runtimeActivated'], isFalse);
    expect(packet['externalTranslationProviderUsed'], isFalse);
    expect(packet['privateRuntimeDataIncluded'], isFalse);

    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      expect(entry['sequence'], index + 1);
      expect(entry['reviewState'], 'pending');
      expect(entry['decision'], isNull);
      expect(entry['replacement'], isNull);
      expect(entry['notes'], isNull);
    }

    final tiers = entries.map((entry) => entry['riskTier']).toList();
    final firstElevated = tiers.indexOf('elevated');
    final firstStandard = tiers.indexOf('standard');
    expect(firstElevated, 433);
    expect(firstStandard, 684);
    expect(tiers.take(firstElevated).toSet(), {'critical'});
    expect(tiers.skip(firstElevated).take(251).toSet(), {'elevated'});
    expect(tiers.skip(firstStandard).toSet(), {'standard'});
  });

  test('C2B remains outside runtime and before reviewer assignment', () {
    final review = _json('localization/reviews/es/qualification.json');
    final audit = _json('localization/reviews/es/packet-audit.json');

    expect(review['phase'], '215G-C1B');
    expect(review['status'], 'structurally_ready');
    expect(review['reviewPacketAssigned'], isFalse);
    expect(review['reviewStarted'], isFalse);
    expect(review['humanReviewer'], isNull);
    expect(review['reviewScope'], isNull);
    expect(review['approvedAt'], isNull);
    expect(review['linguisticallyApproved'], isFalse);
    expect(review['runtimeActivated'], isFalse);
    expect(audit['reviewPacketAssigned'], isFalse);
    expect(audit['reviewStarted'], isFalse);
    expect(audit['assignedReviewer'], isNull);
    expect(audit['reviewerQualification'], isNull);
    expect(audit['linguisticallyApproved'], isFalse);
    expect(audit['runtimeActivated'], isFalse);
    expect(audit['externalTranslationProviderUsed'], isFalse);
    expect(audit['privateRuntimeDataIncluded'], isFalse);

    expect(File('lib/l10n/app_es.arb').existsSync(), isTrue);
    expect(FocusHavenLocales.productionLocales, const [Locale('en')]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.integration,
    );
  });

  test('C2B documentation records creation without claiming review', () {
    final docs = [
      File('README.md').readAsStringSync(),
      File('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md').readAsStringSync(),
      File(
        'docs/LOCALIZATION_SPANISH_HUMAN_REVIEW_PACKET.md',
      ).readAsStringSync(),
      File('docs/LOCALIZATION_SPANISH_REVIEW_WORKSHEET.md').readAsStringSync(),
      File('docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md').readAsStringSync(),
      File('docs/PRODUCT_ROADMAP.md').readAsStringSync(),
    ].map(_normalize).toList();

    for (final document in docs) {
      expect(document, contains('Phase 215G-C2B'));
    }
    final combined = docs.join(' ');
    expect(combined, contains(packetSha));
    expect(combined, contains('review has not started'));
    expect(combined, contains('Spanish remains'));
    expect(combined, contains('outside `lib/l10n`'));
    expect(combined, contains('runtime inactive'));
  });
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
