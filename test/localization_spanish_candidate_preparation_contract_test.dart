import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

void main() {
  test('C1A preparation remains recorded after the C1B candidate', () {
    final review =
        jsonDecode(_read('localization/reviews/es/qualification.json'))
            as Map<String, dynamic>;

    expect(review['phase'], '215G-C1B');
    expect(review['candidatePreparationPhase'], '215G-C1A');
    expect(review['candidateGenerationPhase'], '215G-C1B');
    expect(review['candidatePreparationReady'], isTrue);
    expect(review['translationBundlePresent'], isFalse);
    expect(review['translationBundleCommitted'], isFalse);
    expect(review['candidatePresent'], isTrue);
    expect(review['structuralAuditPassed'], isTrue);
    expect(review['humanReviewer'], isNull);
    expect(review['approvedAt'], isNull);
    expect(review['runtimeActivated'], isTrue);
    expect(review['externalTranslationProviderApproved'], isFalse);
    expect(review['externalTranslationProviderUsed'], isFalse);
  });

  test('candidate builder is isolated, locked, and fail closed', () {
    final builder = _read('tool/localization_spanish_candidate_builder.dart');

    expect(builder, contains("const spanishCandidatePhase = '215G-C1A'"));
    expect(
      builder,
      contains(
        "const spanishCandidateOutput = 'localization/candidates/app_es.arb'",
      ),
    );
    expect(builder, contains('sourceCatalogSha256Matches'));
    expect(
      builder,
      contains("const spanishSourceCatalog = 'lib/l10n/app_en.arb'"),
    );
    expect(builder, contains("Process.runSync('shasum'"));
    expect(builder, contains('missingTranslations'));
    expect(builder, contains('extraTranslations'));
    expect(builder, contains('invalidSourceEqualDecisions'));
    expect(builder, contains('qualification.readyForHumanReview'));
    expect(builder, contains('output.existsSync()'));
    expect(builder, isNot(contains('translation provider')));
  });

  test('Spanish integration stays outside the production allowlist', () {
    expect(FocusHavenLocales.productionLocales, const [
      Locale('en'),
      Locale('es'),
    ]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.production,
    );
    expect(File('lib/l10n/app_es.arb').existsSync(), isTrue);
    expect(File('localization/candidates/app_es.arb').existsSync(), isTrue);
    expect(
      File('localization/intake/es/translations.json').existsSync(),
      isFalse,
    );
  });

  test('C1A documentation preserves human review and privacy gates', () {
    final preparation = _normalize(
      _read('docs/LOCALIZATION_SPANISH_CANDIDATE_PREPARATION.md'),
    );
    final qualification = _normalize(
      _read('docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));

    for (final required in <String>[
      'Spanish remains planned and inactive',
      'does not create a Spanish candidate',
      'qualified human reviewer',
      'private runtime values',
      'localization/candidates/app_es.arb',
      'lib/l10n',
      'external translation provider',
    ]) {
      expect(preparation, contains(required), reason: required);
    }
    expect(qualification, contains('Phase 215G-C1A'));
    expect(policy, contains('Phase 215G-C1A'));
    expect(roadmap, contains('Phase 215G-C1A'));
    expect(readme, contains('Phase 215G-C1A'));
    expect(preparation, contains('Phase 215G-C1B'));
    expect(qualification, contains('Phase 215G-C1B'));
    expect(policy, contains('Phase 215G-C1B'));
    expect(roadmap, contains('Phase 215G-C1B'));
    expect(readme, contains('Phase 215G-C1B'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
