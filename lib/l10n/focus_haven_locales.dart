import 'package:flutter/widgets.dart';

enum FocusHavenLocaleStatus { production, planned }

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
}

abstract final class FocusHavenLocales {
  static const production = <FocusHavenLocaleDefinition>[
    FocusHavenLocaleDefinition(
      languageCode: 'en',
      englishName: 'English',
      nativeName: 'English',
      status: FocusHavenLocaleStatus.production,
    ),
  ];

  static const firstTranslationWave = <FocusHavenLocaleDefinition>[
    FocusHavenLocaleDefinition(
      languageCode: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
      status: FocusHavenLocaleStatus.planned,
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

  static const productionLocales = <Locale>[Locale('en')];
}
