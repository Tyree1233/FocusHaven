import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/smart_reset_plan.dart';
import 'package:focushaven/services/smart_reset_service.dart';

void main() {
  const service = SmartResetService();

  FocusEvent event({
    required FocusEventOutcome outcome,
    required int ageMinutes,
  }) {
    final endedAt = DateTime.utc(
      2026,
      8,
      16,
      18,
    ).subtract(Duration(minutes: ageMinutes));
    return FocusEvent(
      startedAt: endedAt.subtract(const Duration(minutes: 5)),
      endedAt: endedAt,
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: 5 * 60,
      pauseCount: 0,
      didResume: false,
      outcome: outcome,
    );
  }

  test('offers a shorter ten-minute return to a standard session', () {
    final plan = service.createPlan(
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: 2 * 60,
      recentEvents: const [],
    );

    expect(plan.restartDurationSeconds, 10 * 60);
    expect(plan.originalDurationSeconds, 25 * 60);
    expect(plan.focusedDurationSeconds, 2 * 60);
    expect(plan.basis, SmartResetBasis.gentleReturn);
    expect(plan.explanation, contains('more reachable'));
  });

  test('acknowledges meaningful effort without calling it completion', () {
    final plan = service.createPlan(
      plannedDurationSeconds: 45 * 60,
      focusedDurationSeconds: 12 * 60,
      recentEvents: const [],
    );

    expect(plan.restartDurationSeconds, 10 * 60);
    expect(plan.basis, SmartResetBasis.meaningfulProgress);
    expect(plan.acknowledgesProgress, isTrue);
    expect(plan.explanation, contains('focus you already gave'));
  });

  test('repeated recovery signals choose the lowest-pressure return', () {
    final plan = service.createPlan(
      plannedDurationSeconds: 45 * 60,
      focusedDurationSeconds: 12 * 60,
      recentEvents: [
        event(outcome: FocusEventOutcome.completed, ageMinutes: 60),
        event(outcome: FocusEventOutcome.discardedResume, ageMinutes: 10),
        event(outcome: FocusEventOutcome.reset, ageMinutes: 0),
      ],
    );

    expect(plan.restartDurationSeconds, 5 * 60);
    expect(plan.basis, SmartResetBasis.repeatedRecovery);
    expect(plan.respondsToRepeatedRecovery, isTrue);
    expect(plan.explanation, contains('less pressure'));
  });

  test('very short sessions are still made genuinely smaller', () {
    final plan = service.createPlan(
      plannedDurationSeconds: 5 * 60,
      focusedDurationSeconds: 30,
      recentEvents: const [],
    );

    expect(plan.restartDurationSeconds, 2 * 60 + 30);
    expect(plan.restartDurationSeconds, lessThan(plan.originalDurationSeconds));
  });

  test('invalid attempt values are rejected', () {
    expect(
      () => service.createPlan(
        plannedDurationSeconds: 1,
        focusedDurationSeconds: 0,
        recentEvents: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => service.createPlan(
        plannedDurationSeconds: 60,
        focusedDurationSeconds: 61,
        recentEvents: const [],
      ),
      throwsArgumentError,
    );
  });
}
