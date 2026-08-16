import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_rhythm_service.dart';

void main() {
  const service = HavenRhythmService();

  FocusEvent event({
    required FocusEventOutcome outcome,
    int focusedMinutes = 25,
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

  test('starts with an honest learning state instead of a score', () {
    final insight = service.createInsight(recentEvents: const []);

    expect(insight.kind, HavenRhythmKind.learning);
    expect(insight.isLearning, isTrue);
    expect(insight.signalCount, 0);
    expect(insight.hasSuggestedPace, isFalse);
    expect(insight.headline, contains('still forming'));
    expect(insight.evidence, contains('No private'));
  });

  test('recent recovery takes priority over optimization feedback', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 30,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
        event(
          outcome: FocusEventOutcome.discardedResume,
          focusedMinutes: 5,
          ageMinutes: 10,
        ),
        event(outcome: FocusEventOutcome.reset, focusedMinutes: 5),
      ],
    );

    expect(insight.kind, HavenRhythmKind.gentleReturn);
    expect(insight.suggestedFocusMinutes, 10);
    expect(insight.usesSessionReflections, isFalse);
    expect(insight.evidence, contains('2 of the last 3'));
  });

  test('recovery detection sorts events instead of trusting caller order', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 60,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
        event(outcome: FocusEventOutcome.reset, focusedMinutes: 5),
        event(
          outcome: FocusEventOutcome.discardedResume,
          focusedMinutes: 5,
          ageMinutes: 10,
        ),
      ],
    );

    expect(insight.kind, HavenRhythmKind.gentleReturn);
    expect(insight.signalCount, 3);
  });

  test('repeated too-much reflections recommend one gentler step', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.tooMuch,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 30,
          sessionFit: FocusSessionFit.tooMuch,
        ),
      ],
    );

    expect(insight.kind, HavenRhythmKind.gentlerPace);
    expect(insight.suggestedFocusMinutes, 15);
    expect(insight.usesSessionReflections, isTrue);
    expect(insight.evidence, contains('2 of 2'));
  });

  test('about-right reflections identify a sustainable nearby pace', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 20,
          plannedMinutes: 20,
          sessionFit: FocusSessionFit.aboutRight,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 30,
          sessionFit: FocusSessionFit.aboutRight,
        ),
      ],
    );

    expect(insight.kind, HavenRhythmKind.sustainablePace);
    expect(insight.suggestedFocusMinutes, 25);
    expect(insight.headline, contains('25 minutes'));
    expect(insight.detail, contains('About right'));
  });

  test('could-do-more reflections offer only one bounded step up', () {
    final ordinary = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 30,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
    );
    final maximum = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 120,
          plannedMinutes: 120,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 120,
          plannedMinutes: 120,
          ageMinutes: 130,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
    );

    expect(ordinary.kind, HavenRhythmKind.roomToGrow);
    expect(ordinary.suggestedFocusMinutes, 45);
    expect(maximum.suggestedFocusMinutes, 90);
  });

  test('mixed reflections are reported without forcing a conclusion', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          sessionFit: FocusSessionFit.tooMuch,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 30,
          sessionFit: FocusSessionFit.aboutRight,
        ),
        event(
          outcome: FocusEventOutcome.completed,
          ageMinutes: 60,
          sessionFit: FocusSessionFit.couldDoMore,
        ),
      ],
    );

    expect(insight.kind, HavenRhythmKind.variablePace);
    expect(insight.hasSuggestedPace, isFalse);
    expect(insight.usesSessionReflections, isTrue);
    expect(insight.detail, contains('mixed'));
  });

  test('completions alone are observations rather than feeling claims', () {
    final insight = service.createInsight(
      recentEvents: [
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 20,
          plannedMinutes: 20,
        ),
        event(outcome: FocusEventOutcome.completed, ageMinutes: 30),
        event(
          outcome: FocusEventOutcome.completed,
          focusedMinutes: 30,
          plannedMinutes: 30,
          ageMinutes: 60,
        ),
      ],
    );

    expect(insight.kind, HavenRhythmKind.completionPattern);
    expect(insight.suggestedFocusMinutes, 25);
    expect(insight.usesSessionReflections, isFalse);
    expect(insight.detail, contains('Only your reflections'));
    expect(insight.headline, isNot(contains('sustainable')));
  });

  test(
    'Riverpod derives the current ephemeral insight from event snapshots',
    () {
      final container = ProviderContainer(
        overrides: [
          timerFocusEventsProvider.overrideWithValue([
            event(
              outcome: FocusEventOutcome.completed,
              sessionFit: FocusSessionFit.aboutRight,
            ),
            event(
              outcome: FocusEventOutcome.completed,
              ageMinutes: 30,
              sessionFit: FocusSessionFit.aboutRight,
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);

      final insight = container.read(havenRhythmInsightProvider);

      expect(insight.kind, HavenRhythmKind.sustainablePace);
      expect(insight.suggestedFocusMinutes, 25);
    },
  );
}
