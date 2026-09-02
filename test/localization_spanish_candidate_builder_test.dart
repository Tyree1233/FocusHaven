import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_spanish_candidate_builder.dart';

void main() {
  test('builds a complete isolated candidate from an exact locked bundle', () {
    final source = _source();
    final result = prepareSpanishCandidate(
      source: source,
      translationBundle: _bundle(),
    );

    expect(result.readyToWrite, isTrue);
    expect(result.missingTranslations, isEmpty);
    expect(result.extraTranslations, isEmpty);
    expect(result.invalidTranslations, isEmpty);
    expect(result.invalidSourceEqualDecisions, isEmpty);
    expect(result.candidate['@@locale'], 'es');
    expect(result.candidate['title'], 'FocusHaven');
    expect(result.candidate['greeting'], 'Hola, {name}');
    expect(
      result.candidate['sessions'],
      '{count, plural, =0{Ninguna sesión} one{1 sesión} other{{count} sesiones}}',
    );
    expect(result.candidate['@greeting'], source['@greeting']);
    expect(
      identical(result.candidate['@greeting'], source['@greeting']),
      isFalse,
    );
  });

  test('fails closed on incomplete, extra, empty, or unlocked input', () {
    final bundle = _bundle();
    final translations = bundle['translations'] as Map<String, dynamic>;
    translations
      ..remove('greeting')
      ..['sessions'] = '   '
      ..['unexpected'] = 'Texto inesperado';
    bundle
      ..['phase'] = 'wrong-phase'
      ..['locale'] = 'fr'
      ..['sourceCommit'] = 'wrong-commit'
      ..['sourceCatalogSha256'] = 'wrong-digest';

    final result = prepareSpanishCandidate(
      source: _source(),
      translationBundle: bundle,
    );

    expect(result.readyToWrite, isFalse);
    expect(result.phaseMatches, isFalse);
    expect(result.localeMatches, isFalse);
    expect(result.sourceCommitMatches, isFalse);
    expect(result.sourceCatalogSha256Matches, isFalse);
    expect(result.missingTranslations, ['greeting']);
    expect(result.extraTranslations, ['unexpected']);
    expect(result.invalidTranslations, ['sessions']);
  });

  test('requires a rationale for every intentional source-equal value', () {
    final bundle = _bundle();
    bundle['approvedSourceEqual'] = <String, dynamic>{};

    final unapproved = prepareSpanishCandidate(
      source: _source(),
      translationBundle: bundle,
    );
    expect(unapproved.readyToWrite, isFalse);
    expect(unapproved.qualification.sourceEqualTranslations, ['title']);

    bundle['approvedSourceEqual'] = {'greeting': 'Not actually source-equal.'};
    final invalidDecision = prepareSpanishCandidate(
      source: _source(),
      translationBundle: bundle,
    );
    expect(invalidDecision.readyToWrite, isFalse);
    expect(invalidDecision.invalidSourceEqualDecisions, ['greeting']);
  });

  test('preserves placeholder schema and ICU placeholder use', () {
    final bundle = _bundle();
    final translations = bundle['translations'] as Map<String, dynamic>;
    translations['greeting'] = 'Hola';

    final result = prepareSpanishCandidate(
      source: _source(),
      translationBundle: bundle,
    );

    expect(result.readyToWrite, isFalse);
    expect(result.qualification.icuPlaceholderMismatches, ['greeting']);
  });

  test('does not mistake plural branch copy for named placeholders', () {
    final source = <String, dynamic>{
      '@@locale': 'en',
      'parkedThoughts':
          'You have {count, plural, =1 {thought} other {thoughts}}.',
      '@parkedThoughts': {
        'description': 'Number of private parked thoughts.',
        'placeholders': {
          'count': {'type': 'int'},
        },
      },
    };
    final bundle = <String, dynamic>{
      'phase': spanishCandidatePhase,
      'locale': spanishCandidateLocale,
      'sourceCommit': spanishSourceCommit,
      'sourceCatalogSha256': spanishSourceCatalogSha256,
      'translations': {
        'parkedThoughts':
            'Tienes {count, plural, =1 {un pensamiento} other {varios pensamientos}}.',
      },
      'approvedSourceEqual': <String, dynamic>{},
    };

    final result = prepareSpanishCandidate(
      source: source,
      translationBundle: bundle,
    );

    expect(result.readyToWrite, isTrue);
    expect(result.qualification.icuPlaceholderMismatches, isEmpty);
  });

  test('allows only the isolated Spanish candidate output path', () {
    expect(
      isIsolatedSpanishCandidateOutput('localization/candidates/app_es.arb'),
      isTrue,
    );
    expect(isIsolatedSpanishCandidateOutput('lib/l10n/app_es.arb'), isFalse);
    expect(
      isIsolatedSpanishCandidateOutput('localization/candidates/other.arb'),
      isFalse,
    );
    expect(isLockedEnglishSourcePath('lib/l10n/app_en.arb'), isTrue);
    expect(
      isLockedEnglishSourcePath('localization/source/app_en.arb'),
      isFalse,
    );
  });
}

Map<String, dynamic> _source() => {
  '@@locale': 'en',
  'title': 'FocusHaven',
  '@title': {'description': 'Application name.'},
  'greeting': 'Hello, {name}',
  '@greeting': {
    'description': 'Greets the person.',
    'placeholders': {
      'name': {'type': 'String'},
    },
  },
  'sessions':
      '{count, plural, =0{No sessions} one{1 session} other{{count} sessions}}',
  '@sessions': {
    'description': 'Number of sessions.',
    'placeholders': {
      'count': {'type': 'int'},
    },
  },
};

Map<String, dynamic> _bundle() =>
    jsonDecode(
          jsonEncode({
            'phase': spanishCandidatePhase,
            'locale': spanishCandidateLocale,
            'sourceCommit': spanishSourceCommit,
            'sourceCatalogSha256': spanishSourceCatalogSha256,
            'translations': {
              'title': 'FocusHaven',
              'greeting': 'Hola, {name}',
              'sessions':
                  '{count, plural, =0{Ninguna sesión} one{1 sesión} other{{count} sesiones}}',
            },
            'approvedSourceEqual': {
              'title': 'The registered product name remains invariant.',
            },
          }),
        )
        as Map<String, dynamic>;
