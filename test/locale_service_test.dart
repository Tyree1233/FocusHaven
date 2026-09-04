import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'defaults to the device language without storing a preference',
    () async {
      final service = LocaleService();
      await service.initialized;

      expect(service.selectedChoice, FocusHavenLanguageChoice.system);
      expect(service.selectedLocale, isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(LocaleService.storageKey), isFalse);
    },
  );

  test('restores an explicit Spanish preference', () async {
    SharedPreferences.setMockInitialValues({LocaleService.storageKey: 'es'});
    final service = LocaleService();
    await service.initialized;

    expect(service.selectedChoice, FocusHavenLanguageChoice.spanish);
    expect(service.selectedLocale?.languageCode, 'es');
  });

  test(
    'derives available choices from the production locale registry',
    () async {
      final service = LocaleService();
      await service.initialized;

      expect(service.availableChoices, [
        FocusHavenLanguageChoice.system,
        ...FocusHavenLocales.production.map(
          FocusHavenLanguageChoice.forDefinition,
        ),
      ]);
    },
  );

  test(
    'rejects a locale until its registry state becomes production',
    () async {
      final service = LocaleService();
      await service.initialized;
      final plannedFrench = FocusHavenLocales.firstTranslationWave.singleWhere(
        (definition) => definition.languageCode == 'fr',
      );

      await expectLater(
        service.setLanguage(
          FocusHavenLanguageChoice.forDefinition(plannedFrench),
        ),
        throwsArgumentError,
      );
    },
  );

  test('persists and clears a reversible explicit preference', () async {
    final service = LocaleService();
    await service.initialized;

    await service.setLanguage(FocusHavenLanguageChoice.english);
    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleService.storageKey), 'en');

    await service.setLanguage(FocusHavenLanguageChoice.spanish);
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleService.storageKey), 'es');

    await service.setLanguage(FocusHavenLanguageChoice.system);
    preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(LocaleService.storageKey), isFalse);
    expect(service.selectedLocale, isNull);
  });

  test('repairs an unsupported saved language to device default', () async {
    SharedPreferences.setMockInitialValues({LocaleService.storageKey: 'fr'});
    final service = LocaleService();
    await service.initialized;

    expect(service.selectedChoice, FocusHavenLanguageChoice.system);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(LocaleService.storageKey), isFalse);
  });
}
