import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

import '../tool/localization_spanish_review_packet_builder.dart';

void main() {
  test('C2A prepares a complete critical-first packet in memory', () {
    final result = prepareSpanishReviewPacket(
      source: _json(spanishReviewSourceCatalog),
      candidate: _json(spanishReviewCandidateCatalog),
      structuralAudit: _json(spanishReviewStructuralAudit),
    );

    expect(result.readyToWrite, isTrue);
    expect(result.errors, isEmpty);
    expect(result.qualification.sourceMessageCount, 980);
    expect(result.qualification.sourcePlaceholderMessageCount, 148);
    expect(result.packet['messageCount'], 980);
    expect(result.packet['placeholderMessageCount'], 148);
    expect(result.packet['sourceEqualInvariantCount'], 11);
    expect(result.packet['batchSize'], 50);
    expect(result.packet['batchCount'], 20);

    final entries = _entries(result.packet);
    expect(entries, hasLength(980));
    expect(entries.map((entry) => entry['key']).toSet(), hasLength(980));
    expect(entries.first['riskTier'], 'critical');
    expect(entries.last['riskTier'], 'standard');

    final riskCounts = result.packet['riskCounts'] as Map<String, dynamic>;
    expect(riskCounts['critical'] as int, greaterThan(0));
    expect(riskCounts['elevated'] as int, greaterThan(0));
    expect(riskCounts['standard'] as int, greaterThan(0));
    expect(
      (riskCounts['critical'] as int) +
          (riskCounts['elevated'] as int) +
          (riskCounts['standard'] as int),
      980,
    );

    for (var index = 0; index < entries.length; index += 1) {
      expect(entries[index]['sequence'], index + 1);
      expect(entries[index]['reviewState'], 'pending');
      expect(entries[index]['decision'], isNull);
      expect(entries[index]['replacement'], isNull);
      expect(entries[index]['notes'], isNull);
    }

    final deleteAccount = entries.singleWhere(
      (entry) => entry['key'] == 'deleteAccountConfirm',
    );
    expect(deleteAccount['riskTier'], 'critical');
    expect(deleteAccount['categories'], contains('account_and_data'));
    expect(
      deleteAccount['categories'],
      contains('reviewed_actions_and_confirmation'),
    );

    final forecast = entries.singleWhere(
      (entry) => entry['key'] == 'focusForecastAdvisoryBoundary',
    );
    expect(forecast['categories'], contains('advisory_language_and_agency'));

    final placeholderEntry = entries.singleWhere(
      (entry) => entry['key'] == 'coachServiceDistractionParkingSaved',
    );
    expect(placeholderEntry['categories'], contains('placeholders_and_icu'));
    expect(placeholderEntry['placeholders'], ['count']);
  });

  test('C2B records the packet while review and runtime remain absent', () {
    final review = _json('localization/reviews/es/qualification.json');

    expect(review['phase'], '215G-C1B');
    expect(review['status'], 'production_active');
    expect(review['reviewPacketPreparationPhase'], '215G-C2A');
    expect(review['reviewPacketPreparationReady'], isTrue);
    expect(review['reviewPacketCreationPhase'], '215G-C2B');
    expect(review['reviewPacketPresent'], isTrue);
    expect(
      review['reviewPacketSha256'],
      '325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e',
    );
    expect(review['reviewPacketBytes'], 884241);
    expect(review['reviewPacketMessageCount'], 980);
    expect(review['reviewPacketBatchCount'], 20);
    expect(review['reviewPacketAuditPassed'], isTrue);
    expect(review['reviewPacketAssigned'], isFalse);
    expect(review['reviewStarted'], isFalse);
    expect(review['humanReviewer'], isNull);
    expect(review['reviewScope'], isNull);
    expect(review['approvedAt'], isNull);
    expect(review['linguisticallyApproved'], isTrue);
    expect(review['runtimeActivated'], isTrue);
    final packet = File('localization/reviews/es/packets/review-packet.json');
    expect(packet.existsSync(), isTrue);
    expect(_sha256(packet.path), review['reviewPacketSha256']);
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

  test('C2A builder is locked, isolated, bounded, and fail closed', () {
    final builder = File(
      'tool/localization_spanish_review_packet_builder.dart',
    ).readAsStringSync();

    for (final required in <String>[
      "const spanishReviewPacketPhase = '215G-C2A'",
      "const spanishReviewSourceCatalog = 'lib/l10n/app_en.arb'",
      "'localization/candidates/app_es.arb'",
      "'localization/reviews/es/structural-audit.json'",
      "'localization/reviews/es/packets/review-packet.json'",
      'spanishReviewPacketBatchSize = 50',
      'output.existsSync()',
      'candidate_not_structurally_ready',
      'invalid_human_review_boundary',
      'invalid_review_data_boundary',
      "'reviewStarted': false",
      "'assignedReviewer': null",
      "'linguisticallyApproved': false",
      "'runtimeActivated': false",
      "'privateRuntimeDataIncluded': false",
    ]) {
      expect(builder, contains(required), reason: required);
    }
  });

  test('C2A documentation preserves the assignment and approval gates', () {
    final packet = _normalize(
      File(
        'docs/LOCALIZATION_SPANISH_HUMAN_REVIEW_PACKET.md',
      ).readAsStringSync(),
    );
    final qualification = _normalize(
      File('docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md').readAsStringSync(),
    );
    final policy = _normalize(
      File('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md').readAsStringSync(),
    );
    final worksheet = _normalize(
      File('docs/LOCALIZATION_SPANISH_REVIEW_WORKSHEET.md').readAsStringSync(),
    );
    final roadmap = _normalize(
      File('docs/PRODUCT_ROADMAP.md').readAsStringSync(),
    );
    final readme = _normalize(File('README.md').readAsStringSync());

    for (final required in <String>[
      'no packet or human review has started',
      'does not generate that packet, assign or impersonate a reviewer',
      'batches of no more than 50 entries',
      'Automation must never fill these fields',
      'real qualified reviewer',
      'tasks, journals, reflections, transcripts, coaching conversations, account identities, calendar events, purchase history, focus history',
      'Spanish remains outside `lib/l10n`',
    ]) {
      expect(packet, contains(required), reason: required);
    }
    expect(qualification, contains('Phase 215G-C2A'));
    expect(policy, contains('Phase 215G-C2A'));
    expect(worksheet, contains('Phase 215G-C2A'));
    expect(roadmap, contains('Phase 215G-C2A'));
    expect(readme, contains('Phase 215G-C2A'));
  });
}

List<Map<String, dynamic>> _entries(Map<String, dynamic> packet) {
  final batches = packet['batches'] as List<dynamic>;
  return [
    for (final batch in batches.cast<Map<String, dynamic>>())
      ...(batch['entries'] as List<dynamic>).cast<Map<String, dynamic>>(),
  ];
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
