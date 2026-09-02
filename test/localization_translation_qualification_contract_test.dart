import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

import '../tool/localization_catalog_qualification.dart';

void main() {
  test('C0 freezes the complete English source catalog for Spanish intake', () {
    final source =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    final review =
        jsonDecode(_read('localization/reviews/es/qualification.json'))
            as Map<String, dynamic>;
    final messages = source.keys.where((key) => !key.startsWith('@')).toList();
    final placeholderMessages = messages.where((key) {
      final metadata = source['@$key'] as Map<String, dynamic>;
      final placeholders = metadata['placeholders'];
      return placeholders is Map<String, dynamic> && placeholders.isNotEmpty;
    }).toList();

    expect(source['@@locale'], 'en');
    expect(messages, hasLength(980));
    expect(placeholderMessages, hasLength(148));
    expect(review['phase'], '215G-C1B');
    expect(review['locale'], 'es');
    expect(review['status'], 'structurally_ready');
    expect(review['sourceCommit'], 'fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc');
    expect(
      review['sourceCatalogSha256'],
      'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87',
    );
    expect(review['sourceMessageCount'], 980);
    expect(review['sourcePlaceholderMessageCount'], 148);
    expect(review['candidatePresent'], isTrue);
    expect(review['structuralAuditPassed'], isTrue);
    expect(review['humanReviewRequired'], isTrue);
    expect(review['humanReviewer'], isNull);
    expect(review['approvedAt'], isNull);
  });

  test('catalog audit accepts only complete placeholder-safe candidates', () {
    final source = <String, dynamic>{
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
    final candidate = <String, dynamic>{
      '@@locale': 'es',
      'title': 'FocusHaven',
      '@title': {'description': 'Nombre de la aplicación.'},
      'greeting': 'Hola, {name}',
      '@greeting': {
        'description': 'Saluda a la persona.',
        'placeholders': {
          'name': {'type': 'String'},
        },
      },
      'sessions':
          '{count, plural, =0{Ninguna sesión} one{1 sesión} other{{count} sesiones}}',
      '@sessions': {
        'description': 'Cantidad de sesiones.',
        'placeholders': {
          'count': {'type': 'int'},
        },
      },
    };

    final result = auditLocalizationCandidate(
      source: source,
      candidate: candidate,
      approvedSourceEqualKeys: const {'title'},
    );

    expect(result.sourceMessageCount, 3);
    expect(result.sourcePlaceholderMessageCount, 2);
    expect(result.hasCompleteMessageParity, isTrue);
    expect(result.hasCompleteMetadata, isTrue);
    expect(result.hasSafePlaceholders, isTrue);
    expect(result.emptyTranslations, isEmpty);
    expect(result.sourceEqualTranslations, isEmpty);
    expect(result.readyForHumanReview(expectedCandidateLocale: 'es'), isTrue);
  });

  test('catalog audit fails closed on omissions and placeholder changes', () {
    final source = <String, dynamic>{
      '@@locale': 'en',
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
    final candidate = <String, dynamic>{
      '@@locale': 'fr',
      'greeting': 'Hola, {person}',
      '@greeting': {
        'description': 'Saluda a la persona.',
        'placeholders': {
          'person': {'type': 'String'},
        },
      },
      'extra': 'Texto adicional',
      '@extra': {'description': 'Unexpected copy.'},
    };

    final result = auditLocalizationCandidate(
      source: source,
      candidate: candidate,
    );

    expect(result.missingMessages, ['privacy']);
    expect(result.extraMessages, ['extra']);
    expect(result.placeholderSchemaMismatches, ['greeting']);
    expect(result.icuPlaceholderMismatches, ['greeting']);
    expect(result.readyForHumanReview(expectedCandidateLocale: 'es'), isFalse);
  });

  test('Spanish candidate remains isolated and cannot be selected', () {
    final main = _read('lib/main.dart');
    final registry = _read('lib/l10n/focus_haven_locales.dart');
    final review = _read('localization/reviews/es/qualification.json');

    expect(FocusHavenLocales.productionLocales, const [Locale('en')]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.locale,
      const Locale('es'),
    );
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.planned,
    );
    expect(
      Directory('lib/l10n').listSync().whereType<File>().where(
        (file) => file.path.endsWith('.arb'),
      ),
      hasLength(1),
    );
    expect(File('lib/l10n/app_es.arb').existsSync(), isFalse);
    expect(File('localization/candidates/app_es.arb').existsSync(), isTrue);
    expect(
      main,
      contains('supportedLocales: AppLocalizations.supportedLocales'),
    );
    expect(registry, contains("status: FocusHavenLocaleStatus.planned"));
    expect(review, contains('"candidatePresent": true'));
    expect(review, contains('"runtimeActivated": false'));
  });

  test('qualification policy requires human review and protects private data', () {
    final qualification = _normalize(
      _read('docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md'),
    );
    final worksheet = _normalize(
      _read('docs/LOCALIZATION_SPANISH_REVIEW_WORKSHEET.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));

    for (final required in <String>[
      'A structurally complete candidate is not an approved translation',
      'qualified human reviewer',
      'Tasks, journal entries, reflections, transcripts, coaching conversations, account identities, and other private runtime values',
      'candidate catalogs remain outside `lib/l10n`',
      'Spanish remains planned and inactive',
      'Voice and coaching qualification remains Phase 215G-D',
      'Native and store qualification remains Phase 215G-E',
    ]) {
      expect(qualification, contains(required), reason: required);
    }

    expect(
      worksheet,
      contains(
        'Status: Phase 215G-C2C assignment safeguards prepared; packet unassigned and review not started',
      ),
    );
    expect(worksheet, contains('No Spanish product term is approved'));
    expect(worksheet, contains('Focus Coach'));
    expect(worksheet, contains('Smart Reset'));
    expect(policy, contains('Phase 215G-C0'));
    expect(roadmap, contains('Phase 215G-C0 translation qualification'));
    expect(readme, contains('Phase 215G-C0'));
    expect(qualification, contains('Phase 215G-C1B'));
    expect(policy, contains('Phase 215G-C1B'));
    expect(roadmap, contains('Phase 215G-C1B'));
    expect(readme, contains('Phase 215G-C1B'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
