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
      status: FocusHavenLocaleStatus.planned,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
      status: FocusHavenLocaleStatus.planned,
    ),
    FocusHavenLocaleDefinition(
      languageCode: 'pt',
      countryCode: 'BR',
      englishName: 'Brazilian Portuguese',
      nativeName: 'Português (Brasil)',
      status: FocusHavenLocaleStatus.planned,
    ),
  ];

  static const productionLocales = <Locale>[Locale('en'), Locale('es')];

  // Generated catalogs still awaiting production activation belong here.
  static const integrationLocales = <Locale>[];

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
