import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';

void main() {
  test('focus events round trip as bounded text-free UTC signals', () {
    final event = FocusEvent(
      startedAt: DateTime.parse('2026-08-16T19:00:00-05:00'),
      endedAt: DateTime.parse('2026-08-16T19:25:00-05:00'),
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: 25 * 60,
      pauseCount: 1,
      didResume: true,
      outcome: FocusEventOutcome.completed,
    );

    final json = event.toJson();
    final restored = FocusEvent.fromJson(json);

    expect(json.keys.toSet(), {
      'schemaVersion',
      'startedAt',
      'endedAt',
      'plannedDurationSeconds',
      'focusedDurationSeconds',
      'pauseCount',
      'didResume',
      'outcome',
    });
    expect(json.toString(), isNot(contains('task')));
    expect(json.toString(), isNot(contains('mood')));
    expect(restored.startedAt.isUtc, isTrue);
    expect(restored.endedAt.isUtc, isTrue);
    expect(restored.plannedDurationSeconds, 25 * 60);
    expect(restored.focusedDurationSeconds, 25 * 60);
    expect(restored.pauseCount, 1);
    expect(restored.didResume, isTrue);
    expect(restored.outcome, FocusEventOutcome.completed);
    expect(restored.wasCompleted, isTrue);
    expect(restored.canSupportRecovery, isFalse);
  });

  test('reset and discarded attempts can support a compassionate recovery', () {
    FocusEvent event(FocusEventOutcome outcome) => FocusEvent(
      startedAt: DateTime.utc(2026, 8, 16, 12),
      endedAt: DateTime.utc(2026, 8, 16, 12, 5),
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: 5 * 60,
      pauseCount: 0,
      didResume: false,
      outcome: outcome,
    );

    expect(event(FocusEventOutcome.reset).canSupportRecovery, isTrue);
    expect(event(FocusEventOutcome.discardedResume).canSupportRecovery, isTrue);
    expect(event(FocusEventOutcome.changedSession).canSupportRecovery, isFalse);
  });

  test('damaged or impossible focus events are rejected', () {
    final valid = FocusEvent(
      startedAt: DateTime.utc(2026, 8, 16, 12),
      endedAt: DateTime.utc(2026, 8, 16, 12, 5),
      plannedDurationSeconds: 300,
      focusedDurationSeconds: 240,
      pauseCount: 1,
      didResume: true,
      outcome: FocusEventOutcome.reset,
    ).toJson();

    final invalidEvents = <Map<String, dynamic>>[
      {...valid, 'schemaVersion': 99},
      {...valid, 'endedAt': 'not-a-date'},
      {...valid, 'endedAt': DateTime.utc(2026, 8, 16, 11).toIso8601String()},
      {...valid, 'plannedDurationSeconds': 0},
      {...valid, 'focusedDurationSeconds': 301},
      {...valid, 'pauseCount': -1},
      {...valid, 'didResume': 'yes'},
      {...valid, 'outcome': 'punished'},
    ];

    for (final json in invalidEvents) {
      expect(() => FocusEvent.fromJson(json), throwsFormatException);
    }
  });
}
