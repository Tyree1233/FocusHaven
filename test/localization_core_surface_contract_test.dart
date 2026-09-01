import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B1 English messages and metadata are complete', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'onboardingSaveError',
      'onboardingStartError',
      'onboardingTitle',
      'onboardingSubtitle',
      'onboardingOpening',
      'onboardingBeginFocus',
      'customDurationTitle',
      'customDurationInstructions',
      'durationMinutesShort',
      'durationSecondsShort',
      'customDurationSet',
      'appearanceUpdateError',
      'appearanceBackToAccountSettings',
      'appearanceTitle',
      'appearanceDescription',
      'themeTwilight',
      'themeCalmBlue',
      'themeMinimalist',
      'themeSunset',
      'themeForest',
      'themeRoseQuartz',
      'breathingTitle',
      'breathingDescription',
      'breathingPhaseIn',
      'breathingPhaseHold',
      'breathingPhaseOut',
      'breathingComplete',
      'breathingCompletionMessage',
      'durationSeconds',
      'durationMinutes',
      'actionPause',
      'actionTryAgain',
      'breathingBegin',
      'actionReset',
      'timerSemanticsLabel',
      'timerSemanticsValue',
    };

    for (final key in requiredKeys) {
      expect(catalog[key], isA<String>(), reason: 'missing message: $key');
      final metadata = catalog['@$key'];
      expect(metadata, isA<Map<String, dynamic>>(), reason: 'metadata: $key');
      expect(
        (metadata as Map<String, dynamic>)['description'],
        isNotEmpty,
        reason: 'description: $key',
      );
    }

    for (final key in catalog.keys.where((key) => !key.startsWith('@'))) {
      expect(catalog['@$key'], isNotNull, reason: 'catalog metadata: $key');
    }

    expect(catalog['durationSeconds'], contains('plural'));
    expect(catalog['durationMinutes'], contains('plural'));
    expect(
      (catalog['@timerSemanticsValue'] as Map<String, dynamic>)['placeholders'],
      containsPair('percent', isA<Map<String, dynamic>>()),
    );
  });

  test('B1 production surfaces use generated localization access', () {
    final sources = <String, List<String>>{
      'lib/screens/onboarding_screen.dart': <String>[
        'onboardingSaveError',
        'onboardingStartError',
        'onboardingTitle',
        'onboardingSubtitle',
        'onboardingOpening',
        'onboardingBeginFocus',
      ],
      'lib/widgets/custom_duration_sheet.dart': <String>[
        'customDurationTitle',
        'customDurationInstructions',
        'durationMinutesShort',
        'durationSecondsShort',
        'customDurationSet',
      ],
      'lib/widgets/appearance_sheet.dart': <String>[
        'appearanceUpdateError',
        'appearanceBackToAccountSettings',
        'appearanceTitle',
        'appearanceDescription',
        'themeTwilight',
        'themeRoseQuartz',
      ],
      'lib/widgets/guided_breathing_sheet.dart': <String>[
        'breathingTitle',
        'breathingDescription',
        'breathingPhaseIn',
        'breathingPhaseHold',
        'breathingPhaseOut',
        'breathingComplete',
        'durationSeconds',
        'actionPause',
        'actionTryAgain',
        'breathingBegin',
        'actionReset',
      ],
      'lib/widgets/timer_countdown.dart': <String>[
        'durationMinutes',
        'durationSeconds',
        'timerSemanticsLabel',
        'timerSemanticsValue',
      ],
    };

    for (final entry in sources.entries) {
      final source = _read(entry.key);
      expect(source, contains('l10n'));
      for (final getter in entry.value) {
        expect(source, contains('l10n.$getter'), reason: entry.key);
      }
    }

    final contextExtension = _read('lib/l10n/focus_haven_localizations.dart');
    expect(contextExtension, contains('extension AppLocalizationsContext'));
    expect(
      contextExtension,
      contains('AppLocalizations get l10n => AppLocalizations.of(this)'),
    );
    expect(
      _read('lib/services/theme_service.dart'),
      isNot(contains('String get label')),
    );
  });

  test('B1 scope remains truthful and later extraction stays explicit', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));

    for (final required in <String>[
      'English (`en`) remains the only production locale',
      'Spanish, French, German, and Brazilian Portuguese remain planned and inactive',
      'B1 — Core entry and compact controls',
      'B2 — Timer dashboard and session controls',
      'B3 — Planning and recovery',
      'B4 — Coaching and voice',
      'B5 — Account and purchases',
      'B6 — Service and notification messages',
      'Phase 215G-B is complete only when every Flutter-owned source string',
    ]) {
      expect(inventory, contains(required));
    }

    expect(policy, contains('215G-B1 and B2'));
    expect(policy, contains('not complete Phase 215G-B'));
    expect(roadmap, contains('Phase 215G-B1'));
    expect(roadmap, contains('remaining B3–B6 extraction slices'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
