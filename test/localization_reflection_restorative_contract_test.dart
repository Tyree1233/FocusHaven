import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B3B reflection and restorative messages have complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'focusReflectionTitle',
      'focusReflectionDescription',
      'focusSessionFitTooMuch',
      'focusSessionFitAboutRight',
      'focusSessionFitCouldDoMore',
      'focusReflectionSaved',
      'havenRhythmKindLearning',
      'havenRhythmKindGentleReturn',
      'havenRhythmKindGentlerPace',
      'havenRhythmKindSustainablePace',
      'havenRhythmKindRoomToGrow',
      'havenRhythmKindVariablePace',
      'havenRhythmKindCompletionPattern',
      'havenRhythmEyebrow',
      'havenRhythmPossiblePace',
      'havenRhythmPrivacy',
      'havenRhythmReflectionSemantics',
      'havenRhythmReflectionSavedUpper',
      'havenRhythmNoAutomaticChange',
      'focusForecastKindLearning',
      'focusForecastKindEmergingWindow',
      'focusForecastKindFlexible',
      'focusForecastEyebrow',
      'focusForecastShowDetails',
      'focusForecastHideDetails',
      'focusForecastSemantics',
      'focusForecastAdvisoryBoundary',
      'focusForecastPrivacy',
      'focusForecastReflectionSemantics',
      'focusForecastReflectionSavedUpper',
      'focusForecastNoAutomaticChange',
      'smartResetTitle',
      'smartResetFocusStillCounts',
      'smartResetPauseStillCounts',
      'smartResetSmallerWayBackUpper',
      'smartResetPrivacy',
      'smartResetLinkedTaskBoundary',
      'smartResetRestartWith',
      'smartResetResetWithoutRestarting',
      'smartResetKeepSession',
      'havenJourneyPlaceLantern',
      'havenJourneyPlaceCampsite',
      'havenJourneyPlaceCabin',
      'havenJourneyPlaceGarden',
      'havenJourneyPlaceSanctuary',
      'havenJourneyEyebrow',
      'havenJourneySemantics',
      'havenJourneyPrivacy',
      'havenJourneyCompletionSemantics',
      'havenJourneyNewPlaceUpper',
      'havenJourneyCompletionKeptUpper',
      'havenJourneyNoAutomaticChange',
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

    expect(catalog['havenRhythmPossiblePace'], contains('plural'));
    for (final key in <String>[
      'havenRhythmReflectionSemantics',
      'focusForecastSemantics',
      'focusForecastReflectionSemantics',
      'havenJourneySemantics',
      'havenJourneyCompletionSemantics',
    ]) {
      final metadata = catalog['@$key'] as Map<String, dynamic>;
      expect(metadata['placeholders'], isA<Map<String, dynamic>>());
    }
  });

  test('B3B production presentation uses generated localization access', () {
    final sources = <String, List<String>>{
      'lib/widgets/focus_session_reflection_card.dart': <String>[
        'focusReflectionTitle',
        'focusReflectionDescription',
        'focusSessionFitTooMuch',
        'focusSessionFitAboutRight',
        'focusSessionFitCouldDoMore',
        'focusReflectionSaved',
      ],
      'lib/widgets/haven_rhythm_card.dart': <String>[
        'havenRhythmKindLearning',
        'havenRhythmKindCompletionPattern',
        'havenRhythmEyebrow',
        'havenRhythmPossiblePace',
        'havenRhythmPrivacy',
      ],
      'lib/widgets/haven_rhythm_reflection_connection_card.dart': <String>[
        'havenRhythmReflectionSemantics',
        'havenRhythmReflectionSavedUpper',
        'havenRhythmNoAutomaticChange',
      ],
      'lib/widgets/focus_forecast_card.dart': <String>[
        'focusForecastKindLearning',
        'focusForecastKindEmergingWindow',
        'focusForecastKindFlexible',
        'focusForecastSemantics',
        'focusForecastAdvisoryBoundary',
        'focusForecastPrivacy',
      ],
      'lib/widgets/focus_forecast_reflection_connection_card.dart': <String>[
        'focusForecastReflectionSemantics',
        'focusForecastReflectionSavedUpper',
        'focusForecastNoAutomaticChange',
      ],
      'lib/widgets/smart_reset_sheet.dart': <String>[
        'smartResetTitle',
        'smartResetFocusStillCounts',
        'smartResetPauseStillCounts',
        'smartResetPrivacy',
        'smartResetLinkedTaskBoundary',
        'smartResetRestartWith',
        'smartResetKeepSession',
      ],
      'lib/widgets/haven_journey_card.dart': <String>[
        'havenJourneyPlaceLantern',
        'havenJourneyPlaceSanctuary',
        'havenJourneyEyebrow',
        'havenJourneySemantics',
        'havenJourneyPrivacy',
      ],
      'lib/widgets/haven_journey_completion_connection_card.dart': <String>[
        'havenJourneyCompletionSemantics',
        'havenJourneyNewPlaceUpper',
        'havenJourneyCompletionKeptUpper',
        'havenJourneyNoAutomaticChange',
      ],
    };

    for (final entry in sources.entries) {
      final source = _read(entry.key);
      expect(source, contains('l10n'), reason: entry.key);
      for (final getter in entry.value) {
        expect(source, contains(getter), reason: '${entry.key}: $getter');
      }
    }

    final combined = sources.keys.map(_read).join('\n');
    for (final stale in <String>[
      "'How did that session feel?'",
      "'HAVEN RHYTHM · REFLECTION SAVED'",
      "'FOCUS FORECAST · REFLECTION SAVED'",
      "'This session isn’t a failure'",
      "'A SMALLER WAY BACK'",
      "'HAVEN JOURNEY · NEW PLACE'",
      "'HAVEN JOURNEY · COMPLETION KEPT'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: 'stale literal: $stale');
    }
  });

  test('B3B keeps private and generated values outside the catalog', () {
    final reflection = _read('lib/widgets/focus_session_reflection_card.dart');
    final rhythm = _read('lib/widgets/haven_rhythm_card.dart');
    final rhythmConnection = _read(
      'lib/widgets/haven_rhythm_reflection_connection_card.dart',
    );
    final forecast = _read('lib/widgets/focus_forecast_card.dart');
    final forecastConnection = _read(
      'lib/widgets/focus_forecast_reflection_connection_card.dart',
    );
    final reset = _read('lib/widgets/smart_reset_sheet.dart');
    final journey = _read('lib/widgets/haven_journey_card.dart');
    final journeyConnection = _read(
      'lib/widgets/haven_journey_completion_connection_card.dart',
    );

    expect(reflection, isNot(contains('TextField')));
    expect(rhythm, contains('insight.headline'));
    expect(rhythm, contains('insight.detail'));
    expect(rhythm, contains('insight.evidence'));
    expect(rhythmConnection, contains('connection.headline'));
    expect(rhythmConnection, contains('connection.detail'));
    expect(forecast, contains('forecast.headline'));
    expect(forecast, contains('forecast.detail'));
    expect(forecast, contains('forecast.evidence'));
    expect(forecastConnection, contains('connection.headline'));
    expect(reset, contains('plan.explanation'));
    expect(journey, contains('state.headline'));
    expect(journey, contains('state.detail'));
    expect(journeyConnection, contains('connection.detail'));

    final services = <String>[
      'lib/services/haven_rhythm_service.dart',
      'lib/services/focus_forecast_service.dart',
      'lib/services/smart_reset_service.dart',
      'lib/services/haven_journey_service.dart',
    ].map(_read).join('\n');
    expect(services, isNot(contains('context.l10n')));
  });

  test('B3B scope is truthful and planned locales remain inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    for (final required in <String>[
      'B3B — Reflection and restorative guidance',
      'Service-generated headlines, details, evidence, and explanations remain B6-owned',
      'Personal reflection content is never a catalog key',
      'B4 through B6 remain required',
      'No locale was activated by B3B',
    ]) {
      expect(inventory, contains(required));
    }
    expect(policy, contains('Phase 215G-B3C'));
    expect(policy, contains('B4 through B6 remain required'));
    expect(roadmap, contains('Phase 215G-B1/B2/B3A/B3B/B3C extraction'));
    expect(roadmap, contains('remaining B4–B6 extraction slices'));
    expect(readme, contains('Phase 215G-B3B'));
    expect(
      readme,
      contains('service-generated restorative copy remains B6-owned'),
    );
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

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
