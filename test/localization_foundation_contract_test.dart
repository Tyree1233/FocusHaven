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

  test('production and planned locale claims remain deliberately separate', () {
    expect(FocusHavenLocales.productionLocales, const <Locale>[Locale('en')]);
    expect(FocusHavenLocales.production, hasLength(1));
    expect(
      FocusHavenLocales.production.single.status,
      FocusHavenLocaleStatus.production,
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
      FocusHavenLocales.firstTranslationWave,
      everyElement(
        isA<FocusHavenLocaleDefinition>().having(
          (definition) => definition.status,
          'status',
          FocusHavenLocaleStatus.planned,
        ),
      ),
    );
    expect(
      FocusHavenLocales.productionLocales.toSet().intersection(
        FocusHavenLocales.firstTranslationWave
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
      contains('supportedLocales: AppLocalizations.supportedLocales'),
    );
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
      'English (`en`) is the source catalog and the only production-supported runtime locale',
      'Spanish (`es`), French (`fr`), German (`de`), and Brazilian Portuguese (`pt-BR`)',
      'Planned locales are not exposed by `MaterialApp.supportedLocales`',
      'no private user content is sent anywhere for translation',
      'qualified human reviewer',
      'Voice-to-Coach and safe voice commands',
      'A translated interface does not by itself authorize distribution in a new country',
      'Google Play contact-number verification is an account checkpoint',
    ]) {
      expect(policy, contains(required));
    }

    expect(
      roadmap,
      contains(
        '| Global localization | Foundation plus B1–B4 extraction shipped |',
      ),
    );
    expect(
      roadmap,
      contains(
        'Phase 215G-A foundation and Phase 215G-B1/B2/B3A/B3B/B3C/B4 extraction',
      ),
    );
    expect(roadmap, contains('remaining B5–B6 extraction slices'));
    expect(readme, contains('English as the source catalog'));
    expect(readme, contains('deliberately not advertised'));
    expect(readme, contains('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
