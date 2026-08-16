import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/living_lantern_state.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/living_lantern_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  const service = LivingLanternService();

  FocusEvent event({required FocusEventOutcome outcome, int ageMinutes = 0}) {
    final endedAt = DateTime.utc(
      2026,
      8,
      16,
      20,
    ).subtract(Duration(minutes: ageMinutes));
    final focusedMinutes = outcome == FocusEventOutcome.completed ? 25 : 5;
    return FocusEvent(
      startedAt: endedAt.subtract(Duration(minutes: focusedMinutes)),
      endedAt: endedAt,
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: focusedMinutes * 60,
      pauseCount: 0,
      didResume: false,
      outcome: outcome,
    );
  }

  LivingLanternState createState({
    SessionType sessionType = SessionType.focus,
    bool isRunning = false,
    bool isComplete = false,
    bool hasPendingResume = false,
    List<FocusEvent> recentEvents = const [],
  }) => service.createState(
    sessionType: sessionType,
    isRunning: isRunning,
    isComplete: isComplete,
    hasPendingResume: hasPendingResume,
    recentEvents: recentEvents,
  );

  test('starts ready without inventing history or a score', () {
    final lantern = createState();

    expect(lantern.phase, LivingLanternPhase.ready);
    expect(lantern.isActive, isFalse);
    expect(lantern.usesRecentEvents, isFalse);
    expect(lantern.supportingSignalCount, 0);
    expect(lantern.headline, contains('ready'));
    expect(lantern.detail, contains('presence'));
  });

  test('running focus produces a steady non-scoring state', () {
    final lantern = createState(isRunning: true);

    expect(lantern.phase, LivingLanternPhase.focusing);
    expect(lantern.isActive, isTrue);
    expect(lantern.supportingSignalCount, 0);
    expect(lantern.headline, contains('steady'));
    expect(lantern.detail, contains('without keeping score'));
  });

  test('running and idle breaks both honor rest', () {
    final running = createState(
      sessionType: SessionType.shortBreak,
      isRunning: true,
    );
    final idle = createState(sessionType: SessionType.longBreak);

    expect(running.phase, LivingLanternPhase.resting);
    expect(running.isActive, isTrue);
    expect(running.detail, contains('nothing else to earn'));
    expect(idle.phase, LivingLanternPhase.resting);
    expect(idle.isActive, isTrue);
    expect(idle.detail, contains('sustainable focus'));
  });

  test('completed break waits without rushing another session', () {
    final lantern = createState(
      sessionType: SessionType.shortBreak,
      isComplete: true,
    );

    expect(lantern.phase, LivingLanternPhase.ready);
    expect(lantern.headline, contains('when you choose'));
    expect(lantern.detail, contains('without rushing'));
  });

  test('completed focus celebrates without requiring more', () {
    final lantern = createState(isComplete: true);

    expect(lantern.phase, LivingLanternPhase.celebrating);
    expect(lantern.isCelebrating, isTrue);
    expect(lantern.detail, contains('does not depend'));
    expect(lantern.supportingSignalCount, 0);
  });

  test('pending resume takes priority without erasing effort', () {
    final lantern = createState(
      hasPendingResume: true,
      recentEvents: [event(outcome: FocusEventOutcome.completed)],
    );

    expect(lantern.phase, LivingLanternPhase.gentleReturn);
    expect(lantern.isGentleReturn, isTrue);
    expect(lantern.detail, contains('Nothing about the pause erased'));
    expect(lantern.usesRecentEvents, isFalse);
  });

  test('repeated recent recovery offers a gentle return', () {
    final lantern = createState(
      recentEvents: [
        event(outcome: FocusEventOutcome.reset, ageMinutes: 5),
        event(outcome: FocusEventOutcome.discardedResume),
      ],
    );

    expect(lantern.phase, LivingLanternPhase.gentleReturn);
    expect(lantern.supportingSignalCount, 2);
    expect(lantern.usesRecentEvents, isTrue);
    expect(lantern.headline, contains('smaller return'));
    expect(lantern.detail, contains('stays whole'));
  });

  test('recovery detection sorts events and ignores session changes', () {
    final lantern = createState(
      recentEvents: [
        event(outcome: FocusEventOutcome.completed, ageMinutes: 60),
        event(outcome: FocusEventOutcome.reset, ageMinutes: 5),
        event(outcome: FocusEventOutcome.changedSession),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
      ],
    );

    expect(lantern.phase, LivingLanternPhase.gentleReturn);
    expect(lantern.supportingSignalCount, 2);
  });

  test('one interrupted attempt never becomes a failure state', () {
    final lantern = createState(
      recentEvents: [
        event(outcome: FocusEventOutcome.reset),
        event(outcome: FocusEventOutcome.completed, ageMinutes: 10),
      ],
    );

    expect(lantern.phase, LivingLanternPhase.ready);
    expect(lantern.isGentleReturn, isFalse);
    expect(lantern.supportingSignalCount, 1);
    expect(lantern.detail, contains('Past focus still counts'));
  });

  test('rejects an impossible running and complete timer state', () {
    expect(
      () => createState(isRunning: true, isComplete: true),
      throwsArgumentError,
    );
  });

  test('Riverpod composes the current ephemeral lantern state', () {
    const focusingSession = (
      sessionType: SessionType.focus,
      isRunning: true,
      isComplete: false,
      hasPendingResume: false,
      focusTask: '',
      parkedThoughtCount: 0,
      completionMessage: '',
      completedFocusSessionFit: null,
    );
    final container = ProviderContainer(
      overrides: [
        timerSessionStateProvider.overrideWithValue(focusingSession),
        timerFocusEventsProvider.overrideWithValue([
          event(outcome: FocusEventOutcome.reset),
          event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final lantern = container.read(livingLanternStateProvider);

    expect(lantern.phase, LivingLanternPhase.focusing);
    expect(lantern.supportingSignalCount, 0);
  });
}
