import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_spanish_review_packet_builder.dart';

void main() {
  test(
    'builds critical-first review batches with empty reviewer decisions',
    () {
      final result = prepareSpanishReviewPacket(
        source: _source(),
        candidate: _candidate(),
        structuralAudit: _audit(),
        batchSize: 2,
      );

      expect(result.readyToWrite, isTrue);
      expect(result.errors, isEmpty);
      expect(result.packet['packetStatus'], 'ready_for_reviewer_assignment');
      expect(result.packet['reviewStarted'], isFalse);
      expect(result.packet['assignedReviewer'], isNull);
      expect(result.packet['linguisticallyApproved'], isFalse);
      expect(result.packet['runtimeActivated'], isFalse);
      expect(result.packet['messageCount'], 4);
      expect(result.packet['placeholderMessageCount'], 1);
      expect(result.packet['batchCount'], 2);

      final entries = _entries(result.packet);
      expect(entries.map((entry) => entry['key']), [
        'deleteAccount',
        'privateCoach',
        'focusForecast',
        'plainGreeting',
      ]);
      expect(entries[0]['riskTier'], 'critical');
      expect(entries[0]['categories'], contains('account_and_data'));
      expect(
        entries[0]['requiredChecks'],
        contains('irreversibility_is_explicit'),
      );
      expect(entries[1]['riskTier'], 'critical');
      expect(entries[1]['categories'], contains('privacy_ai_and_coaching'));
      expect(entries[1]['placeholders'], ['name']);
      expect(entries[2]['riskTier'], 'elevated');
      expect(
        entries[2]['categories'],
        contains('advisory_language_and_agency'),
      );
      expect(entries[3]['riskTier'], 'standard');
      for (final entry in entries) {
        expect(entry['reviewState'], 'pending');
        expect(entry['decision'], isNull);
        expect(entry['replacement'], isNull);
        expect(entry['notes'], isNull);
      }
    },
  );

  test('preserves source-equal invariants as explicit review work', () {
    final source = _source();
    final candidate = _candidate();
    source['appTitle'] = 'FocusHaven';
    source['@appTitle'] = {'description': 'Registered product name.'};
    candidate['appTitle'] = 'FocusHaven';
    candidate['@appTitle'] = source['@appTitle'];
    final audit = _audit();
    audit['approvedSourceEqual'] = {
      'appTitle': 'The registered product name remains invariant.',
    };

    final result = prepareSpanishReviewPacket(
      source: source,
      candidate: candidate,
      structuralAudit: audit,
      batchSize: 5,
    );

    expect(result.readyToWrite, isTrue);
    final appTitle = _entries(
      result.packet,
    ).singleWhere((entry) => entry['key'] == 'appTitle');
    expect(appTitle['categories'], contains('source_equal_invariant'));
    expect(
      appTitle['requiredChecks'],
      contains('source_equal_rationale_confirmed'),
    );
  });

  test('fails closed when structural or human-review boundaries change', () {
    final audit = _audit()
      ..['readyForHumanReview'] = false
      ..['humanReviewer'] = 'Invented Reviewer'
      ..['linguisticallyApproved'] = true
      ..['runtimeActivated'] = true
      ..['privateRuntimeDataUsed'] = true;

    final result = prepareSpanishReviewPacket(
      source: _source(),
      candidate: _candidate(),
      structuralAudit: audit,
    );

    expect(result.readyToWrite, isFalse);
    expect(result.errors, contains('invalid_structural_audit_state'));
    expect(result.errors, contains('invalid_human_review_boundary'));
    expect(result.errors, contains('invalid_review_data_boundary'));
  });

  test('fails closed on a placeholder mismatch or invalid batch size', () {
    final candidate = _candidate();
    candidate['privateCoach'] = 'Hola';

    final result = prepareSpanishReviewPacket(
      source: _source(),
      candidate: candidate,
      structuralAudit: _audit(),
      batchSize: 51,
    );

    expect(result.readyToWrite, isFalse);
    expect(result.errors, contains('candidate_not_structurally_ready'));
    expect(result.errors, contains('invalid_batch_size'));
  });

  test('allows only locked input paths and the isolated packet output', () {
    expect(isLockedSpanishReviewSourcePath('lib/l10n/app_en.arb'), isTrue);
    expect(
      isLockedSpanishReviewCandidatePath('localization/candidates/app_es.arb'),
      isTrue,
    );
    expect(
      isLockedSpanishStructuralAuditPath(
        'localization/reviews/es/structural-audit.json',
      ),
      isTrue,
    );
    expect(
      isIsolatedSpanishReviewPacketOutput(
        'localization/reviews/es/packets/review-packet.json',
      ),
      isTrue,
    );
    expect(
      isIsolatedSpanishReviewPacketOutput('lib/l10n/review-packet.json'),
      isFalse,
    );
    expect(
      isIsolatedSpanishReviewPacketOutput(
        'localization/reviews/es/packets/approved.json',
      ),
      isFalse,
    );
  });
}

List<Map<String, dynamic>> _entries(Map<String, dynamic> packet) {
  final batches = packet['batches'] as List<dynamic>;
  return [
    for (final batch in batches.cast<Map<String, dynamic>>())
      ...(batch['entries'] as List<dynamic>).cast<Map<String, dynamic>>(),
  ];
}

Map<String, dynamic> _source() =>
    jsonDecode(
          jsonEncode({
            '@@locale': 'en',
            'plainGreeting': 'Welcome back.',
            '@plainGreeting': {'description': 'A calm greeting.'},
            'focusForecast': 'A possible window, not a rule.',
            '@focusForecast': {
              'description':
                  'Advisory forecast language that preserves choice.',
            },
            'privateCoach': 'Your private Focus Coach draft for {name}.',
            '@privateCoach': {
              'description': 'Private local coaching draft.',
              'placeholders': {
                'name': {'type': 'String'},
              },
            },
            'deleteAccount': 'Delete account permanently.',
            '@deleteAccount': {
              'description': 'Irreversible account deletion action.',
            },
          }),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _candidate() =>
    jsonDecode(
          jsonEncode({
            '@@locale': 'es',
            'plainGreeting': 'Te damos la bienvenida de nuevo.',
            '@plainGreeting': {'description': 'A calm greeting.'},
            'focusForecast': 'Una ventana posible, no una regla.',
            '@focusForecast': {
              'description':
                  'Advisory forecast language that preserves choice.',
            },
            'privateCoach':
                'Tu borrador privado del Coach de enfoque para {name}.',
            '@privateCoach': {
              'description': 'Private local coaching draft.',
              'placeholders': {
                'name': {'type': 'String'},
              },
            },
            'deleteAccount': 'Eliminar la cuenta de forma permanente.',
            '@deleteAccount': {
              'description': 'Irreversible account deletion action.',
            },
          }),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _audit() => {
  'phase': '215G-C1B',
  'status': 'structurally_ready',
  'sourceCommit': spanishReviewSourceCommit,
  'sourceCatalog': spanishReviewSourceCatalog,
  'sourceCatalogSha256': spanishReviewSourceCatalogSha256,
  'candidateCatalog': spanishReviewCandidateCatalog,
  'candidateCatalogSha256': spanishReviewCandidateCatalogSha256,
  'approvedSourceEqual': <String, dynamic>{},
  'readyForHumanReview': true,
  'humanReviewRequired': true,
  'humanReviewer': null,
  'linguisticallyApproved': false,
  'runtimeActivated': false,
  'externalTranslationProviderUsed': false,
  'privateRuntimeDataUsed': false,
};
