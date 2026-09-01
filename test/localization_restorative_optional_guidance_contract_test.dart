import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B6B2 restorative and optional-system catalog has metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'havenRhythmConnectionLearningHeadline',
      'havenRhythmConnectionPatternDetail',
      'havenRhythmConnectionRecoveryDetail',
      'havenRhythmGentleReturnEvidence',
      'havenRhythmGentlerPaceEvidence',
      'havenRhythmSustainablePaceHeadline',
      'havenRhythmRoomToGrowEvidence',
      'havenRhythmVariablePaceEvidence',
      'havenRhythmCompletionPatternDetail',
      'havenRhythmLearningEvidence',
      'focusForecastConnectionLearningHeadline',
      'focusForecastConnectionFlexibleDetail',
      'focusForecastConnectionInsideDetail',
      'focusForecastConnectionOutsideDetail',
      'focusForecastLearningEvidence',
      'focusForecastFlexibleEvidence',
      'focusForecastEmergingHeadline',
      'focusForecastEmergingEvidence',
      'focusForecastEarlyMorningLabel',
      'focusForecastMorningRange',
      'focusForecastLateNightRange',
      'smartResetInvalidAttempt',
      'smartResetRepeatedRecoveryExplanation',
      'smartResetMeaningfulProgressExplanation',
      'smartResetGentleReturnExplanation',
      'havenJourneyConnectionChangedDetail',
      'havenJourneyConnectionHeldDetail',
      'havenJourneyNegativeCompletionCount',
      'havenJourneySanctuaryHeadline',
      'havenJourneyGardenDetail',
      'havenJourneyCabinDetail',
      'havenJourneyCampsiteDetail',
      'havenJourneyLanternDetail',
      'havenJourneySanctuaryLabel',
      'havenWindowUnsupportedHeadline',
      'havenWindowDisconnectedDetail',
      'havenWindowDeniedDetail',
      'havenWindowNoAvailabilityEvidence',
      'havenWindowInvalidEvidence',
      'havenWindowStaleEvidence',
      'havenWindowLearningDetail',
      'havenWindowOpeningEvidence',
      'havenWindowNoOpeningEvidence',
      'havenWindowInvalidPreferredDuration',
      'havenWindowEarlyMorningLabel',
      'havenWindowLateNightLabel',
      'focusShieldOffDetail',
      'focusShieldUnsupportedDetail',
      'focusShieldPermissionDeniedDetail',
      'focusShieldPermissionRequiredDetail',
      'focusShieldSelectionDetail',
      'focusShieldFailedDetail',
      'focusShieldStartingDetail',
      'focusShieldProtectingDetail',
      'focusShieldPausedDetail',
      'focusShieldBreakDetail',
      'focusShieldRecoveryDetail',
      'focusShieldReadyDetail',
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

    expect(_placeholderKeys(catalog, 'havenRhythmConnectionPatternDetail'), {
      'insightHeadline',
    });
    expect(_placeholderKeys(catalog, 'havenRhythmGentleReturnEvidence'), {
      'recoveryCount',
      'attemptCount',
    });
    expect(_placeholderKeys(catalog, 'focusForecastLearningEvidence'), {
      'signalCount',
      'minimumCount',
    });
    expect(_placeholderKeys(catalog, 'focusForecastEmergingEvidence'), {
      'matchingCount',
      'sessionCount',
      'windowRange',
    });
    expect(_placeholderKeys(catalog, 'havenJourneyConnectionChangedDetail'), {
      'placeLabel',
    });
    expect(_placeholderKeys(catalog, 'havenWindowOpeningEvidence'), {
      'minutes',
      'windowLabel',
    });
  });

  test('B6B2 services use the generated catalog with an English fallback', () {
    const servicePaths = <String>[
      'lib/services/haven_rhythm_service.dart',
      'lib/services/focus_forecast_service.dart',
      'lib/services/smart_reset_service.dart',
      'lib/services/haven_journey_service.dart',
      'lib/services/haven_window_service.dart',
      'lib/services/focus_shield_service.dart',
    ];

    for (final path in servicePaths) {
      final source = _read(path);
      expect(source, contains("import '../l10n/app_localizations.dart';"));
      expect(source, contains("import '../l10n/service_localizations.dart';"));
      expect(source, contains('AppLocalizations? localizations'));
      expect(
        source,
        contains('localizations ?? defaultServiceLocalizations()'),
      );
    }

    final combined = servicePaths.map(_read).join('\n');
    for (final stale in <String>[
      "'A gentler return may fit right now'",
      "'Your Focus Forecast is still forming'",
      "'Recent restarts suggest that less pressure may make returning easier.'",
      "'Your Haven has become a sanctuary'",
      "'Calendar availability is unavailable here'",
      "'Focus Shield is off'",
      "'Preparing your Haven'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: stale);
    }
  });

  test('B6B2 preserves private values and deterministic service ownership', () {
    final rhythm = _read('lib/services/haven_rhythm_service.dart');
    final forecast = _read('lib/services/focus_forecast_service.dart');
    final window = _read('lib/services/haven_window_service.dart');
    final shield = _read('lib/services/focus_shield_service.dart');
    final catalog = _read('lib/l10n/app_en.arb');

    expect(rhythm, contains('required List<FocusEvent> recentEvents'));
    expect(forecast, contains('required List<FocusEvent> recentEvents'));
    expect(
      window,
      contains('required PrivateCalendarAvailability availability'),
    );
    expect(window, contains('availability.busyBlocks'));
    expect(shield, contains('required FocusShieldCapability capability'));
    expect(shield, isNot(contains('selectedApps')));
    expect(shield, isNot(contains('selectedWebsites')));
    expect(catalog, isNot(contains('Private task')));
    expect(catalog, isNot(contains('calendar event title')));
    expect(catalog, isNot(contains('selected app name')));
  });

  test('B6B2 remains partial and planned locales stay inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    expect(
      inventory,
      contains('B6B2 — Restorative and optional-system guidance'),
    );
    expect(inventory, contains('Private reflections, completion identities'));
    expect(inventory, contains('B6C1 — Haven action service results'));
    expect(policy, contains('Phase 215G-B6B2'));
    expect(policy, contains('B6 remains required through B6C3'));
    expect(roadmap, contains('B1–B6C1 extraction shipped'));
    expect(roadmap, contains('remaining B6 extraction work is B6C2 and B6C3'));
    expect(readme, contains('Phase 215G-B6B2'));
    expect(
      locales,
      contains("static const productionLocales = <Locale>[Locale('en')]"),
    );
    expect(
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .length,
      1,
    );
  });
}

Set<String> _placeholderKeys(Map<String, dynamic> catalog, String key) {
  final metadata = catalog['@$key'] as Map<String, dynamic>;
  final placeholders = metadata['placeholders'] as Map<String, dynamic>;
  return placeholders.keys.toSet();
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
