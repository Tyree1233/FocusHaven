import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

void main() {
  test(
    'Flutter generation is pinned to the reviewed English source catalog',
    () {
      final pubspec = _read('pubspec.yaml');
      final lock = _read('pubspec.lock');
      final configuration = _read('l10n.yaml');
      final source =
          jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;

      expect(pubspec, contains('flutter_localizations:\n    sdk: flutter'));
      expect(pubspec, contains('intl: 0.20.2'));
      expect(pubspec, contains('generate: true'));
      expect(lock, contains('flutter_localizations:'));
      expect(lock, contains('version: "0.20.2"'));

      for (final required in <String>[
        'arb-dir: lib/l10n',
        'template-arb-file: app_en.arb',
        'output-localization-file: app_localizations.dart',
        'output-class: AppLocalizations',
        'nullable-getter: false',
        'required-resource-attributes: true',
      ]) {
        expect(configuration, contains(required));
      }

      expect(source['@@locale'], 'en');
      expect(source['appTitle'], 'FocusHaven');
      expect(
        (source['@appTitle'] as Map<String, dynamic>)['description'],
        isNotEmpty,
      );
    },
  );

  test('production, integration, and planned locale claims stay separate', () {
    expect(FocusHavenLocales.productionLocales, const <Locale>[
      Locale('en'),
      Locale('es'),
      Locale('fr'),
    ]);
    expect(FocusHavenLocales.production, hasLength(3));
    expect(
      FocusHavenLocales.production,
      everyElement(
        isA<FocusHavenLocaleDefinition>().having(
          (definition) => definition.status,
          'status',
          FocusHavenLocaleStatus.production,
        ),
      ),
    );

    expect(
      FocusHavenLocales.firstTranslationWave
          .map((definition) => definition.locale)
          .toList(),
      const <Locale>[
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('pt', 'BR'),
      ],
    );
    expect(
      FocusHavenLocales.firstTranslationWave.take(2),
      everyElement(
        isA<FocusHavenLocaleDefinition>().having(
          (definition) => definition.status,
          'status',
          FocusHavenLocaleStatus.production,
        ),
      ),
    );
    expect(
      FocusHavenLocales.firstTranslationWave.skip(2),
      everyElement(
        isA<FocusHavenLocaleDefinition>().having(
          (definition) => definition.status,
          'status',
          FocusHavenLocaleStatus.planned,
        ),
      ),
    );
    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      FocusHavenLocales.firstTranslationWave.map(
        (definition) => definition.languageTag,
      ),
      ['es', 'fr', 'de', 'pt-BR'],
    );
    expect(
      FocusHavenLocales.firstTranslationWave.map(
        (definition) => definition.arbLocale,
      ),
      ['es', 'fr', 'de', 'pt_BR'],
    );
    expect(
      FocusHavenLocales.productionLocales.toSet().intersection(
        FocusHavenLocales.firstTranslationWave
            .skip(2)
            .map((definition) => definition.locale)
            .toSet(),
      ),
      isEmpty,
    );
  });

  test('runtime wiring uses generated localization without claiming plans', () {
    final main = _read('lib/main.dart');
    final registry = _read('lib/l10n/focus_haven_locales.dart');
    final ignore = _read('.gitignore');

    expect(main, contains("import 'l10n/app_localizations.dart';"));
    expect(
      main,
      contains(
        'localizationsDelegates: AppLocalizations.localizationsDelegates',
      ),
    );
    expect(
      main,
      contains('supportedLocales: FocusHavenLocales.productionLocales'),
    );
    expect(main, contains("import 'l10n/focus_haven_locales.dart';"));
    expect(main, contains('AppLocalizations.of(context).appTitle'));
    expect(main, isNot(contains("title: 'FocusHaven'")));

    expect(registry, contains('firstTranslationWave'));
    expect(registry, contains("countryCode: 'BR'"));
    expect(ignore, contains('/lib/l10n/app_localizations.dart'));
    expect(ignore, contains('/lib/l10n/app_localizations_*.dart'));
  });

  test('global release policy forbids incomplete and private translation', () {
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));

    for (final required in <String>[
      'English (`en`) is the source catalog and fallback production locale',
      'Spanish (`es`) and French (`fr`) are reviewed production runtime locales',
      'Planned locales are not exposed by the production `MaterialApp.supportedLocales` allowlist',
      'no private user content is sent anywhere for translation',
      'qualified human reviewer',
      'voice features use an explicitly supported speech locale',
      'A translated interface does not by itself authorize distribution in a new country',
      'Google Play contact-number verification is an account checkpoint',
    ]) {
      expect(policy, contains(required));
    }

    expect(
      roadmap,
      contains('| Global localization | English, Spanish, and French active |'),
    );
    expect(
      roadmap,
      contains(
        'Phase 215G-A foundation and Phase 215G-B1/B2/B3A/B3B/B3C/B4/B5/B6A/B6B1/B6B2/B6C1/B6C2/B6C3 English Flutter extraction',
      ),
    );
    expect(
      roadmap,
      contains('Phase 215G-B English Flutter extraction is complete'),
    );
    expect(readme, contains('English as the source and fallback catalog'));
    expect(
      readme,
      contains('Store-language promotion remains a separate release decision'),
    );
    expect(readme, contains('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
