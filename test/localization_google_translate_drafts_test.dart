import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_google_translate_drafts.dart';
import '../tool/localization_streamlined_batch.dart';
import '../tool/localization_streamlined_pipeline.dart';

const _sourceDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test('locks an exact private Google Advanced config per batch locale', () {
    final manifest = _sixLocaleManifest();
    final config = GoogleTranslationDraftConfig.fromJson(
      _providerConfigJson(manifest),
    );

    verifyGoogleTranslationDraftConfiguration(
      manifest: manifest,
      config: config,
    );

    expect(config.location, googleTranslationDraftLocation);
    expect(config.modelResource, contains('/models/general/nmt'));
    expect(config.locales.keys, ['id', 'tr', 'sv', 'nb', 'da', 'fi']);
    expect(
      config.locales.values.map((value) => value.glossary).toSet(),
      hasLength(6),
    );
  });

  test('rejects missing, reused, or cross-project glossaries', () {
    final manifest = _sixLocaleManifest();

    final missing = _providerConfigJson(manifest);
    (missing['locales'] as Map<String, dynamic>).remove('fi');
    final missingConfig = GoogleTranslationDraftConfig.fromJson(missing);
    expect(
      () => verifyGoogleTranslationDraftConfiguration(
        manifest: manifest,
        config: missingConfig,
      ),
      throwsFormatException,
    );

    final reused = _providerConfigJson(manifest);
    final reusedLocales = reused['locales'] as Map<String, dynamic>;
    (reusedLocales['fi'] as Map<String, dynamic>)['glossary'] =
        (reusedLocales['da'] as Map<String, dynamic>)['glossary'];
    expect(
      () => GoogleTranslationDraftConfig.fromJson(reused),
      throwsFormatException,
    );

    final crossProject = _providerConfigJson(manifest);
    final crossProjectLocales = crossProject['locales'] as Map<String, dynamic>;
    (crossProjectLocales['id'] as Map<String, dynamic>)['glossary'] =
        'projects/another-project/locations/us-central1/glossaries/focus-id';
    expect(
      () => GoogleTranslationDraftConfig.fromJson(crossProject),
      throwsFormatException,
    );
  });

  test(
    'chunks source messages deterministically below the configured limit',
    () {
      final chunks = buildGoogleTranslationDraftChunks(
        source: {'@@locale': 'en', 'c': 'cccc', 'a': 'aaaa', 'b': 'bbbb'},
        maxCodePointsPerRequest: 8,
      );

      expect(chunks, hasLength(2));
      expect(chunks.first.keys, ['a', 'b']);
      expect(chunks.first.contents, ['aaaa', 'bbbb']);
      expect(chunks.first.codePointCount, 8);
      expect(chunks.last.keys, ['c']);
    },
  );

  test(
    'creates only the existing locked bundle schema after safety passes',
    () async {
      final source = _source();
      final plan = _plan('id');
      final config = GoogleTranslationDraftLocaleConfig(
        targetLanguageCode: 'id',
        glossary:
            'projects/focushaven-l10n/locations/us-central1/glossaries/focus-id',
        approvedSourceEqual: const {
          'appTitle': 'The registered product name remains invariant.',
        },
      );
      final translatedBySource = {
        'FocusHaven': 'FocusHaven',
        'Hello, {name}': 'Halo, {name}',
        'Pause for 60 minutes': 'Jeda selama 60 menit',
      };

      final bundle = await buildGoogleTranslationDraftBundle(
        plan: plan,
        localeConfig: config,
        source: source,
        maxCodePointsPerRequest: 5000,
        sender:
            ({required locale, required glossary, required contents}) async =>
                contents.map((value) => translatedBySource[value]!).toList(),
      );

      expect(bundle.keys, {
        'schemaVersion',
        'workflow',
        'locale',
        'sourceCatalogSha256',
        'translations',
        'approvedSourceEqual',
      });
      expect(bundle['locale'], 'id');
      expect(
        (bundle['translations'] as Map<String, String>)['duration'],
        'Jeda selama 60 menit',
      );
    },
  );

  test('fails closed on unapproved or stale source-equal output', () async {
    Future<void> build(Map<String, String> approvedSourceEqual) async {
      await buildGoogleTranslationDraftBundle(
        plan: _plan('id'),
        localeConfig: GoogleTranslationDraftLocaleConfig(
          targetLanguageCode: 'id',
          glossary:
              'projects/focushaven-l10n/locations/us-central1/glossaries/focus-id',
          approvedSourceEqual: approvedSourceEqual,
        ),
        source: _source(),
        maxCodePointsPerRequest: 5000,
        sender:
            ({required locale, required glossary, required contents}) async => [
              for (final value in contents)
                switch (value) {
                  'Hello, {name}' => 'Halo, {name}',
                  'Pause for 60 minutes' => 'Jeda selama 60 menit',
                  _ => value,
                },
            ],
      );
    }

    await expectLater(
      build(const {}),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'unapproved_source_equal:appTitle',
        ),
      ),
    );
    await expectLater(
      build(const {
        'appTitle': 'The registered product name remains invariant.',
        'duration': 'A human approved this source-equal value.',
      }),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'stale_source_equal_approval:duration',
        ),
      ),
    );
  });

  test(
    'rejects malformed provider output without exposing response text',
    () async {
      final future = buildGoogleTranslationDraftBundle(
        plan: _plan('id'),
        localeConfig: const GoogleTranslationDraftLocaleConfig(
          targetLanguageCode: 'id',
          glossary:
              'projects/focushaven-l10n/locations/us-central1/glossaries/focus-id',
          approvedSourceEqual: {},
        ),
        source: _source(),
        maxCodePointsPerRequest: 5000,
        sender:
            ({required locale, required glossary, required contents}) async =>
                const ['unexpected private provider response'],
      );

      await expectLater(
        future,
        throwsA(
          isA<GoogleTranslationDraftFailure>().having(
            (error) => error.code,
            'code',
            'provider_response_count_mismatch',
          ),
        ),
      );
    },
  );

  test('new Latin locales inherit time-unit and foreign-script safeguards', () {
    const minuteTranslations = {
      'id': '60 menit',
      'tr': '60 dakika',
      'sv': '60 minuter',
      'nb': '60 minutter',
      'da': '60 minutter',
      'fi': '60 minuuttia',
    };
    const secondTranslations = {
      'id': '60 detik',
      'tr': '60 saniye',
      'sv': '60 sekunder',
      'nb': '60 sekunder',
      'da': '60 sekunder',
      'fi': '60 sekuntia',
    };

    for (final locale in minuteTranslations.keys) {
      final valid = auditStreamlinedLocaleContent(
        plan: _plan(locale),
        source: {'@@locale': 'en', 'duration': 'Pause for 60 minutes'},
        candidate: {'@@locale': locale, 'duration': minuteTranslations[locale]},
      );
      final drift = auditStreamlinedLocaleContent(
        plan: _plan(locale),
        source: {'@@locale': 'en', 'duration': 'Pause for 60 minutes'},
        candidate: {'@@locale': locale, 'duration': secondTranslations[locale]},
      );
      final contamination = auditStreamlinedLocaleContent(
        plan: _plan(locale),
        source: {'@@locale': 'en', 'weekday': 'Tuesday'},
        candidate: {'@@locale': locale, 'weekday': '日本日本日本日本'},
      );

      expect(valid.errors, isEmpty, reason: locale);
      expect(
        drift.errors,
        contains('candidate_time_unit_drift:duration'),
        reason: locale,
      );
      expect(
        contamination.errors,
        contains('candidate_unexpected_script:weekday'),
        reason: locale,
      );
    }
  });
}

StreamlinedLocalePlan _plan(String locale) => StreamlinedLocalePlan.fromJson({
  'schemaVersion': 1,
  'workflow': streamlinedLocaleWorkflow,
  'locale': locale,
  'englishName': locale,
  'nativeName': locale,
  'reviewScope': '${locale}_review',
  'sourceCatalog': 'lib/l10n/app_en.arb',
  'sourceCatalogSha256': _sourceDigest,
  'candidateCatalog': 'localization/candidates/app_$locale.arb',
  'structuralAudit': 'localization/reviews/$locale/structural-audit.json',
  'approvedCatalog': 'localization/reviews/$locale/app_$locale.approved.arb',
  'validationRecord':
      'localization/reviews/$locale/private-human-validation.json',
  'runtimeCatalog': 'lib/l10n/app_$locale.arb',
  'exceptionalGates': streamlinedLocaleClosedExceptionalGates,
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
  'duration': 'Pause for 60 minutes',
  '@duration': {'description': 'A timer duration.'},
};

StreamlinedLocaleBatchManifest _sixLocaleManifest() =>
    StreamlinedLocaleBatchManifest.fromJson({
      'schemaVersion': 1,
      'workflow': streamlinedLocaleBatchWorkflow,
      'sourceCatalog': 'lib/l10n/app_en.arb',
      'sourceCatalogSha256': _sourceDigest,
      'maxParallelism': 3,
      'locales': const [
        {
          'locale': 'id',
          'englishName': 'Indonesian',
          'nativeName': 'Bahasa Indonesia',
          'reviewScope': 'general_indonesian',
        },
        {
          'locale': 'tr',
          'englishName': 'Turkish',
          'nativeName': 'Türkçe',
          'reviewScope': 'general_turkish',
        },
        {
          'locale': 'sv',
          'englishName': 'Swedish',
          'nativeName': 'Svenska',
          'reviewScope': 'general_swedish',
        },
        {
          'locale': 'nb',
          'englishName': 'Norwegian Bokmål',
          'nativeName': 'Norsk bokmål',
          'reviewScope': 'norwegian_bokmal',
        },
        {
          'locale': 'da',
          'englishName': 'Danish',
          'nativeName': 'Dansk',
          'reviewScope': 'general_danish',
        },
        {
          'locale': 'fi',
          'englishName': 'Finnish',
          'nativeName': 'Suomi',
          'reviewScope': 'general_finnish',
        },
      ],
    });

Map<String, dynamic> _providerConfigJson(
  StreamlinedLocaleBatchManifest manifest,
) => {
  'schemaVersion': 1,
  'workflow': googleTranslationDraftWorkflow,
  'projectId': 'focushaven-l10n',
  'location': 'us-central1',
  'model': 'general/nmt',
  'maxCodePointsPerRequest': 4500,
  'locales': {
    for (final entry in manifest.locales)
      entry.locale: {
        'targetLanguageCode': entry.locale,
        'glossary':
            'projects/focushaven-l10n/locations/us-central1/glossaries/focus-${entry.locale}',
        'approvedSourceEqual': <String, String>{},
      },
  },
};
