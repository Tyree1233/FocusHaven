import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_incremental_review.dart';

void main() {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const proposalPath =
      'localization/proposals/app_en_android_system_assistant_native_review.arb';
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
        'deltaId': 'android-system-assistant-native-copy-v1',
        'sourceProposal': proposalPath,
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
      jsonDecode(File(proposalPath).readAsStringSync()) as Map<String, dynamic>;

  test('locks fifteen independent reviews and Portuguese derivation', () {
    final value = manifest();

    expect(value.deltaId, 'android-system-assistant-native-copy-v1');
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

  test('preflights the exact twenty-eight-message native delta', () {
    final value = manifest();
    final catalogs = <String, Map<String, dynamic>>{};
    final digests = <String, String>{};
    for (final path in {
      ...value.locales.map((entry) => entry.runtimeCatalog),
      ...value.derivedFallbacks.map((entry) => entry.runtimeCatalog),
    }) {
      catalogs[path] =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      digests[path] = digest;
    }

    final result = verifyIncrementalLocaleReview(
      manifest: value,
      sourceProposal: proposal(),
      runtimeCatalogs: catalogs,
      runtimeCatalogDigests: digests,
    );

    expect(result.passed, isTrue, reason: result.errors.join('\n'));
    expect(result.messageCount, 28);
    expect(result.metadataCount, 28);
    expect(result.runtimeCatalogCount, 16);
    expect(result.summary(value), containsPair('providerRequestMade', false));
    expect(result.summary(value), containsPair('reviewWorkbookCreated', false));
    expect(result.summary(value), containsPair('runtimeActivated', false));
  });

  test('review helpers retain deterministic private paths', () {
    final value = manifest();

    for (final entry in value.locales) {
      expect(
        entry.bundlePath('/private/drafts'),
        '/private/drafts/focushaven-${entry.locale}-incremental-translations.json',
      );
      expect(
        entry.reviewPath('/private/reviews'),
        '/private/reviews/focushaven-${entry.locale}-incremental-review.csv',
      );
      expect(
        entry.approvedPath('/private/approved'),
        '/private/approved/app_${entry.arbLocale}.incremental.approved.arb',
      );
    }
  });

  test('documentation forbids runtime and public Android integration', () {
    String normalize(String value) =>
        value.replaceAll(RegExp(r'\s+'), ' ').trim();

    final review = normalize(
      File(
        'docs/ANDROID_SYSTEM_ASSISTANT_NATIVE_COPY_REVIEW.md',
      ).readAsStringSync(),
    );
    final workflow = normalize(
      File(
        'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
      ).readAsStringSync(),
    );

    expect(review, contains('twenty-eight complete messages'));
    expect(review, contains('Fifteen-language incremental review'));
    expect(review, contains('must never be merged into the Flutter ARB'));
    expect(review, contains('Android string resources only by a separate'));
    expect(review, contains('Provider-assisted drafts require separate'));
    expect(workflow, contains('Android-native system-assistant copy'));
    expect(workflow, contains('not Flutter runtime content'));
    expect(workflow, contains('public App Actions registration stays closed'));
  });
}
