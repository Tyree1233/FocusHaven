import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_incremental_review.dart';

void main() {
  group('incremental locale manifest', () {
    test('accepts an isolated proposal and canonical runtime catalog', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );

      expect(manifest.deltaId, 'adaptive-focus-review-v1');
      expect(manifest.sourceProposal, startsWith('localization/proposals/'));
      expect(manifest.locales.single.locale, 'es');
      expect(manifest.locales.single.arbLocale, 'es');
      expect(manifest.derivedFallbacks, isEmpty);
    });

    test('rejects a proposal placed in the Flutter runtime directory', () {
      final json = _manifestJson()
        ..['sourceProposal'] = 'lib/l10n/app_en_delta.arb';

      expect(
        () => IncrementalLocaleReviewManifest.fromJson(json),
        throwsFormatException,
      );
    });

    test('rejects a runtime path that does not match the locale', () {
      final json = _manifestJson();
      final locales = json['locales']! as List<dynamic>;
      (locales.single as Map<String, dynamic>)['runtimeCatalog'] =
          'lib/l10n/app_fr.arb';

      expect(
        () => IncrementalLocaleReviewManifest.fromJson(json),
        throwsFormatException,
      );
    });

    test('requires a derived fallback to reference a reviewed locale', () {
      final json = _manifestJson()
        ..['derivedFallbacks'] = [
          {
            'reviewedLocale': 'pt-BR',
            'fallbackLocale': 'pt',
            'runtimeCatalog': 'lib/l10n/app_pt.arb',
            'runtimeCatalogSha256': _digestB,
          },
        ];

      expect(
        () => IncrementalLocaleReviewManifest.fromJson(json),
        throwsFormatException,
      );
    });
  });

  group('incremental locale preflight', () {
    test('locks metadata and proves the delta is absent from runtime', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final result = verifyIncrementalLocaleReview(
        manifest: manifest,
        sourceProposal: _sourceProposal(),
        runtimeCatalogs: {
          'lib/l10n/app_es.arb': {'@@locale': 'es', 'existing': 'Existente'},
        },
        runtimeCatalogDigests: {'lib/l10n/app_es.arb': _digestB},
      );

      expect(result.passed, isTrue);
      expect(result.messageCount, 3);
      expect(result.metadataCount, 3);
      expect(result.runtimeCatalogCount, 1);
      expect(
        result.summary(manifest),
        containsPair('providerRequestMade', false),
      );
      expect(result.summary(manifest), containsPair('runtimeActivated', false));
    });

    test('fails closed on a runtime lock mismatch and key collision', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final result = verifyIncrementalLocaleReview(
        manifest: manifest,
        sourceProposal: _sourceProposal(),
        runtimeCatalogs: {
          'lib/l10n/app_es.arb': {
            '@@locale': 'es',
            'adaptiveFocusEyebrow': 'Ya existe',
          },
        },
        runtimeCatalogDigests: {'lib/l10n/app_es.arb': _digestA},
      );

      expect(result.passed, isFalse);
      expect(result.errors, contains('runtime_catalog_lock_mismatch:es'));
      expect(
        result.errors,
        contains('runtime_already_contains_delta:es:adaptiveFocusEyebrow'),
      );
    });

    test('fails closed when a message has no matching metadata', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final source = _sourceProposal()..remove('@adaptiveFocusEyebrow');
      final result = verifyIncrementalLocaleReview(
        manifest: manifest,
        sourceProposal: source,
        runtimeCatalogs: {
          'lib/l10n/app_es.arb': {'@@locale': 'es', 'existing': 'Existente'},
        },
        runtimeCatalogDigests: {'lib/l10n/app_es.arb': _digestB},
      );

      expect(result.passed, isFalse);
      expect(
        result.errors,
        contains('source_proposal_message_metadata_mismatch'),
      );
    });
  });

  group('incremental locale review preparation and acceptance', () {
    test('reuses the complete safety pipeline for a bounded delta', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final entry = manifest.locales.single;
      final result = prepareIncrementalLocaleReview(
        manifest: manifest,
        entry: entry,
        sourceProposal: _sourceProposal(),
        translationBundle: _translationBundle(),
      );

      expect(result.passed, isTrue, reason: result.errors.join('\n'));
      expect(result.reviewRows, hasLength(3));
      expect(result.reviewRows.map((row) => row['sequence']), ['1', '2', '3']);
      expect(
        result.reviewRows.singleWhere(
          (row) => row['key'] == 'adaptiveFocusCurrentPlan',
        )['placeholders'],
        'focusMinutes',
      );
      expect(result.contentSafety.passed, isTrue);
      expect(result.candidate['@@locale'], 'es');
    });

    test('rejects provider output that changes a placeholder name', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final bundle = _translationBundle();
      final translations = bundle['translations']! as Map<String, String>;
      translations['adaptiveFocusCurrentPlan'] =
          'Actual: {minutos} min de concentración';
      final result = prepareIncrementalLocaleReview(
        manifest: manifest,
        entry: manifest.locales.single,
        sourceProposal: _sourceProposal(),
        translationBundle: bundle,
      );

      expect(result.passed, isFalse);
      expect(result.errors, contains('candidate_not_structurally_ready'));
    });

    test('accepts only a complete immutable fluent review', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final entry = manifest.locales.single;
      final bundle = _translationBundle();
      final prepared = prepareIncrementalLocaleReview(
        manifest: manifest,
        entry: entry,
        sourceProposal: _sourceProposal(),
        translationBundle: bundle,
      );
      final rows = [
        for (final row in prepared.reviewRows)
          {...row, 'decision': 'ACCEPT', 'replacement': ''},
      ];

      final result = acceptIncrementalLocaleReview(
        manifest: manifest,
        entry: entry,
        sourceProposal: _sourceProposal(),
        translationBundle: bundle,
        reviewRows: rows,
      );

      expect(result.passed, isTrue, reason: result.errors.join('\n'));
      expect(result.decisionCounts['accepted'], 3);
      expect(result.decisionCounts['revised'], 0);
      expect(result.decisionCounts['blocked'], 0);
      expect(result.approvedCatalog['@@locale'], 'es');
    });

    test('rejects a missing decision without weakening other checks', () {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final entry = manifest.locales.single;
      final bundle = _translationBundle();
      final prepared = prepareIncrementalLocaleReview(
        manifest: manifest,
        entry: entry,
        sourceProposal: _sourceProposal(),
        translationBundle: bundle,
      );
      final rows = [
        for (final row in prepared.reviewRows)
          {...row, 'decision': 'ACCEPT', 'replacement': ''},
      ];
      rows.first['decision'] = '';

      final result = acceptIncrementalLocaleReview(
        manifest: manifest,
        entry: entry,
        sourceProposal: _sourceProposal(),
        translationBundle: bundle,
        reviewRows: rows,
      );

      expect(result.passed, isFalse);
      expect(
        result.errors.any(
          (error) => error.startsWith('missing_or_invalid_decision:'),
        ),
        isTrue,
      );
      expect(result.errors, contains('review_not_complete'));
    });
  });

  test(
    'workflow documentation keeps provider and runtime authority closed',
    () {
      final productionReview = File(
        'docs/ADAPTIVE_FOCUS_PRODUCTION_REVIEW.md',
      ).readAsStringSync();
      final localeWorkflow = File(
        'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
      ).readAsStringSync();
      final roadmap = File('docs/PRODUCT_ROADMAP.md').readAsStringSync();

      expect(
        localeWorkflow,
        contains(
          'For Adaptive Focus, the reviewed scope was exactly seventeen',
        ),
      );
      expect(
        productionReview,
        contains('## Incremental delta-review foundation'),
      );
      expect(productionReview, contains('cannot approve another'));
      expect(localeWorkflow, contains('Review a bounded message delta'));
      expect(localeWorkflow, contains('never call a translation provider'));
      expect(roadmap, contains('Existing runtime catalogs are not rewritten'));
    },
  );
}

const _digestA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _digestB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, dynamic> _manifestJson() => {
  'schemaVersion': 1,
  'workflow': incrementalLocaleReviewWorkflow,
  'deltaId': 'adaptive-focus-review-v1',
  'sourceProposal': 'localization/proposals/app_en_adaptive_focus_review.arb',
  'sourceProposalSha256': _digestA,
  'locales': [
    {
      'locale': 'es',
      'englishName': 'Spanish',
      'nativeName': 'Español',
      'reviewScope': 'general_spanish',
      'runtimeCatalog': 'lib/l10n/app_es.arb',
      'runtimeCatalogSha256': _digestB,
      'exceptionalGates': {
        'rightToLeft': false,
        'fontCoverage': false,
        'physicalScreenReader': false,
        'physicalSpeechRecognition': false,
        'storePromotion': false,
      },
    },
  ],
  'derivedFallbacks': <Map<String, dynamic>>[],
};

Map<String, dynamic> _sourceProposal() => {
  '@@locale': 'en',
  'adaptiveFocusEyebrow': 'ADAPTIVE FOCUS',
  '@adaptiveFocusEyebrow': {
    'description': 'Short label above the review card.',
  },
  'adaptiveFocusCurrentPlan': 'Current: {focusMinutes} min focus',
  '@adaptiveFocusCurrentPlan': {
    'description': 'Complete current Focus plan.',
    'placeholders': {
      'focusMinutes': {'type': 'int', 'example': '25'},
    },
  },
  'adaptiveFocusNoAutomaticChange':
      'Nothing changes unless you choose Use suggestion.',
  '@adaptiveFocusNoAutomaticChange': {
    'description': 'Disclosure that the review is optional.',
  },
};

Map<String, dynamic> _translationBundle() => {
  'schemaVersion': 1,
  'workflow': incrementalLocaleBundleWorkflow,
  'deltaId': 'adaptive-focus-review-v1',
  'locale': 'es',
  'sourceProposalSha256': _digestA,
  'translations': <String, String>{
    'adaptiveFocusEyebrow': 'FOCUS ADAPTATIVO',
    'adaptiveFocusCurrentPlan': 'Actual: {focusMinutes} min de concentración',
    'adaptiveFocusNoAutomaticChange':
        'Nada cambia a menos que elijas Usar sugerencia.',
  },
  'approvedSourceEqual': <String, String>{},
};
