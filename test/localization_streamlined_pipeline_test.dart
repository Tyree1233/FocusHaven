import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_streamlined_pipeline.dart';

const _sourceDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test('prepares any canonical locale with complete structural safeguards', () {
    final result = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: _bundle(),
    );

    expect(result.passed, isTrue);
    expect(result.errors, isEmpty);
    expect(result.candidate['@@locale'], 'fr');
    expect(result.qualification.sourceMessageCount, 3);
    expect(result.qualification.sourcePlaceholderMessageCount, 1);
    expect(result.approvedSourceEqual, {
      'appTitle': 'The registered product name remains invariant.',
    });
    expect(result.reviewRows, hasLength(3));
    expect(result.reviewRows.first['risk'], 'critical');
    expect(result.reviewRows.first['decision'], isEmpty);
  });

  test('fails closed on missing copy and altered ICU placeholders', () {
    final bundle = _bundle();
    final translations = bundle['translations'] as Map<String, dynamic>;
    translations.remove('privacy');
    translations['greeting'] = 'Bonjour';

    final result = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: bundle,
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains('missing_translation:privacy'));
    expect(result.errors, contains('candidate_not_structurally_ready'));
    expect(result.qualification.icuPlaceholderMismatches, ['greeting']);
  });

  test('private CSV round trip preserves punctuation and multiline copy', () {
    final rows = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: _bundle(),
    ).reviewRows;
    rows.first['replacement'] = 'Texte, avec "guillemets"\net retour.';

    final decoded = decodePrivateReviewCsv(encodePrivateReviewCsv(rows));

    expect(decoded, rows);
  });

  test('accepts complete anonymous review and applies reviewed revisions', () {
    final prepared = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: _bundle(),
    );
    final rows = decodePrivateReviewCsv(
      encodePrivateReviewCsv(prepared.reviewRows),
    );
    for (final row in rows) {
      row['decision'] = 'ACCEPT';
    }
    final privacy = rows.singleWhere((row) => row['key'] == 'privacy');
    privacy['decision'] = 'REVISE';
    privacy['replacement'] = 'Vos réflexions restent privées.';

    final result = acceptStreamlinedLocaleReview(
      plan: _plan(),
      source: _source(),
      candidate: prepared.candidate,
      approvedSourceEqual: prepared.approvedSourceEqual,
      reviewRows: rows,
    );

    expect(result.passed, isTrue);
    expect(result.approvedCatalog['privacy'], privacy['replacement']);
    expect(result.decisionCounts, {'accepted': 2, 'revised': 1, 'blocked': 0});
    expect(result.reviewApprovedSourceEqual, isEmpty);
  });

  test('records an explicit reviewed source-equal revision as intentional', () {
    final source = _source();
    final prepared = prepareStreamlinedLocale(
      plan: _plan(),
      source: source,
      translationBundle: _bundle(),
    );
    final rows = prepared.reviewRows;
    for (final row in rows) {
      row['decision'] = 'ACCEPT';
    }
    final privacy = rows.singleWhere((row) => row['key'] == 'privacy');
    privacy['decision'] = 'REVISE';
    privacy['replacement'] = source['privacy'] as String;

    final result = acceptStreamlinedLocaleReview(
      plan: _plan(),
      source: source,
      candidate: prepared.candidate,
      approvedSourceEqual: prepared.approvedSourceEqual,
      reviewRows: rows,
    );

    expect(result.passed, isTrue);
    expect(result.approvedCatalog['privacy'], source['privacy']);
    expect(result.reviewApprovedSourceEqual, ['privacy']);
    expect(result.qualification.sourceEqualTranslations, isEmpty);
  });

  test('rejects changed worksheet copy and any blocked decision', () {
    final prepared = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: _bundle(),
    );
    final rows = prepared.reviewRows;
    for (final row in rows) {
      row['decision'] = 'ACCEPT';
    }
    rows.first['source'] = 'Changed source';
    rows.first['decision'] = 'BLOCK';

    final result = acceptStreamlinedLocaleReview(
      plan: _plan(),
      source: _source(),
      candidate: prepared.candidate,
      approvedSourceEqual: prepared.approvedSourceEqual,
      reviewRows: rows,
    );

    expect(result.passed, isFalse);
    expect(result.errors, contains('review_copy_changed:${rows.first['key']}'));
    expect(result.errors, contains('blocked_translation:${rows.first['key']}'));
  });

  test('region-specific locale plans use BCP-47 storage and ARB paths', () {
    final json = _plan().toJson()
      ..['locale'] = 'pt-BR'
      ..['englishName'] = 'Brazilian Portuguese'
      ..['nativeName'] = 'Português (Brasil)'
      ..['reviewScope'] = 'brazilian_portuguese'
      ..['candidateCatalog'] = 'localization/candidates/app_pt_BR.arb'
      ..['structuralAudit'] = 'localization/reviews/pt-BR/structural-audit.json'
      ..['approvedCatalog'] =
          'localization/reviews/pt-BR/app_pt_BR.approved.arb'
      ..['validationRecord'] =
          'localization/reviews/pt-BR/private-human-validation.json'
      ..['runtimeCatalog'] = 'lib/l10n/app_pt_BR.arb';

    final plan = StreamlinedLocalePlan.fromJson(json);

    expect(plan.locale, 'pt-BR');
    expect(plan.arbLocale, 'pt_BR');
    expect(plan.runtimeCatalog, 'lib/l10n/app_pt_BR.arb');
  });
}

StreamlinedLocalePlan _plan() => StreamlinedLocalePlan.fromJson({
  'schemaVersion': 1,
  'workflow': streamlinedLocaleWorkflow,
  'locale': 'fr',
  'englishName': 'French',
  'nativeName': 'Français',
  'reviewScope': 'general_french',
  'sourceCatalog': 'lib/l10n/app_en.arb',
  'sourceCatalogSha256': _sourceDigest,
  'candidateCatalog': 'localization/candidates/app_fr.arb',
  'structuralAudit': 'localization/reviews/fr/structural-audit.json',
  'approvedCatalog': 'localization/reviews/fr/app_fr.approved.arb',
  'validationRecord': 'localization/reviews/fr/private-human-validation.json',
  'runtimeCatalog': 'lib/l10n/app_fr.arb',
  'exceptionalGates': {
    'rightToLeft': false,
    'fontCoverage': false,
    'physicalScreenReader': false,
    'physicalSpeechRecognition': false,
    'storePromotion': false,
  },
});

Map<String, dynamic> _source() => {
  '@@locale': 'en',
  'appTitle': 'FocusHaven',
  '@appTitle': {'description': 'Registered application name.'},
  'greeting': 'Hello, {name}',
  '@greeting': {
    'description': 'Greets the person.',
    'placeholders': {
      'name': {'type': 'String'},
    },
  },
  'privacy': 'Your reflection stays private.',
  '@privacy': {'description': 'Privacy boundary.'},
};

Map<String, dynamic> _bundle() =>
    jsonDecode(
          jsonEncode({
            'schemaVersion': 1,
            'workflow': streamlinedLocaleWorkflow,
            'locale': 'fr',
            'sourceCatalogSha256': _sourceDigest,
            'translations': {
              'appTitle': 'FocusHaven',
              'greeting': 'Bonjour, {name}',
              'privacy': 'Votre réflexion reste privée.',
            },
            'approvedSourceEqual': {
              'appTitle': 'The registered product name remains invariant.',
            },
          }),
        )
        as Map<String, dynamic>;
