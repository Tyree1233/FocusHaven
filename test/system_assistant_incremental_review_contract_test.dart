import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_incremental_review.dart';
import 'support/localization_catalog_prefix.dart';

void main() {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const localeSpecs = <(String, String, String, String, bool)>[
    ('es', 'Spanish', 'Español', 'general_spanish', false),
    ('fr', 'French', 'Français', 'general_french', false),
    ('de', 'German', 'Deutsch', 'general_german', false),
    (
      'pt-BR',
      'Brazilian Portuguese',
      'Português (Brasil)',
      'brazilian_portuguese',
      false,
    ),
    ('ja', 'Japanese', '日本語', 'japanese_cjk', true),
    ('ko', 'Korean', '한국어', 'korean_cjk', true),
    ('it', 'Italian', 'Italiano', 'general_italian', false),
    ('pl', 'Polish', 'Polski', 'general_polish', false),
    ('nl', 'Dutch', 'Nederlands', 'general_dutch', false),
    ('id', 'Indonesian', 'Bahasa Indonesia', 'general_indonesian', false),
    ('tr', 'Turkish', 'Türkçe', 'general_turkish', false),
    ('sv', 'Swedish', 'Svenska', 'general_swedish', false),
    ('nb', 'Norwegian Bokmål', 'Norsk bokmål', 'norwegian_bokmal', false),
    ('da', 'Danish', 'Dansk', 'general_danish', false),
    ('fi', 'Finnish', 'Suomi', 'general_finnish', false),
  ];

  IncrementalLocaleReviewManifest manifest() =>
      IncrementalLocaleReviewManifest.fromJson({
        'schemaVersion': 1,
        'workflow': incrementalLocaleReviewWorkflow,
        'deltaId': 'system-assistant-review-v1',
        'sourceProposal':
            'localization/proposals/app_en_system_assistant_review.arb',
        'sourceProposalSha256': digest,
        'locales': [
          for (final spec in localeSpecs)
            {
              'locale': spec.$1,
              'englishName': spec.$2,
              'nativeName': spec.$3,
              'reviewScope': spec.$4,
              'runtimeCatalog':
                  'lib/l10n/app_${spec.$1.replaceAll('-', '_')}.arb',
              'runtimeCatalogSha256': digest,
              'exceptionalGates': {
                'rightToLeft': false,
                'fontCoverage': spec.$5,
                'physicalScreenReader': false,
                'physicalSpeechRecognition': false,
                'storePromotion': false,
              },
            },
        ],
        'derivedFallbacks': [
          {
            'reviewedLocale': 'pt-BR',
            'fallbackLocale': 'pt',
            'runtimeCatalog': 'lib/l10n/app_pt.arb',
            'runtimeCatalogSha256': digest,
          },
        ],
      });

  Map<String, dynamic> proposal() =>
      jsonDecode(
            File(
              'localization/proposals/app_en_system_assistant_review.arb',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('locks fifteen independent reviews and one Portuguese fallback', () {
    final value = manifest();

    expect(value.deltaId, 'system-assistant-review-v1');
    expect(
      value.locales.map((entry) => entry.locale),
      localeSpecs.map((spec) => spec.$1),
    );
    expect(value.locales, hasLength(15));
    expect(
      value.locales
          .where((entry) => entry.exceptionalGates['fontCoverage']!)
          .map((entry) => entry.locale),
      ['ja', 'ko'],
    );
    expect(value.derivedFallbacks, hasLength(1));
    expect(value.derivedFallbacks.single.reviewedLocale, 'pt-BR');
    expect(value.derivedFallbacks.single.fallbackLocale, 'pt');
  });

  test('preflights the exact eleven-message delta outside runtime', () {
    final value = manifest();
    final catalogs = <String, Map<String, dynamic>>{};
    final digests = <String, String>{};
    for (final path in {
      ...value.locales.map((entry) => entry.runtimeCatalog),
      ...value.derivedFallbacks.map((entry) => entry.runtimeCatalog),
    }) {
      catalogs[path] = catalogBeforeSystemAssistant(path);
      digests[path] = digest;
    }

    final result = verifyIncrementalLocaleReview(
      manifest: value,
      sourceProposal: proposal(),
      runtimeCatalogs: catalogs,
      runtimeCatalogDigests: digests,
    );

    expect(result.passed, isTrue, reason: result.errors.join('\n'));
    expect(result.messageCount, 11);
    expect(result.metadataCount, 11);
    expect(result.runtimeCatalogCount, 16);
    expect(result.summary(value), containsPair('providerRequestMade', false));
    expect(result.summary(value), containsPair('reviewWorkbookCreated', false));
    expect(result.summary(value), containsPair('runtimeActivated', false));
  });

  test('fails closed if one runtime catalog already contains the delta', () {
    final value = manifest();
    final source = proposal();
    final firstKey = source.keys.firstWhere(
      (key) => key != '@@locale' && !key.startsWith('@'),
    );
    final catalogs = <String, Map<String, dynamic>>{};
    final digests = <String, String>{};
    for (final path in {
      ...value.locales.map((entry) => entry.runtimeCatalog),
      ...value.derivedFallbacks.map((entry) => entry.runtimeCatalog),
    }) {
      catalogs[path] = catalogBeforeSystemAssistant(path);
      digests[path] = digest;
    }
    catalogs['lib/l10n/app_es.arb']![firstKey] = 'Already present';

    final result = verifyIncrementalLocaleReview(
      manifest: value,
      sourceProposal: source,
      runtimeCatalogs: catalogs,
      runtimeCatalogDigests: digests,
    );

    expect(result.passed, isFalse);
    expect(
      result.errors,
      contains('runtime_already_contains_delta:es:$firstKey'),
    );
  });

  test(
    'documentation preserves review history and keeps native gates closed',
    () {
      String normalize(String value) =>
          value.replaceAll(RegExp(r'\s+'), ' ').trim();

      final readme = normalize(File('README.md').readAsStringSync());
      final policy = normalize(
        File('docs/SYSTEM_ASSISTANT_PRODUCTION_REVIEW.md').readAsStringSync(),
      );
      final workflow = normalize(
        File(
          'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
        ).readAsStringSync(),
      );
      final roadmap = normalize(
        File('docs/PRODUCT_ROADMAP.md').readAsStringSync(),
      );

      expect(readme, contains('those eleven messages as a'));
      expect(readme, contains('reviewed production integration now places'));
      expect(policy, contains('## Incremental delta-review foundation'));
      expect(policy, contains('One language cannot approve another'));
      expect(policy, contains('no provider configuration'));
      expect(policy, contains('No production native producer is registered'));
      expect(workflow, contains('exactly eleven messages'));
      expect(workflow, contains('creates no provider config'));
      expect(
        workflow,
        contains('native registration remain separate release gates'),
      );
      expect(roadmap, contains('incremental-review foundation'));
      expect(roadmap, contains('creates no provider draft'));
      expect(
        roadmap,
        contains('subsequent Phase 217D integration accepts all 165'),
      );
    },
  );
}
