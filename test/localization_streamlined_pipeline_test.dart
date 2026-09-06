import 'dart:convert';
import 'dart:io';

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

  test(
    'fails closed on identifiers, brands, drift, repetition, and scripts',
    () {
      final source = <String, dynamic>{
        '@@locale': 'en',
        'brand': 'Welcome to FocusHaven',
        'contact': 'Add to Focus Queue',
        'duration': 'Pause for 60 minutes',
        'repeat': 'One step',
        'weekday': 'Tuesday',
        for (var index = 0; index < 8; index += 1)
          'distinct$index': 'Distinct source $index',
      };
      final candidate = <String, dynamic>{
        '@@locale': 'ja',
        'brand': 'FateHavenへようこそ',
        'contact': 'sales@cccue.com',
        'duration': '61秒間一時停止',
        'repeat': '一歩一歩一歩一歩',
        'weekday': '한국어',
        for (var index = 0; index < 8; index += 1) 'distinct$index': 'クーポン',
      };

      final result = auditStreamlinedLocaleContent(
        plan: _planForLocale('ja'),
        source: source,
        candidate: candidate,
      );

      expect(result.passed, isFalse);
      expect(
        result.errors,
        contains('candidate_protected_term_changed:brand:FocusHaven'),
      );
      expect(
        result.errors,
        contains('candidate_introduced_identifier:contact'),
      );
      expect(result.errors, contains('candidate_number_drift:duration'));
      expect(result.errors, contains('candidate_time_unit_drift:duration'));
      expect(result.errors, contains('candidate_runaway_repetition:repeat'));
      expect(result.errors, contains('candidate_unexpected_script:weekday'));
      expect(result.errors, contains('candidate_suspicious_reuse:distinct0:8'));
    },
  );

  test('flags Korean cross-script and runaway repeated content', () {
    final result = auditStreamlinedLocaleContent(
      plan: _planForLocale('ko'),
      source: {'@@locale': 'en', 'weekday': 'Tuesday'},
      candidate: {'@@locale': 'ko', 'weekday': '日本日本日本日本日本日本日本日本'},
    );

    expect(result.errors, contains('candidate_unexpected_script:weekday'));
    expect(result.errors, contains('candidate_runaway_repetition:weekday'));
  });

  test('does not flag valid Latin word-boundary letter runs', () {
    final valid = auditStreamlinedLocaleContent(
      plan: _planForLocale('nl'),
      source: {
        '@@locale': 'en',
        'reflection':
            'It sounds like two honest needs are pulling in different directions.',
      },
      candidate: {
        '@@locale': 'nl',
        'reflection':
            'Het klinkt alsof twee eerlijke behoeften verschillende kanten op trekken.',
      },
    );
    final repeated = auditStreamlinedLocaleContent(
      plan: _planForLocale('nl'),
      source: {'@@locale': 'en', 'step': 'One step'},
      candidate: {'@@locale': 'nl', 'step': 'stap stap stap stap'},
    );

    expect(valid.errors, isEmpty);
    expect(repeated.errors, contains('candidate_runaway_repetition:step'));
  });

  test('content screen accepts every existing reviewed production catalog', () {
    final source =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final entry in const {
      'es': 'lib/l10n/app_es.arb',
      'fr': 'lib/l10n/app_fr.arb',
      'de': 'lib/l10n/app_de.arb',
      'pt-BR': 'lib/l10n/app_pt_BR.arb',
    }.entries) {
      final candidate =
          jsonDecode(File(entry.value).readAsStringSync())
              as Map<String, dynamic>;

      final result = auditStreamlinedLocaleContent(
        plan: _planForLocale(entry.key),
        source: source,
        candidate: candidate,
      );

      expect(result.errors, isEmpty, reason: entry.key);
    }
  });

  test('review must repair unsafe candidate content before acceptance', () {
    StreamlinedAcceptanceResult review({required bool repair}) {
      final prepared = prepareStreamlinedLocale(
        plan: _plan(),
        source: _source(),
        translationBundle: _bundle(),
      );
      prepared.candidate['privacy'] = 'sales@cccue.com';
      final rows = prepared.reviewRows;
      for (final row in rows) {
        row['decision'] = 'ACCEPT';
      }
      final privacy = rows.singleWhere((row) => row['key'] == 'privacy');
      privacy['candidate'] = 'sales@cccue.com';
      if (repair) {
        privacy['decision'] = 'REVISE';
        privacy['replacement'] = 'Vos réflexions restent privées.';
      }
      return acceptStreamlinedLocaleReview(
        plan: _plan(),
        source: _source(),
        candidate: prepared.candidate,
        approvedSourceEqual: prepared.approvedSourceEqual,
        reviewRows: rows,
      );
    }

    final unsafe = review(repair: false);
    expect(unsafe.passed, isFalse);
    expect(unsafe.errors, contains('candidate_introduced_identifier:privacy'));

    final repaired = review(repair: true);
    expect(repaired.passed, isTrue);
    expect(repaired.contentSafety.passed, isTrue);
  });

  test('reviewed replacements preserve structural boundary whitespace', () {
    final prepared = prepareStreamlinedLocale(
      plan: _plan(),
      source: _source(),
      translationBundle: _bundle(),
    );
    final rows = prepared.reviewRows;
    for (final row in rows) {
      row['decision'] = 'ACCEPT';
    }
    final privacy = rows.singleWhere((row) => row['key'] == 'privacy');
    privacy['decision'] = 'REVISE';
    privacy['replacement'] = ' Vos réflexions restent privées.';

    final result = acceptStreamlinedLocaleReview(
      plan: _plan(),
      source: _source(),
      candidate: prepared.candidate,
      approvedSourceEqual: prepared.approvedSourceEqual,
      reviewRows: rows,
    );

    expect(result.passed, isFalse);
    expect(
      result.errors,
      contains('replacement_boundary_whitespace_mismatch:privacy'),
    );
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

  test('parses only complete boolean exceptional locale gates', () {
    final cjkGates = {
      ...streamlinedLocaleClosedExceptionalGates,
      'fontCoverage': true,
    };

    expect(parseStreamlinedLocaleExceptionalGates(cjkGates), cjkGates);
    expect(
      parseStreamlinedLocaleExceptionalGates(null, allowAbsent: true),
      streamlinedLocaleClosedExceptionalGates,
    );
    expect(
      () => parseStreamlinedLocaleExceptionalGates({'fontCoverage': true}),
      throwsFormatException,
    );
    expect(
      () => parseStreamlinedLocaleExceptionalGates({
        ...streamlinedLocaleClosedExceptionalGates,
        'rightToLeft': 'false',
      }),
      throwsFormatException,
    );
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

StreamlinedLocalePlan _planForLocale(String locale) {
  final arbLocale = locale.replaceAll('-', '_');
  final json = _plan().toJson()
    ..['locale'] = locale
    ..['englishName'] = locale
    ..['nativeName'] = locale
    ..['reviewScope'] = '${locale}_review'
    ..['candidateCatalog'] = 'localization/candidates/app_$arbLocale.arb'
    ..['structuralAudit'] = 'localization/reviews/$locale/structural-audit.json'
    ..['approvedCatalog'] =
        'localization/reviews/$locale/app_$arbLocale.approved.arb'
    ..['validationRecord'] =
        'localization/reviews/$locale/private-human-validation.json'
    ..['runtimeCatalog'] = 'lib/l10n/app_$arbLocale.arb';
  return StreamlinedLocalePlan.fromJson(json);
}

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
