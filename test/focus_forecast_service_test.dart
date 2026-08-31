import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_forecast_service.dart';

void main() {
  const service = FocusForecastService();

  FocusEvent event({
    required int startHour,
    int ageDays = 0,
    FocusEventOutcome outcome = FocusEventOutcome.completed,
    FocusSessionFit? sessionFit,
    bool deviceLocal = false,
  }) {
    final localOrUtcStart = deviceLocal
        ? DateTime(2026, 8, 16 - ageDays, startHour)
        : DateTime.utc(2026, 8, 16 - ageDays, startHour);
    final startedAt = deviceLocal ? localOrUtcStart.toUtc() : localOrUtcStart;
    final focusedMinutes = outcome == FocusEventOutcome.completed ? 25 : 5;
    return FocusEvent(
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: focusedMinutes)),
      plannedDurationSeconds: 25 * 60,
      focusedDurationSeconds: focusedMinutes * 60,
      pauseCount: 0,
      didResume: false,
      outcome: outcome,
      sessionFit: sessionFit,
    );
  }

  FocusForecast forecast(List<FocusEvent> events) =>
      service.createForecast(recentEvents: events, localize: (value) => value);

  test('starts with an honest learning state instead of guessing', () {
    final insight = forecast(const []);

    expect(insight.kind, FocusForecastKind.learning);
    expect(insight.isLearning, isTrue);
    expect(insight.hasPossibleWindow, isFalse);
    expect(insight.signalCount, 0);
    expect(insight.headline, contains('still forming'));
    expect(insight.evidence, contains('No completed'));
  });

  test('interrupted attempts never become weak-time evidence', () {
    final insight = forecast([
      for (var i = 0; i < 10; i++)
        event(startHour: 9, ageDays: i, outcome: FocusEventOutcome.reset),
    ]);

    expect(insight.kind, FocusForecastKind.learning);
    expect(insight.signalCount, 0);
    expect(insight.evidence, contains('No completed'));
  });

  test('requires six completed signals before naming a window', () {
    final insight = forecast([
      event(startHour: 9),
      event(startHour: 9, ageDays: 1),
      event(startHour: 10, ageDays: 2),
      event(startHour: 11, ageDays: 3),
      event(startHour: 14, ageDays: 4),
    ]);

    expect(insight.kind, FocusForecastKind.learning);
    expect(insight.signalCount, 5);
    expect(insight.evidence, contains('at least 6'));
  });

  test('a repeated morning cluster becomes one possible window', () {
    final insight = forecast([
      event(startHour: 9),
      event(startHour: 10, ageDays: 1),
      event(startHour: 11, ageDays: 2),
      event(startHour: 9, ageDays: 3),
      event(startHour: 14, ageDays: 4),
      event(startHour: 18, ageDays: 5),
    ]);

    expect(insight.kind, FocusForecastKind.emergingWindow);
    expect(insight.window, FocusForecastWindow.morning);
    expect(insight.hasPossibleWindow, isTrue);
    expect(insight.signalCount, 6);
    expect(insight.headline, contains('in the morning'));
    expect(insight.detail, contains('not a rule or prediction'));
    expect(insight.evidence, contains('4 of 6'));
    expect(insight.evidence, contains('local time'));
  });

  test('equally repeated windows stay flexible', () {
    final insight = forecast([
      event(startHour: 9),
      event(startHour: 10, ageDays: 1),
      event(startHour: 11, ageDays: 2),
      event(startHour: 18, ageDays: 3),
      event(startHour: 19, ageDays: 4),
      event(startHour: 20, ageDays: 5),
    ]);

    expect(insight.kind, FocusForecastKind.flexible);
    expect(insight.hasPossibleWindow, isFalse);
    expect(insight.signalCount, 6);
    expect(insight.detail, contains('availability should keep leading'));
    expect(insight.evidence, contains('largest window contains 3'));
  });

  test('late-night observations include both sides of midnight', () {
    final insight = forecast([
      event(startHour: 22),
      event(startHour: 23, ageDays: 1),
      event(startHour: 1, ageDays: 2),
      event(startHour: 2, ageDays: 3),
      event(startHour: 9, ageDays: 4),
      event(startHour: 14, ageDays: 5),
    ]);

    expect(insight.window, FocusForecastWindow.lateNight);
    expect(insight.headline, contains('late at night'));
    expect(insight.evidence, contains('between 9 PM and 5 AM'));
  });

  test('historical events are interpreted through local time', () {
    final events = [
      event(startHour: 1),
      event(startHour: 1, ageDays: 1),
      event(startHour: 1, ageDays: 2),
      event(startHour: 1, ageDays: 3),
      event(startHour: 6, ageDays: 4),
      event(startHour: 7, ageDays: 5),
    ];
    final insight = service.createForecast(
      recentEvents: events,
      localize: (value) => value.add(const Duration(hours: 8)),
    );

    expect(insight.window, FocusForecastWindow.morning);
    expect(insight.evidence, contains('between 8 AM and noon'));
  });

  test('only the latest thirty meaningful attempts shape the forecast', () {
    final recent = [
      for (var i = 0; i < 16; i++) event(startHour: 18, ageDays: i),
      for (var i = 16; i < 30; i++) event(startHour: 9, ageDays: i),
    ];
    final older = [
      for (var i = 30; i < 40; i++) event(startHour: 9, ageDays: i),
    ];
    final insight = forecast([...older, ...recent]);

    expect(insight.window, FocusForecastWindow.evening);
    expect(insight.signalCount, 30);
    expect(insight.evidence, contains('16 of 30'));
  });

  test('connects one exact reflection without inventing a forecast', () {
    final current = event(startHour: 9, sessionFit: FocusSessionFit.aboutRight);

    final connection = service.createReflectionConnection(
      completion: current.completionIdentity!,
      recentEvents: [current],
      localize: (value) => value,
    );

    expect(connection, isNotNull);
    expect(connection!.kind, FocusForecastReflectionConnectionKind.learning);
    expect(connection.selectedFit, FocusSessionFit.aboutRight);
    expect(connection.completion, current.completionIdentity);
    expect(connection.forecast.kind, FocusForecastKind.learning);
    expect(connection.headline, contains('does not create'));
  });

  test('explains when the exact completion aligns with a possible window', () {
    final current = event(
      startHour: 9,
      sessionFit: FocusSessionFit.couldDoMore,
    );
    final events = [
      current,
      event(startHour: 9, ageDays: 1),
      event(startHour: 10, ageDays: 2),
      event(startHour: 11, ageDays: 3),
      event(startHour: 14, ageDays: 4),
      event(startHour: 18, ageDays: 5),
    ];

    final connection = service.createReflectionConnection(
      completion: current.completionIdentity!,
      recentEvents: events,
      localize: (value) => value,
    );

    expect(
      connection!.kind,
      FocusForecastReflectionConnectionKind.alignsWithPossibleWindow,
    );
    expect(connection.alignsWithPossibleWindow, isTrue);
    expect(connection.completedWindow, FocusForecastWindow.morning);
    expect(connection.forecast.window, FocusForecastWindow.morning);
    expect(connection.detail, contains('adds context, not proof'));
  });

  test(
    'keeps an out-of-window reflection valid without rewriting forecast',
    () {
      final current = event(startHour: 18, sessionFit: FocusSessionFit.tooMuch);
      final events = [
        current,
        event(startHour: 9, ageDays: 1),
        event(startHour: 9, ageDays: 2),
        event(startHour: 10, ageDays: 3),
        event(startHour: 11, ageDays: 4),
        event(startHour: 14, ageDays: 5),
      ];

      final connection = service.createReflectionConnection(
        completion: current.completionIdentity!,
        recentEvents: events,
        localize: (value) => value,
      );

      expect(
        connection!.kind,
        FocusForecastReflectionConnectionKind.outsidePossibleWindow,
      );
      expect(connection.completedWindow, FocusForecastWindow.evening);
      expect(connection.forecast.window, FocusForecastWindow.morning);
      expect(connection.detail, contains('remains valid'));
    },
  );

  test('keeps mixed completed timing flexible after a reflection', () {
    final current = event(startHour: 9, sessionFit: FocusSessionFit.aboutRight);
    final connection = service.createReflectionConnection(
      completion: current.completionIdentity!,
      recentEvents: [
        current,
        event(startHour: 10, ageDays: 1),
        event(startHour: 11, ageDays: 2),
        event(startHour: 18, ageDays: 3),
        event(startHour: 19, ageDays: 4),
        event(startHour: 20, ageDays: 5),
      ],
      localize: (value) => value,
    );

    expect(
      connection!.kind,
      FocusForecastReflectionConnectionKind.flexibleTiming,
    );
    expect(connection.forecast.kind, FocusForecastKind.flexible);
    expect(connection.detail, contains('does not rank'));
  });

  test('fails closed for unanswered, stale, or duplicate evidence', () {
    final current = event(startHour: 9, sessionFit: FocusSessionFit.aboutRight);
    final older = event(
      startHour: 10,
      ageDays: 1,
      sessionFit: FocusSessionFit.tooMuch,
    );
    final unanswered = event(startHour: 9);

    expect(
      service.createReflectionConnection(
        completion: unanswered.completionIdentity!,
        recentEvents: [unanswered],
      ),
      isNull,
    );
    expect(
      service.createReflectionConnection(
        completion: older.completionIdentity!,
        recentEvents: [older, current],
      ),
      isNull,
    );
    expect(
      service.createReflectionConnection(
        completion: current.completionIdentity!,
        recentEvents: [current, current],
      ),
      isNull,
    );
  });

  test(
    'Riverpod derives the current private forecast from event snapshots',
    () {
      final events = [
        event(startHour: 9, deviceLocal: true),
        event(startHour: 9, ageDays: 1, deviceLocal: true),
        event(startHour: 10, ageDays: 2, deviceLocal: true),
        event(startHour: 11, ageDays: 3, deviceLocal: true),
        event(startHour: 14, ageDays: 4, deviceLocal: true),
        event(startHour: 18, ageDays: 5, deviceLocal: true),
      ];
      final container = ProviderContainer(
        overrides: [timerFocusEventsProvider.overrideWithValue(events)],
      );
      addTearDown(container.dispose);

      final insight = container.read(focusForecastProvider);

      expect(insight.window, FocusForecastWindow.morning);
      expect(insight.signalCount, 6);
    },
  );
}
