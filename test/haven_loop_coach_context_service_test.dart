import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/models/haven_loop_coach_context.dart';
import 'package:focushaven/models/haven_loop_state.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_loop_coach_context_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  const service = HavenLoopCoachContextService();
  const selectedItem = FocusQueueItem(
    id: 'private-queue-id',
    title: 'Private authored task',
  );

  FocusEvent completedEvent({FocusSessionFit? fit, int offset = 0}) =>
      FocusEvent(
        startedAt: DateTime.utc(2026, 9, 6, 12, offset),
        endedAt: DateTime.utc(2026, 9, 6, 12, offset + 25),
        plannedDurationSeconds: 1500,
        focusedDurationSeconds: 1500,
        pauseCount: 0,
        didResume: false,
        outcome: FocusEventOutcome.completed,
        sessionFit: fit,
      );

  HavenLoopState loop({
    HavenLoopPhase phase = HavenLoopPhase.completed,
    FocusQueueItem? selected,
    bool canResolve = false,
    bool initialized = true,
  }) => HavenLoopState(
    selectedItem: selected,
    phase: phase,
    canResolveCompletion: canResolve,
    isInitialized: initialized,
  );

  HavenLoopCoachContext? create({
    required HavenLoopState loopState,
    SessionType sessionType = SessionType.focus,
    bool isComplete = true,
    bool canOfferSmartReset = false,
    FocusCompletionIdentity? completion,
    FocusSessionFit? fit,
    List<FocusEvent> events = const [],
    HavenRhythmReflectionConnection? rhythm,
    FocusForecastReflectionConnection? forecast,
    HavenJourneyCompletionConnection? journey,
  }) => service.createContext(
    loop: loopState,
    sessionType: sessionType,
    isComplete: isComplete,
    canOfferSmartReset: canOfferSmartReset,
    completion: completion,
    sessionFit: fit,
    recentEvents: events,
    rhythmConnection: rhythm,
    forecastConnection: forecast,
    journeyConnection: journey,
  );

  test('starts closed and rejects non-Focus or inconsistent owners', () {
    final event = completedEvent();
    final completion = event.completionIdentity;

    expect(
      create(
        loopState: loop(initialized: false),
        completion: completion,
        events: [event],
      ),
      isNull,
    );
    expect(
      create(
        loopState: loop(),
        sessionType: SessionType.shortBreak,
        completion: completion,
        events: [event],
      ),
      isNull,
    );
    expect(
      create(
        loopState: loop(phase: HavenLoopPhase.paused),
        completion: completion,
        events: [event],
      ),
      isNull,
    );
  });

  test('exposes a linked Smart Reset choice without copying identity', () {
    final context = create(
      loopState: loop(phase: HavenLoopPhase.paused, selected: selectedItem),
      isComplete: false,
      canOfferSmartReset: true,
    );

    expect(context, isNotNull);
    expect(context!.moment, HavenLoopCoachMoment.smartResetChoice);
    expect(context.hasLinkedTask, isTrue);
    expect(context.completion, isNull);
    expect(context.sessionFit, isNull);
    expect(context.usesRhythm, isFalse);
    expect(context.usesForecast, isFalse);
    expect(context.usesJourney, isFalse);
  });

  test('requires one exact latest completion before a task decision', () {
    final event = completedEvent();
    final context = create(
      loopState: loop(selected: selectedItem, canResolve: true),
      completion: event.completionIdentity,
      events: [event],
    );

    expect(context, isNotNull);
    expect(context!.moment, HavenLoopCoachMoment.taskDecision);
    expect(context.hasLinkedTask, isTrue);
    expect(context.completion, event.completionIdentity);

    expect(
      create(
        loopState: loop(selected: selectedItem, canResolve: true),
        completion: event.completionIdentity,
        events: [event, event],
      ),
      isNull,
    );
    expect(
      create(
        loopState: loop(selected: selectedItem, canResolve: true),
        completion: event.completionIdentity,
        events: [event, completedEvent(offset: 30)],
      ),
      isNull,
    );
  });

  test('offers an optional reflection only after task ownership settles', () {
    final event = completedEvent();
    final context = create(
      loopState: loop(),
      completion: event.completionIdentity,
      events: [event],
    );

    expect(context, isNotNull);
    expect(context!.moment, HavenLoopCoachMoment.reflectionChoice);
    expect(context.hasLinkedTask, isFalse);

    expect(
      create(
        loopState: loop(selected: selectedItem),
        completion: event.completionIdentity,
        events: [event],
      ),
      isNull,
    );
  });

  test('maps each exact saved fit to a calm next-session moment', () {
    final expected = <FocusSessionFit, HavenLoopCoachMoment>{
      FocusSessionFit.tooMuch: HavenLoopCoachMoment.gentlerNextSession,
      FocusSessionFit.aboutRight: HavenLoopCoachMoment.steadyNextSession,
      FocusSessionFit.couldDoMore: HavenLoopCoachMoment.flexibleNextSession,
    };

    for (final entry in expected.entries) {
      final event = completedEvent(fit: entry.key);
      final context = create(
        loopState: loop(),
        completion: event.completionIdentity,
        fit: entry.key,
        events: [event],
      );

      expect(context, isNotNull, reason: entry.key.name);
      expect(context!.moment, entry.value, reason: entry.key.name);
      expect(context.sessionFit, entry.key, reason: entry.key.name);
    }
  });

  test('accepts only connections bound to the exact completion and fit', () {
    final event = completedEvent(fit: FocusSessionFit.aboutRight);
    final completion = event.completionIdentity!;
    final staleCompletion = completedEvent(offset: 30).completionIdentity!;
    const insight = HavenRhythmInsight(
      kind: HavenRhythmKind.learning,
      headline: 'not copied',
      detail: 'not copied',
      evidence: 'not copied',
      signalCount: 1,
      usesSessionReflections: true,
    );
    const forecastState = FocusForecast(
      kind: FocusForecastKind.learning,
      headline: 'not copied',
      detail: 'not copied',
      evidence: 'not copied',
      signalCount: 1,
    );
    final rhythm = HavenRhythmReflectionConnection(
      kind: HavenRhythmReflectionConnectionKind.learning,
      completion: completion,
      selectedFit: FocusSessionFit.aboutRight,
      insight: insight,
      headline: 'not copied',
      detail: 'not copied',
    );
    final forecast = FocusForecastReflectionConnection(
      kind: FocusForecastReflectionConnectionKind.learning,
      completion: completion,
      selectedFit: FocusSessionFit.aboutRight,
      forecast: forecastState,
      completedWindow: FocusForecastWindow.afternoon,
      headline: 'not copied',
      detail: 'not copied',
    );
    final journey = HavenJourneyCompletionConnection(
      kind: HavenJourneyCompletionConnectionKind.placeHeld,
      completion: completion,
      previousPlace: HavenJourneyPlace.cabin,
      currentPlace: HavenJourneyPlace.cabin,
      headline: 'not copied',
      detail: 'not copied',
    );

    final context = create(
      loopState: loop(),
      completion: completion,
      fit: FocusSessionFit.aboutRight,
      events: [event],
      rhythm: rhythm,
      forecast: forecast,
      journey: journey,
    );
    expect(context, isNotNull);
    expect(context!.rhythmKind, rhythm.kind);
    expect(context.forecastKind, forecast.kind);
    expect(context.journeyKind, journey.kind);

    final staleRhythm = HavenRhythmReflectionConnection(
      kind: rhythm.kind,
      completion: staleCompletion,
      selectedFit: rhythm.selectedFit,
      insight: insight,
      headline: 'not copied',
      detail: 'not copied',
    );
    expect(
      create(
        loopState: loop(),
        completion: completion,
        fit: FocusSessionFit.aboutRight,
        events: [event],
        rhythm: staleRhythm,
      ),
      isNull,
    );
  });

  test('the bridge has no authored text or serialization boundary', () {
    final model = File(
      'lib/models/haven_loop_coach_context.dart',
    ).readAsStringSync();
    final serviceSource = File(
      'lib/services/haven_loop_coach_context_service.dart',
    ).readAsStringSync();

    expect(model, isNot(contains('String ')));
    expect(model, isNot(contains('toJson')));
    expect(model, isNot(contains('fromJson')));
    expect(serviceSource, isNot(contains('SharedPreferences')));
    expect(serviceSource, isNot(contains('firebase')));
    expect(serviceSource, isNot(contains('http')));
    expect(serviceSource, isNot(contains('.title')));
    expect(serviceSource, isNot(contains('selectedItemId')));
  });
}
