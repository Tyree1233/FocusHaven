import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/haven_plan.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_plan_service.dart';

void main() {
  const service = HavenPlanService();
  const firstTask = HavenTaskCandidate(
    id: 'task-1',
    title: 'Finish the presentation',
  );

  FocusEvent event({
    required FocusEventOutcome outcome,
    int focusedMinutes = 10,
    int plannedMinutes = 25,
    int ageMinutes = 0,
    FocusSessionFit? sessionFit,
  }) {
    final endedAt = DateTime.utc(
      2026,
      8,
      16,
      20,
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

  test('starts with one queued task and a transparent steady plan', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: const [],
      energy: HavenEnergy.steady,
      availableMinutes: 30,
    );

    expect(plan.queueItemId, 'task-1');
    expect(plan.taskTitle, 'Finish the presentation');
    expect(plan.firstStep, contains('smallest visible action'));
    expect(plan.focusMinutes, 25);
    expect(plan.breakMinutes, 5);
    expect(plan.totalPlannedMinutes, 30);
    expect(plan.basis, HavenPlanBasis.freshStart);
    expect(plan.usesPersonalHistory, isFalse);
    expect(plan.explanation, contains('while FocusHaven learns'));
  });

  test('a low-energy check-in creates a gentler starting point', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: const [],
      energy: HavenEnergy.low,
      availableMinutes: 20,
    );

    expect(plan.focusMinutes, 10);
    expect(plan.breakMinutes, 2);
    expect(plan.basis, HavenPlanBasis.gentleStart);
    expect(plan.explanation, contains('gentler'));
  });

  test('recent interrupted attempts take priority over optimization', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(outcome: FocusEventOutcome.reset),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 20),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
          ageMinutes: 40,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
          ageMinutes: 100,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
          ageMinutes: 160,
        ),
      ],
      energy: HavenEnergy.strong,
      availableMinutes: 90,
    );

    expect(plan.focusMinutes, 10);
    expect(plan.basis, HavenPlanBasis.recentRecovery);
    expect(plan.supportsRecovery, isTrue);
    expect(plan.explanation, contains('lower the pressure'));
  });

  test('recovery detection uses timestamps instead of caller list order', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 45,
          plannedMinutes: 45,
          ageMinutes: 120,
        ),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
        event(outcome: FocusEventOutcome.reset),
      ],
      energy: HavenEnergy.strong,
      availableMinutes: 60,
    );

    expect(plan.basis, HavenPlanBasis.recentRecovery);
    expect(plan.focusMinutes, 10);
  });

  test('three completed sessions can establish a personal rhythm', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 40,
          plannedMinutes: 40,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 45,
          plannedMinutes: 45,
          ageMinutes: 60,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 50,
          plannedMinutes: 50,
          ageMinutes: 120,
        ),
      ],
      energy: HavenEnergy.strong,
      availableMinutes: 60,
    );

    expect(plan.focusMinutes, 45);
    expect(plan.breakMinutes, 10);
    expect(plan.basis, HavenPlanBasis.personalRhythm);
    expect(plan.usesPersonalHistory, isTrue);
    expect(plan.explanation, contains('recent completed sessions'));
  });

  test('a too-much reflection gently steps the next plan down', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 25,
          plannedMinutes: 25,
          sessionFit: FocusSessionFit.tooMuch,
        ),
      ],
      energy: HavenEnergy.steady,
      availableMinutes: 60,
    );

    expect(plan.focusMinutes, 15);
    expect(plan.basis, HavenPlanBasis.sessionReflection);
    expect(plan.usesPersonalHistory, isTrue);
    expect(plan.usesSessionReflection, isTrue);
    expect(plan.explanation, contains('steps down gently'));
  });

  test('about-right and could-do-more reflections adjust one bounded step', () {
    HavenPlan planFor(FocusSessionFit sessionFit) => service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 25,
          plannedMinutes: 25,
          sessionFit: sessionFit,
        ),
      ],
      energy: HavenEnergy.strong,
      availableMinutes: 60,
    );

    final aboutRight = planFor(FocusSessionFit.aboutRight);
    final couldDoMore = planFor(FocusSessionFit.couldDoMore);

    expect(aboutRight.focusMinutes, 25);
    expect(aboutRight.explanation, contains('stays close'));
    expect(couldDoMore.focusMinutes, 45);
    expect(couldDoMore.explanation, contains('one small step up'));
  });

  test(
    'recovery and current energy remain stronger than ambition feedback',
    () {
      final reflected = event(
        outcome: FocusEventOutcome.completed,
        focusedMinutes: 25,
        plannedMinutes: 25,
        ageMinutes: 30,
        sessionFit: FocusSessionFit.couldDoMore,
      );
      final recoveryPlan = service.createPlan(
        queue: const [firstTask],
        recentEvents: [
          event(outcome: FocusEventOutcome.reset),
          event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
          reflected,
        ],
        energy: HavenEnergy.strong,
        availableMinutes: 60,
      );
      final lowEnergyPlan = service.createPlan(
        queue: const [firstTask],
        recentEvents: [reflected],
        energy: HavenEnergy.low,
        availableMinutes: 60,
      );

      expect(recoveryPlan.basis, HavenPlanBasis.recentRecovery);
      expect(recoveryPlan.focusMinutes, 10);
      expect(lowEnergyPlan.basis, HavenPlanBasis.sessionReflection);
      expect(lowEnergyPlan.focusMinutes, 15);
      expect(lowEnergyPlan.wasEnergyBound, isTrue);
    },
  );

  test('insufficient history never claims a learned rhythm', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
          ageMinutes: 60,
        ),
      ],
      energy: HavenEnergy.steady,
      availableMinutes: 90,
    );

    expect(plan.focusMinutes, 25);
    expect(plan.basis, HavenPlanBasis.freshStart);
    expect(plan.usesPersonalHistory, isFalse);
  });

  test('recommendations fit the available time without overcommitting', () {
    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: const [],
      energy: HavenEnergy.strong,
      availableMinutes: 20,
    );

    expect(plan.focusMinutes, 15);
    expect(plan.breakMinutes, 3);
    expect(plan.totalPlannedMinutes, lessThanOrEqualTo(20));
    expect(plan.wasTimeBound, isTrue);
    expect(plan.explanation, contains('fit the time'));
  });

  test('energy limits remain respected after learning a rhythm', () {
    final history = [
      for (var index = 0; index < 3; index++)
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 60,
          plannedMinutes: 60,
          ageMinutes: index * 60,
        ),
    ];

    final plan = service.createPlan(
      queue: const [firstTask],
      recentEvents: history,
      energy: HavenEnergy.low,
      availableMinutes: 90,
    );

    expect(plan.focusMinutes, 15);
    expect(plan.basis, HavenPlanBasis.personalRhythm);
    expect(plan.usesPersonalHistory, isTrue);
    expect(plan.wasEnergyBound, isTrue);
    expect(plan.explanation, contains('energy you have today'));
  });

  test('empty queues produce a safe user-controlled next step', () {
    final plan = service.createPlan(
      queue: const [],
      recentEvents: const [],
      energy: HavenEnergy.steady,
      availableMinutes: 30,
    );

    expect(plan.queueItemId, isNull);
    expect(plan.taskTitle, 'Choose one small next step');
    expect(plan.firstStep, startsWith('Name one visible action'));
  });

  test('invalid candidates are skipped and valid titles are normalized', () {
    final plan = service.createPlan(
      queue: const [
        HavenTaskCandidate(id: '', title: 'Skip me'),
        HavenTaskCandidate(id: 'task-2', title: '  Draft   the outline  '),
      ],
      recentEvents: const [],
      energy: HavenEnergy.steady,
      availableMinutes: 30,
    );

    expect(plan.queueItemId, 'task-2');
    expect(plan.taskTitle, 'Draft the outline');
  });

  test('Riverpod composes the current queue and private event snapshots', () {
    final container = ProviderContainer(
      overrides: [
        focusQueueStateProvider.overrideWithValue((
          activeItems: const [
            FocusQueueItem(id: 'provider-task', title: 'Provider task'),
          ],
          completedItems: const [],
          completedToday: 0,
        )),
        timerFocusEventsProvider.overrideWithValue([
          event(outcome: FocusEventOutcome.reset),
          event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final plan = container.read(
      havenPlanProvider((energy: HavenEnergy.strong, availableMinutes: 60)),
    );

    expect(plan.queueItemId, 'provider-task');
    expect(plan.taskTitle, 'Provider task');
    expect(plan.basis, HavenPlanBasis.recentRecovery);
    expect(plan.focusMinutes, 10);
  });
}
