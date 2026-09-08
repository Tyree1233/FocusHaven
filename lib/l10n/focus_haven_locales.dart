import 'package:flutter/widgets.dart';

enum FocusHavenLocaleStatus { production, integration, planned }

class FocusHavenLocaleDefinition {
  const FocusHavenLocaleDefinition({
    required this.languageCode,
    required this.englishName,
    required this.nativeName,
    required this.status,
    this.countryCode,
  });

  final String languageCode;
  final String? countryCode;
  final String englishName;
  final String nativeName;
  final FocusHavenLocaleStatus status;

  Locale get locale => Locale(languageCode, countryCode);

  /// Stable BCP-47-shaped value used for local preference persistence.
  String get languageTag =>
      countryCode == null ? languageCode : '$languageCode-$countryCode';

  /// Locale identifier used by Flutter ARB filenames and `@@locale` values.
  String get arbLocale =>
      countryCode == null ? languageCode : '${languageCode}_$countryCode';
}

abstract final class FocusHavenLocales {
  static const production = <FocusHavenLocaleDefinition>[
    FocusHavenLocaleDefinition(
      languageCode: 'en',
      englishName: 'English',
      nativeName: 'English',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'fr',
      englishName: 'French',
      nativeName: 'Français',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'pt',
      countryCode: 'BR',
      englishName: 'Brazilian Portuguese',
      nativeName: 'Português (Brasil)',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'ja',
      englishName: 'Japanese',
      nativeName: '日本語',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'ko',
      englishName: 'Korean',
      nativeName: '한국어',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'it',
      englishName: 'Italian',
      nativeName: 'Italiano',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'pl',
      englishName: 'Polish',
      nativeName: 'Polski',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'nl',
      englishName: 'Dutch',
      nativeName: 'Nederlands',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'id',
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'tr',
      englishName: 'Turkish',
      nativeName: 'Türkçe',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'sv',
      englishName: 'Swedish',
      nativeName: 'Svenska',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'nb',
      englishName: 'Norwegian Bokmål',
      nativeName: 'Norsk bokmål',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'da',
      englishName: 'Danish',
      nativeName: 'Dansk',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'fi',
      englishName: 'Finnish',
      nativeName: 'Suomi',
      status: FocusHavenLocaleStatus.production,
    ),
  ];

  static const firstTranslationWave = <FocusHavenLocaleDefinition>[
    FocusHavenLocaleDefinition(
      languageCode: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'fr',
      englishName: 'French',
      nativeName: 'Français',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
      status: FocusHavenLocaleStatus.production,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'pt',
      countryCode: 'BR',
      englishName: 'Brazilian Portuguese',
      nativeName: 'Português (Brasil)',
      status: FocusHavenLocaleStatus.production,
    ),
  ];

  static const productionLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('pt', 'BR'),
    Locale('ja'),
    Locale('ko'),
    Locale('it'),
    Locale('pl'),
    Locale('nl'),
    Locale('id'),
    Locale('tr'),
    Locale('sv'),
    Locale('nb'),
    Locale('da'),
    Locale('fi'),
  ];

  // Generated catalogs still awaiting production activation belong here.
  // The current reviewed Japanese and Korean catalogs have completed their
  // physical CJK coverage gate, so no catalog remains integration-only.
  static const integrationLocales = <Locale>[];

  // Exact locale surface for the fail-closed CJK coverage entry point.
  static const cjkCoverageTestLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  // Exact locale surface retained for the reproducible debug-only Spanish
  // device-test entry point.
  static const spanishDeviceTestLocales = <Locale>[Locale('en'), Locale('es')];

  static FocusHavenLocaleDefinition? productionDefinitionForTag(String tag) {
    for (final definition in production) {
      if (definition.languageTag == tag) return definition;
    }
    return null;
  }
}
