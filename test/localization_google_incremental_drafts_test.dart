import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_google_incremental_drafts.dart';
import '../tool/localization_google_translate_drafts.dart';
import '../tool/localization_incremental_review.dart';

const _proposalDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _runtimeDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('locks one distinct Google glossary to every incremental locale', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());

    verifyGoogleIncrementalTranslationDraftConfiguration(
      manifest: manifest,
      config: config,
    );

    expect(config.locales.keys, ['es', 'fr']);
    expect(
      config.locales.values.map((value) => value.glossary).toSet(),
      hasLength(2),
    );
  });

  test('rejects a missing or extra incremental provider locale', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final missingJson = _configJson();
    (missingJson['locales'] as Map<String, dynamic>).remove('fr');
    final extraJson = _configJson();
    (extraJson['locales'] as Map<String, dynamic>)['de'] = _localeConfigJson(
      'de',
    );

    expect(
      () => verifyGoogleIncrementalTranslationDraftConfiguration(
        manifest: manifest,
        config: GoogleTranslationDraftConfig.fromJson(missingJson),
      ),
      throwsFormatException,
    );
    expect(
      () => verifyGoogleIncrementalTranslationDraftConfiguration(
        manifest: manifest,
        config: GoogleTranslationDraftConfig.fromJson(extraJson),
      ),
      throwsFormatException,
    );
  });

  test('maps reviewed pt-BR only to Google target code pt', () {
    final accepted = GoogleTranslationDraftLocaleConfig.fromJson(
      'pt-BR',
      {
        'targetLanguageCode': 'pt',
        'glossary':
            'projects/focushaven-l10n/locations/us-central1/glossaries/focus-pt-br',
        'approvedSourceEqual': <String, String>{},
      },
      projectId: 'focushaven-l10n',
      location: googleTranslationDraftLocation,
    );

    expect(accepted.targetLanguageCode, 'pt');
    expect(
      () => GoogleTranslationDraftLocaleConfig.fromJson(
        'pt-BR',
        {
          'targetLanguageCode': 'es',
          'glossary':
              'projects/focushaven-l10n/locations/us-central1/glossaries/focus-pt-br',
          'approvedSourceEqual': <String, String>{},
        },
        projectId: 'focushaven-l10n',
        location: googleTranslationDraftLocation,
      ),
      throwsFormatException,
    );
  });

  test('preflight is bounded, recoverable, and makes no provider request', () {
    final summary = googleIncrementalTranslationPreflightSummary(
      manifest: IncrementalLocaleReviewManifest.fromJson(_manifestJson()),
      config: GoogleTranslationDraftConfig.fromJson(_configJson()),
      sourceProposal: _sourceProposal(),
    );

    expect(summary['passed'], isTrue);
    expect(summary['deltaId'], 'adaptive-focus-review-v1');
    expect(summary['localeCount'], 2);
    expect(summary['messageCountPerLocale'], 3);
    expect(summary['maxParallelism'], 3);
    expect(summary['providerMimeType'], 'text/html');
    expect(summary['icuPlaceholderShielding'], isTrue);
    expect(summary['recoverablePrivateQuarantineEnabled'], isTrue);
    expect(summary['externalRequestMade'], isFalse);
    expect(summary['runtimeActivated'], isFalse);
  });

  test('builds only the locked incremental bundle after safety passes', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());
    final entry = manifest.locales.first;
    final bundle = buildGoogleIncrementalTranslationDraftBundle(
      manifest: manifest,
      entry: entry,
      localeConfig: config.locales[entry.locale]!,
      sourceProposal: _sourceProposal(),
      translations: _spanishTranslations(),
    );

    expect(bundle.keys, {
      'schemaVersion',
      'workflow',
      'deltaId',
      'locale',
      'sourceProposalSha256',
      'translations',
      'approvedSourceEqual',
    });
    expect(bundle['workflow'], incrementalLocaleBundleWorkflow);
    expect(bundle['deltaId'], manifest.deltaId);
    expect(bundle['locale'], 'es');
    expect(bundle['sourceProposalSha256'], _proposalDigest);
    expect(
      (bundle['translations']
          as Map<String, String>)['adaptiveFocusCurrentPlan'],
      'Actual: {focusMinutes} min de concentración',
    );
  });

  test('incremental bundle refuses changed ICU and source-equal output', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());
    final entry = manifest.locales.first;
    final changedIcu = _spanishTranslations()
      ..['adaptiveFocusCurrentPlan'] = 'Actual: {minutos} min de concentración';
    final sourceEqual = _spanishTranslations()
      ..['adaptiveFocusEyebrow'] = 'ADAPTIVE FOCUS';

    expect(
      () => buildGoogleIncrementalTranslationDraftBundle(
        manifest: manifest,
        entry: entry,
        localeConfig: config.locales[entry.locale]!,
        sourceProposal: _sourceProposal(),
        translations: changedIcu,
      ),
      throwsA(isA<GoogleTranslationDraftFailure>()),
    );
    expect(
      () => buildGoogleIncrementalTranslationDraftBundle(
        manifest: manifest,
        entry: entry,
        localeConfig: config.locales[entry.locale]!,
        sourceProposal: _sourceProposal(),
        translations: sourceEqual,
      ),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.allCodes,
          'diagnostics',
          contains('unapproved_source_equal:adaptiveFocusEyebrow'),
        ),
      ),
    );
  });

  test(
    'provider fetch shields and restores the incremental ICU value',
    () async {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final config = GoogleTranslationDraftConfig.fromJson(_configJson());
      final entry = manifest.locales.first;
      final sent = <String>[];

      final translations = await fetchGoogleTranslationDraftTranslations(
        plan: incrementalLocalePlanFor(manifest, entry),
        localeConfig: config.locales[entry.locale]!,
        source: _sourceProposal(),
        maxCodePointsPerRequest: 5000,
        sender:
            ({required locale, required glossary, required contents}) async {
              sent.addAll(contents);
              return [
                for (final value in contents)
                  value
                      .replaceAll('ADAPTIVE FOCUS', 'FOCUS ADAPTATIVO')
                      .replaceAll('Current:', 'Actual:')
                      .replaceAll('min focus', 'min de concentración')
                      .replaceAll(
                        'Nothing changes unless you choose Use suggestion.',
                        'Nada cambia a menos que elijas Usar sugerencia.',
                      ),
              ];
            },
      );

      expect(sent, everyElement(isNot(contains('{focusMinutes}'))));
      expect(sent.join(), contains('FHICU'));
      expect(
        translations['adaptiveFocusCurrentPlan'],
        'Actual: {focusMinutes} min de concentración',
      );
    },
  );

  test('provider sender receives the configured Google target code', () async {
    final manifestJson = _manifestJson();
    final locales = manifestJson['locales'] as List<dynamic>;
    locales[0] = _manifestLocaleJson(
      'pt-BR',
      'Brazilian Portuguese',
      'Português (Brasil)',
    );
    final manifest = IncrementalLocaleReviewManifest.fromJson(manifestJson);
    final localeConfig = GoogleTranslationDraftLocaleConfig.fromJson(
      'pt-BR',
      {
        'targetLanguageCode': 'pt',
        'glossary':
            'projects/focushaven-l10n/locations/us-central1/glossaries/focus-pt-br',
        'approvedSourceEqual': <String, String>{},
      },
      projectId: 'focushaven-l10n',
      location: googleTranslationDraftLocation,
    );
    String? sentLocale;

    await fetchGoogleTranslationDraftTranslations(
      plan: incrementalLocalePlanFor(manifest, manifest.locales.first),
      localeConfig: localeConfig,
      source: _sourceProposal(),
      maxCodePointsPerRequest: 5000,
      sender: ({required locale, required glossary, required contents}) async {
        sentLocale = locale;
        return [
          for (final value in contents)
            value
                .replaceAll('ADAPTIVE FOCUS', 'FOCO ADAPTATIVO')
                .replaceAll('Current:', 'Atual:')
                .replaceAll('min focus', 'min de foco')
                .replaceAll(
                  'Nothing changes unless you choose Use suggestion.',
                  'Nada muda a menos que você escolha Usar sugestão.',
                ),
        ];
      },
    );

    expect(sentLocale, 'pt');
  });

  test('private quarantine is exact and bound to delta and glossary', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());
    final entry = manifest.locales.first;
    final localeConfig = config.locales[entry.locale]!;
    final quarantine = buildGoogleIncrementalTranslationQuarantine(
      manifest: manifest,
      entry: entry,
      config: config,
      localeConfig: localeConfig,
      translations: _spanishTranslations(),
    );

    expect(
      verifyGoogleIncrementalTranslationQuarantine(
        quarantine: quarantine,
        manifest: manifest,
        entry: entry,
        config: config,
        localeConfig: localeConfig,
        sourceProposal: _sourceProposal(),
      ),
      _spanishTranslations(),
    );

    final changed = Map<String, dynamic>.from(quarantine)
      ..['deltaId'] = 'another-delta';
    expect(
      () => verifyGoogleIncrementalTranslationQuarantine(
        quarantine: changed,
        manifest: manifest,
        entry: entry,
        config: config,
        localeConfig: localeConfig,
        sourceProposal: _sourceProposal(),
      ),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'incremental_quarantine_binding_mismatch',
        ),
      ),
    );
  });

  test(
    'raw provider HTML is observed before local decoding can fail',
    () async {
      final manifest = IncrementalLocaleReviewManifest.fromJson(
        _manifestJson(),
      );
      final config = GoogleTranslationDraftConfig.fromJson(_configJson());
      final entry = manifest.locales.first;
      Map<String, String>? observed;

      await expectLater(
        fetchGoogleTranslationDraftTranslations(
          plan: incrementalLocalePlanFor(manifest, entry),
          localeConfig: config.locales[entry.locale]!,
          source: _sourceProposal(),
          maxCodePointsPerRequest: 5000,
          sender:
              ({
                required locale,
                required glossary,
                required contents,
              }) async => [
                for (var index = 0; index < contents.length; index += 1)
                  index == 0 ? '<b>${contents[index]}</b>' : contents[index],
              ],
          onProviderHtml: (providerHtml) => observed = providerHtml,
        ),
        throwsA(
          isA<GoogleTranslationDraftFailure>().having(
            (error) => error.code,
            'code',
            'provider_html_mismatch',
          ),
        ),
      );

      expect(observed, isNotNull);
      expect(observed, hasLength(3));
      expect(observed!.values, contains(startsWith('<b>')));
    },
  );

  test('restores one adjacent bare ICU marker echo before its span', () {
    const source = 'Review: {reason} Nothing changes.';
    final protected = protectGoogleTranslationIcu(source);
    final echoed = protected.html.replaceFirst(
      '<span translate="no">FHICU0000X</span>',
      'FHICU0000X <span translate="no">FHICU0000X</span>',
    );

    expect(
      restoreGoogleTranslationIcu(protected: protected, providerHtml: echoed),
      source,
    );
  });

  test('rejects nonadjacent or repeated bare ICU marker echoes', () {
    const source = 'Review: {reason} Nothing changes.';
    final protected = protectGoogleTranslationIcu(source);
    const span = '<span translate="no">FHICU0000X</span>';
    final nonadjacent = protected.html.replaceFirst(
      span,
      'FHICU0000X translated $span',
    );
    final repeated = protected.html.replaceFirst(
      span,
      'FHICU0000X FHICU0000X $span',
    );

    for (final refused in [nonadjacent, repeated]) {
      expect(
        () => restoreGoogleTranslationIcu(
          protected: protected,
          providerHtml: refused,
        ),
        throwsA(
          isA<GoogleTranslationDraftFailure>().having(
            (error) => error.code,
            'code',
            'provider_html_mismatch',
          ),
        ),
      );
    }
  });

  test('raw provider response is exact and bound before offline decode', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());
    final entry = manifest.locales.first;
    final localeConfig = config.locales[entry.locale]!;
    final providerHtml = <String, String>{
      for (final sourceEntry in _sourceProposal().entries)
        if (!sourceEntry.key.startsWith('@'))
          sourceEntry.key: sourceEntry.key == 'adaptiveFocusEyebrow'
              ? '<b>${sourceEntry.value}</b>'
              : protectGoogleTranslationIcu(sourceEntry.value as String).html,
    };
    final response = buildGoogleIncrementalProviderResponse(
      manifest: manifest,
      entry: entry,
      config: config,
      localeConfig: localeConfig,
      providerHtml: providerHtml,
    );

    expect(
      verifyGoogleIncrementalProviderResponse(
        response: response,
        manifest: manifest,
        entry: entry,
        config: config,
        localeConfig: localeConfig,
        sourceProposal: _sourceProposal(),
      ),
      providerHtml,
    );
    expect(
      () => restoreGoogleTranslationDraftProviderHtml(
        source: _sourceProposal(),
        providerHtml: providerHtml,
      ),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'provider_html_mismatch',
        ),
      ),
    );

    final changed = Map<String, dynamic>.from(response)
      ..['projectId'] = 'different-project';
    expect(
      () => verifyGoogleIncrementalProviderResponse(
        response: changed,
        manifest: manifest,
        entry: entry,
        config: config,
        localeConfig: localeConfig,
        sourceProposal: _sourceProposal(),
      ),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'incremental_provider_response_binding_mismatch',
        ),
      ),
    );
  });

  test('targeted repair requires one empty target and exact saved peers', () {
    final manifest = IncrementalLocaleReviewManifest.fromJson(_manifestJson());
    final config = GoogleTranslationDraftConfig.fromJson(_configJson());
    final sourceProposal = _sourceProposal();
    final directory = Directory.systemTemp.createTempSync(
      'focushaven-incremental-repair-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final peer = manifest.locales.singleWhere((entry) => entry.locale == 'fr');
    final bundle = buildGoogleIncrementalTranslationDraftBundle(
      manifest: manifest,
      entry: peer,
      localeConfig: config.locales[peer.locale]!,
      sourceProposal: sourceProposal,
      translations: _spanishTranslations(),
    );
    File(peer.bundlePath(directory.path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(bundle)}\n',
      );

    expect(
      () => verifyGoogleIncrementalTargetedRepairState(
        manifest: manifest,
        config: config,
        sourceProposal: sourceProposal,
        outputDirectory: directory.path,
        targetLocale: 'es',
      ),
      returnsNormally,
    );

    final target = manifest.locales.singleWhere(
      (entry) => entry.locale == 'es',
    );
    File(target.bundlePath(directory.path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{}\n');
    expect(
      () => verifyGoogleIncrementalTargetedRepairState(
        manifest: manifest,
        config: config,
        sourceProposal: sourceProposal,
        outputDirectory: directory.path,
        targetLocale: 'es',
      ),
      throwsA(
        isA<GoogleTranslationDraftFailure>().having(
          (error) => error.code,
          'code',
          'incremental_repair_target_not_empty:es',
        ),
      ),
    );
  });

  test('all seventeen proposed messages round-trip through ICU shielding', () {
    final proposal =
        jsonDecode(
              File(
                'localization/proposals/app_en_adaptive_focus_review.arb',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final messageKeys = proposal.keys
        .where((key) => !key.startsWith('@'))
        .toList();

    expect(messageKeys, hasLength(17));
    for (final key in messageKeys) {
      final value = proposal[key] as String;
      final protected = protectGoogleTranslationIcu(value);
      expect(
        restoreGoogleTranslationIcu(
          protected: protected,
          providerHtml: protected.html,
        ),
        value,
        reason: key,
      );
    }
  });

  test('documentation keeps generation explicit and runtime closed', () {
    final readme = File('README.md').readAsStringSync();
    final productionReview = File(
      'docs/ADAPTIVE_FOCUS_PRODUCTION_REVIEW.md',
    ).readAsStringSync();
    final localeWorkflow = File(
      'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
    ).readAsStringSync();
    final roadmap = File('docs/PRODUCT_ROADMAP.md').readAsStringSync();

    expect(readme, contains('Google-assisted incremental drafts'));
    expect(productionReview, contains('provider-draft foundation'));
    expect(localeWorkflow, contains('Google-assisted incremental drafts'));
    expect(localeWorkflow, contains('explicitly authorized `translate`'));
    expect(roadmap, contains('Fourteen provider drafts were preserved'));
    expect(localeWorkflow, contains('raw provider-response envelope'));
    expect(localeWorkflow, contains('`repair-preflight`'));
    expect(productionReview, contains('Japanese-only targeted repair'));
  });
}

Map<String, dynamic> _manifestJson() => {
  'schemaVersion': 1,
  'workflow': incrementalLocaleReviewWorkflow,
  'deltaId': 'adaptive-focus-review-v1',
  'sourceProposal': 'localization/proposals/app_en_adaptive_focus_review.arb',
  'sourceProposalSha256': _proposalDigest,
  'locales': [
    _manifestLocaleJson('es', 'Spanish', 'Español'),
    _manifestLocaleJson('fr', 'French', 'Français'),
  ],
  'derivedFallbacks': <Map<String, dynamic>>[],
};

Map<String, dynamic> _manifestLocaleJson(
  String locale,
  String englishName,
  String nativeName,
) => {
  'locale': locale,
  'englishName': englishName,
  'nativeName': nativeName,
  'reviewScope': '${locale}_fluent_review',
  'runtimeCatalog': 'lib/l10n/app_${locale.replaceAll('-', '_')}.arb',
  'runtimeCatalogSha256': _runtimeDigest,
  'exceptionalGates': {
    'rightToLeft': false,
    'fontCoverage': false,
    'physicalScreenReader': false,
    'physicalSpeechRecognition': false,
    'storePromotion': false,
  },
};

Map<String, dynamic> _configJson() => {
  'schemaVersion': 1,
  'workflow': googleTranslationDraftWorkflow,
  'projectId': 'focushaven-l10n',
  'location': googleTranslationDraftLocation,
  'model': googleTranslationDraftModel,
  'maxCodePointsPerRequest': 5000,
  'locales': {'es': _localeConfigJson('es'), 'fr': _localeConfigJson('fr')},
};

Map<String, dynamic> _localeConfigJson(String locale) => {
  'targetLanguageCode': locale,
  'glossary':
      'projects/focushaven-l10n/locations/us-central1/glossaries/focus-$locale',
  'approvedSourceEqual': <String, String>{},
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

Map<String, String> _spanishTranslations() => {
  'adaptiveFocusEyebrow': 'FOCUS ADAPTATIVO',
  'adaptiveFocusCurrentPlan': 'Actual: {focusMinutes} min de concentración',
  'adaptiveFocusNoAutomaticChange':
      'Nada cambia a menos que elijas Usar sugerencia.',
};
