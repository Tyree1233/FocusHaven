import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/models/haven_window_suggestion.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_window_service.dart';

void main() {
  const service = HavenWindowService();
  final day = DateTime(2026, 8, 18);

  FocusForecast forecast({
    FocusForecastKind kind = FocusForecastKind.emergingWindow,
    FocusForecastWindow? window = FocusForecastWindow.morning,
  }) => FocusForecast(
    kind: kind,
    headline: 'Forecast for ${kind.name}',
    detail: 'Cautious detail.',
    evidence: 'Private timing evidence.',
    signalCount: kind == FocusForecastKind.learning ? 0 : 6,
    window: window,
  );

  PrivateCalendarAvailability availability({
    DateTime? start,
    DateTime? end,
    List<CalendarBusyBlock> busy = const [],
  }) => PrivateCalendarAvailability(
    status: PrivateCalendarAvailabilityStatus.ready,
    rangeStart: start ?? day.add(const Duration(hours: 8)),
    rangeEnd: end ?? day.add(const Duration(hours: 12)),
    busyBlocks: busy,
  );

  test('defaults to disconnected without reading calendar availability', () {
    const snapshot = PrivateCalendarAvailability(
      status: PrivateCalendarAvailabilityStatus.disconnected,
    );
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: snapshot,
      now: day,
    );

    expect(suggestion.kind, HavenWindowKind.unavailable);
    expect(suggestion.hasOpening, isFalse);
    expect(suggestion.headline, contains('not connected'));
    expect(suggestion.evidence, 'No calendar availability was read.');
  });

  test('respects denied access without framing it as an error', () {
    const snapshot = PrivateCalendarAvailability(
      status: PrivateCalendarAvailabilityStatus.denied,
    );
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: snapshot,
      now: day,
    );

    expect(suggestion.kind, HavenWindowKind.unavailable);
    expect(suggestion.headline, contains('stays off'));
    expect(suggestion.detail, contains('choice is respected'));
  });

  test('free time alone never invents a forecast recommendation', () {
    final suggestion = service.createSuggestion(
      forecast: forecast(kind: FocusForecastKind.learning, window: null),
      availability: availability(),
      now: day.add(const Duration(hours: 8)),
    );

    expect(suggestion.kind, HavenWindowKind.learning);
    expect(suggestion.hasOpening, isFalse);
    expect(suggestion.evidence, contains('still learning'));
  });

  test('finds one forecast-aligned opening around unsorted busy blocks', () {
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: availability(
        busy: [
          CalendarBusyBlock(
            startsAt: day.add(const Duration(hours: 9, minutes: 30)),
            endsAt: day.add(const Duration(hours: 10)),
          ),
          CalendarBusyBlock(
            startsAt: day.add(const Duration(hours: 8)),
            endsAt: day.add(const Duration(hours: 9)),
          ),
        ],
      ),
      now: day.add(const Duration(hours: 8, minutes: 2)),
    );

    expect(suggestion.kind, HavenWindowKind.opening);
    expect(suggestion.hasOpening, isTrue);
    expect(suggestion.startsAt, day.add(const Duration(hours: 9)));
    expect(suggestion.endsAt, day.add(const Duration(hours: 9, minutes: 25)));
    expect(suggestion.forecastWindow, FocusForecastWindow.morning);
    expect(suggestion.evidence, contains('busy-time boundaries only'));
  });

  test('adjacent busy boundaries do not erase a valid opening', () {
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: availability(
        busy: [
          CalendarBusyBlock(
            startsAt: day.add(const Duration(hours: 8)),
            endsAt: day.add(const Duration(hours: 9)),
          ),
          CalendarBusyBlock(
            startsAt: day.add(const Duration(hours: 9, minutes: 25)),
            endsAt: day.add(const Duration(hours: 10)),
          ),
        ],
      ),
      now: day.add(const Duration(hours: 8)),
    );

    expect(suggestion.startsAt, day.add(const Duration(hours: 9)));
    expect(suggestion.endsAt, day.add(const Duration(hours: 9, minutes: 25)));
  });

  test('never lets a candidate cross out of the forecast window', () {
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: availability(
        start: day.add(const Duration(hours: 11, minutes: 50)),
        end: day.add(const Duration(hours: 12, minutes: 30)),
      ),
      now: day.add(const Duration(hours: 11, minutes: 50)),
    );

    expect(suggestion.kind, HavenWindowKind.noOpening);
    expect(suggestion.hasOpening, isFalse);
    expect(suggestion.detail, contains('Nothing needs to be forced'));
  });

  test('late-night openings can continue safely across midnight', () {
    final start = day.add(const Duration(hours: 23, minutes: 40));
    final suggestion = service.createSuggestion(
      forecast: forecast(window: FocusForecastWindow.lateNight),
      availability: availability(
        start: start,
        end: day.add(const Duration(days: 1, hours: 1)),
      ),
      now: start,
    );

    expect(suggestion.kind, HavenWindowKind.opening);
    expect(suggestion.startsAt, start);
    expect(suggestion.endsAt, day.add(const Duration(days: 1, minutes: 5)));
  });

  test('malformed and oversized snapshots fail closed', () {
    final malformed = availability(
      start: day.add(const Duration(hours: 12)),
      end: day.add(const Duration(hours: 8)),
    );
    final oversized = availability(end: day.add(const Duration(days: 2)));

    for (final snapshot in [malformed, oversized]) {
      final suggestion = service.createSuggestion(
        forecast: forecast(),
        availability: snapshot,
        now: day,
      );

      expect(suggestion.kind, HavenWindowKind.unavailable);
      expect(suggestion.evidence, contains('rejected'));
    }
  });

  test('UTC calendar boundaries are rejected instead of misranked', () {
    final snapshot = PrivateCalendarAvailability(
      status: PrivateCalendarAvailabilityStatus.ready,
      rangeStart: DateTime.utc(2026, 8, 18, 8),
      rangeEnd: DateTime.utc(2026, 8, 18, 12),
    );
    final suggestion = service.createSuggestion(
      forecast: forecast(),
      availability: snapshot,
      now: day,
    );

    expect(suggestion.kind, HavenWindowKind.unavailable);
    expect(suggestion.hasOpening, isFalse);
  });

  test('preferred durations stay bounded to five-minute steps', () {
    for (final duration in [
      const Duration(minutes: 4),
      const Duration(minutes: 26),
      const Duration(minutes: 125),
    ]) {
      expect(
        () => service.createSuggestion(
          forecast: forecast(),
          availability: availability(),
          now: day,
          preferredDuration: duration,
        ),
        throwsArgumentError,
      );
    }
  });

  test('Riverpod composes one opening from narrow private snapshots', () {
    final snapshot = availability();
    final container = ProviderContainer(
      overrides: [
        focusForecastProvider.overrideWithValue(forecast()),
        privateCalendarAvailabilityProvider.overrideWithValue(snapshot),
        havenWindowCurrentTimeProvider.overrideWithValue(
          day.add(const Duration(hours: 8)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final suggestion = container.read(havenWindowSuggestionProvider);

    expect(suggestion.kind, HavenWindowKind.opening);
    expect(suggestion.startsAt, day.add(const Duration(hours: 8)));
    expect(suggestion.hasOpening, isTrue);
  });
}
