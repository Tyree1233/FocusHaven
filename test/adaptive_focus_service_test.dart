import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/adaptive_focus_suggestion.dart';
import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/adaptive_focus_service.dart';

void main() {
  const service = AdaptiveFocusService();

  FocusEvent event({
    required FocusEventOutcome outcome,
    int ageMinutes = 0,
    int focusedMinutes = 25,
    int plannedMinutes = 25,
    FocusSessionFit? sessionFit,
  }) {
    final endedAt = DateTime.utc(
      2026,
      9,
      6,
      18,
    ).subtract(Duration(minutes: ageMinutes));
    return FocusEvent(
      startedAt: endedAt.subtract(Duration(minutes: focusedMinutes)),
      endedAt: endedAt,
      plannedDurationSeconds: plannedMinutes * 60,
      focusedDurationSeconds: focusedMinutes * 60,
      pauseCount: 0,
      didResume: false,
      outcome: outcome,
      sessionFit: sessionFit,
    );
  }

  HavenRhythmInsight rhythm({
    HavenRhythmKind kind = HavenRhythmKind.learning,
    int signalCount = 0,
    int? suggestedFocusMinutes,
  }) => HavenRhythmInsight(
    kind: kind,
    headline: 'opaque',
    detail: 'opaque',
    evidence: 'opaque',
    signalCount: signalCount,
    usesSessionReflections: false,
    suggestedFocusMinutes: suggestedFocusMinutes,
  );

  FocusForecast forecast({
    FocusForecastKind kind = FocusForecastKind.learning,
    int signalCount = 0,
    FocusForecastWindow? window,
  }) => FocusForecast(
    kind: kind,
    headline: 'opaque',
    detail: 'opaque',
    evidence: 'opaque',
    signalCount: signalCount,
    window: window,
  );

  AdaptiveFocusSuggestion? suggestion({
    int currentFocusMinutes = 25,
    int currentBreakMinutes = 5,
    bool preserveCurrentChoice = false,
    List<FocusEvent> recentEvents = const [],
    HavenRhythmInsight? rhythmValue,
    FocusForecast? forecastValue,
  }) => service.createSuggestion(
    currentFocusMinutes: currentFocusMinutes,
    currentBreakMinutes: currentBreakMinutes,
    preserveCurrentChoice: preserveCurrentChoice,
    recentEvents: recentEvents,
    rhythm: rhythmValue ?? rhythm(),
    forecast: forecastValue ?? forecast(),
  );

  test('invalid current choices fail closed without a preview', () {
    expect(suggestion(currentFocusMinutes: 0), isNull);
    expect(suggestion(currentFocusMinutes: 181), isNull);
    expect(suggestion(currentBreakMinutes: -1), isNull);
    expect(suggestion(currentBreakMinutes: 61), isNull);
  });

  test('an explicit keep-current choice overrides every learned signal', () {
    final result = suggestion(
      currentFocusMinutes: 37,
      currentBreakMinutes: 7,
      preserveCurrentChoice: true,
      recentEvents: [
        event(outcome: FocusEventOutcome.reset),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 5),
      ],
      rhythmValue: rhythm(
        kind: HavenRhythmKind.roomToGrow,
        signalCount: 8,
        suggestedFocusMinutes: 60,
      ),
      forecastValue: forecast(
        kind: FocusForecastKind.emergingWindow,
        signalCount: 9,
        window: FocusForecastWindow.morning,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.explicitChoice);
    expect(result.suggestedFocusMinutes, 37);
    expect(result.suggestedBreakMinutes, 7);
    expect(result.direction, AdaptiveFocusDirection.keepCurrent);
    expect(result.breakDirection, AdaptiveFocusBreakDirection.keepCurrent);
    expect(result.preservesExplicitChoice, isTrue);
    expect(result.usesRecoveryPattern, isFalse);
    expect(result.usesRepeatedRhythm, isFalse);
    expect(result.possibleWindow, FocusForecastWindow.morning);
  });

  test('repeated recovery leads before reflection, rhythm, or timing', () {
    final result = suggestion(
      currentFocusMinutes: 45,
      currentBreakMinutes: 5,
      recentEvents: [
        event(outcome: FocusEventOutcome.reset),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 5),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 10,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
      rhythmValue: rhythm(
        kind: HavenRhythmKind.roomToGrow,
        signalCount: 5,
        suggestedFocusMinutes: 60,
      ),
      forecastValue: forecast(
        kind: FocusForecastKind.emergingWindow,
        signalCount: 8,
        window: FocusForecastWindow.afternoon,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.recoveryPriority);
    expect(result.direction, AdaptiveFocusDirection.gentler);
    expect(result.suggestedFocusMinutes, 10);
    expect(result.suggestedBreakMinutes, 5);
    expect(result.usesRecoveryPattern, isTrue);
    expect(result.usesLatestReflection, isFalse);
    expect(result.usesRepeatedRhythm, isFalse);
    expect(result.usesForecast, isTrue);
    expect(result.evidenceStrength, AdaptiveFocusEvidenceStrength.reinforced);
  });

  test('recovery detection is based on timestamps, not caller order', () {
    final result = suggestion(
      currentFocusMinutes: 25,
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 60,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 5),
        event(outcome: FocusEventOutcome.reset),
      ],
    )!;

    expect(result.basis, AdaptiveFocusBasis.recoveryPriority);
    expect(result.suggestedFocusMinutes, 10);
  });

  test('a latest too-much reflection cannot be reversed by growth data', () {
    final result = suggestion(
      currentFocusMinutes: 25,
      currentBreakMinutes: 2,
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.tooMuch,
        ),
      ],
      rhythmValue: rhythm(
        kind: HavenRhythmKind.roomToGrow,
        signalCount: 6,
        suggestedFocusMinutes: 60,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.latestReflection);
    expect(result.direction, AdaptiveFocusDirection.gentler);
    expect(result.suggestedFocusMinutes, 15);
    expect(result.suggestedBreakMinutes, 5);
    expect(result.breakDirection, AdaptiveFocusBreakDirection.moreRecovery);
    expect(result.usesLatestReflection, isTrue);
    expect(result.usesRepeatedRhythm, isFalse);
  });

  test('one could-do-more reflection is insufficient to lengthen focus', () {
    final result = suggestion(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
      rhythmValue: rhythm(
        kind: HavenRhythmKind.learning,
        signalCount: 2,
        suggestedFocusMinutes: 45,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.latestReflection);
    expect(result.suggestedFocusMinutes, 25);
    expect(result.changesAnything, isFalse);
    expect(result.usesLatestReflection, isTrue);
    expect(result.usesRepeatedRhythm, isFalse);
    expect(result.evidenceStrength, AdaptiveFocusEvidenceStrength.limited);
  });

  test('repeated room-to-grow evidence permits only one bounded step', () {
    final result = suggestion(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
      rhythmValue: rhythm(
        kind: HavenRhythmKind.roomToGrow,
        signalCount: 4,
        suggestedFocusMinutes: 90,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.repeatedRhythm);
    expect(result.direction, AdaptiveFocusDirection.roomToGrow);
    expect(result.suggestedFocusMinutes, 45);
    expect(result.suggestedBreakMinutes, 5);
    expect(result.usesLatestReflection, isTrue);
    expect(result.usesRepeatedRhythm, isTrue);
    expect(result.relevantSignalCount, 5);
    expect(result.evidenceStrength, AdaptiveFocusEvidenceStrength.reinforced);
  });

  test('qualified gentler rhythm never lengthens the current choice', () {
    final result = suggestion(
      currentFocusMinutes: 45,
      currentBreakMinutes: 5,
      rhythmValue: rhythm(
        kind: HavenRhythmKind.gentlerPace,
        signalCount: 3,
        suggestedFocusMinutes: 15,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.repeatedRhythm);
    expect(result.suggestedFocusMinutes, 15);
    expect(result.direction, AdaptiveFocusDirection.gentler);
    expect(result.usesRepeatedRhythm, isTrue);
  });

  test('a qualified forecast adds timing context without changing pace', () {
    final result = suggestion(
      currentFocusMinutes: 30,
      currentBreakMinutes: 8,
      forecastValue: forecast(
        kind: FocusForecastKind.emergingWindow,
        signalCount: 6,
        window: FocusForecastWindow.evening,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.currentBaseline);
    expect(result.suggestedFocusMinutes, 30);
    expect(result.suggestedBreakMinutes, 8);
    expect(result.possibleWindow, FocusForecastWindow.evening);
    expect(result.usesForecast, isTrue);
    expect(result.changesAnything, isFalse);
  });

  test('unqualified timing and rhythm evidence remain absent', () {
    final result = suggestion(
      forecastValue: forecast(
        kind: FocusForecastKind.emergingWindow,
        signalCount: 5,
        window: FocusForecastWindow.lateNight,
      ),
      rhythmValue: rhythm(
        kind: HavenRhythmKind.roomToGrow,
        signalCount: 2,
        suggestedFocusMinutes: 60,
      ),
    )!;

    expect(result.basis, AdaptiveFocusBasis.currentBaseline);
    expect(result.hasPossibleWindow, isFalse);
    expect(result.usesRepeatedRhythm, isFalse);
    expect(result.changesAnything, isFalse);
  });

  test('Riverpod composes only explicit choices and owner snapshots', () {
    final events = [
      event(outcome: FocusEventOutcome.reset),
      event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 5),
    ];
    final container = ProviderContainer(
      overrides: [
        timerFocusEventsProvider.overrideWithValue(events),
        havenRhythmInsightProvider.overrideWithValue(
          rhythm(
            kind: HavenRhythmKind.roomToGrow,
            signalCount: 4,
            suggestedFocusMinutes: 60,
          ),
        ),
        focusForecastProvider.overrideWithValue(
          forecast(
            kind: FocusForecastKind.emergingWindow,
            signalCount: 6,
            window: FocusForecastWindow.morning,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(
      adaptiveFocusSuggestionProvider((
        currentFocusMinutes: 45,
        currentBreakMinutes: 5,
        preserveCurrentChoice: false,
      )),
    )!;

    expect(result.basis, AdaptiveFocusBasis.recoveryPriority);
    expect(result.suggestedFocusMinutes, 10);
    expect(result.possibleWindow, FocusForecastWindow.morning);
  });
}
