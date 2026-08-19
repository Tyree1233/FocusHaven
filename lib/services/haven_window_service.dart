import '../models/focus_forecast.dart';
import '../models/haven_window_suggestion.dart';

/// Finds at most one optional opening from redacted calendar availability.
///
/// The service never receives calendar metadata, creates events, changes the
/// timer, or treats an unavailable forecast window as a personal failure.
class HavenWindowService {
  const HavenWindowService();

  static const _step = Duration(minutes: 5);
  static const _minimumDuration = Duration(minutes: 5);
  static const _maximumDuration = Duration(hours: 2);
  static const _maximumRange = Duration(hours: 36);
  static const _maximumBusyBlocks = 64;

  HavenWindowSuggestion createSuggestion({
    required FocusForecast forecast,
    required PrivateCalendarAvailability availability,
    required DateTime now,
    Duration preferredDuration = const Duration(minutes: 25),
  }) {
    _validatePreferredDuration(preferredDuration);

    switch (availability.status) {
      case PrivateCalendarAvailabilityStatus.unsupported:
        return const HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: 'Calendar availability is unavailable here',
          detail:
              'This device does not currently offer a supported private calendar connection.',
          evidence: 'No calendar availability was read.',
        );
      case PrivateCalendarAvailabilityStatus.disconnected:
        return const HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: 'Calendar availability is not connected',
          detail:
              'FocusHaven will not infer free time until you explicitly connect a supported device calendar.',
          evidence: 'No calendar availability was read.',
        );
      case PrivateCalendarAvailabilityStatus.denied:
        return const HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: 'Calendar access stays off',
          detail:
              'Your choice is respected. FocusHaven can continue without calendar availability.',
          evidence: 'No calendar availability was read.',
        );
      case PrivateCalendarAvailabilityStatus.ready:
        break;
    }

    if (!_isValidAvailability(availability, now)) {
      return const HavenWindowSuggestion(
        kind: HavenWindowKind.unavailable,
        headline: 'Calendar availability is temporarily unavailable',
        detail:
            'The private availability snapshot could not be safely interpreted. Nothing was scheduled or changed.',
        evidence: 'Malformed or oversized availability data was rejected.',
      );
    }

    final forecastWindow = forecast.window;
    if (forecast.kind != FocusForecastKind.emergingWindow ||
        forecastWindow == null) {
      return HavenWindowSuggestion(
        kind: HavenWindowKind.learning,
        headline: 'Your Haven Window is still forming',
        detail:
            'FocusHaven will wait for a clear completed-session pattern instead of turning free calendar time into a recommendation.',
        evidence: forecast.isLearning
            ? 'The private Focus Forecast is still learning.'
            : 'Recent completed focus remains flexible across the day.',
      );
    }

    final rangeStart = availability.rangeStart!;
    final rangeEnd = availability.rangeEnd!;
    final firstFutureMoment = now.add(const Duration(microseconds: 1));
    var candidate = _roundUpToStep(_later(rangeStart, firstFutureMoment));

    while (!candidate.add(preferredDuration).isAfter(rangeEnd)) {
      final candidateEnd = candidate.add(preferredDuration);
      if (_fitsForecastWindow(candidate, candidateEnd, forecastWindow) &&
          !_overlapsBusyBlock(
            candidate,
            candidateEnd,
            availability.busyBlocks,
          )) {
        final minutes = preferredDuration.inMinutes;
        return HavenWindowSuggestion(
          kind: HavenWindowKind.opening,
          headline: 'A possible Haven Window is open',
          detail:
              'This optional opening overlaps a repeated completed-session window. Review it before deciding whether it fits today.',
          evidence:
              'One $minutes-minute opening fits ${_windowLabel(forecastWindow)} using busy-time boundaries only.',
          startsAt: candidate,
          endsAt: candidateEnd,
          forecastWindow: forecastWindow,
        );
      }
      candidate = candidate.add(_step);
    }

    return HavenWindowSuggestion(
      kind: HavenWindowKind.noOpening,
      headline: 'No matching Haven Window appears right now',
      detail:
          'Nothing needs to be forced. Another time, a smaller session, or no session may fit better today.',
      evidence:
          'No ${preferredDuration.inMinutes}-minute opening overlaps ${_windowLabel(forecastWindow)} in the available range.',
      forecastWindow: forecastWindow,
    );
  }

  static void _validatePreferredDuration(Duration duration) {
    if (duration < _minimumDuration ||
        duration > _maximumDuration ||
        duration.inSeconds % _step.inSeconds != 0) {
      throw ArgumentError.value(
        duration,
        'preferredDuration',
        'must be 5 to 120 minutes in five-minute steps',
      );
    }
  }

  static bool _isValidAvailability(
    PrivateCalendarAvailability availability,
    DateTime now,
  ) {
    final start = availability.rangeStart;
    final end = availability.rangeEnd;
    if (start == null ||
        end == null ||
        !start.isBefore(end) ||
        end.difference(start) > _maximumRange ||
        start.isUtc ||
        end.isUtc ||
        now.isUtc ||
        availability.busyBlocks.length > _maximumBusyBlocks) {
      return false;
    }

    for (final block in availability.busyBlocks) {
      if (!block.startsAt.isBefore(block.endsAt) ||
          block.startsAt.isUtc ||
          block.endsAt.isUtc) {
        return false;
      }
    }
    return true;
  }

  static DateTime _roundUpToStep(DateTime value) {
    final stepMicros = _step.inMicroseconds;
    final remainder = value.microsecondsSinceEpoch.remainder(stepMicros);
    return remainder == 0
        ? value
        : value.add(Duration(microseconds: stepMicros - remainder));
  }

  static DateTime _later(DateTime first, DateTime second) =>
      first.isAfter(second) ? first : second;

  static bool _fitsForecastWindow(
    DateTime start,
    DateTime end,
    FocusForecastWindow window,
  ) {
    final finalMoment = end.subtract(const Duration(microseconds: 1));
    return _windowForHour(start.hour) == window &&
        _windowForHour(finalMoment.hour) == window;
  }

  static bool _overlapsBusyBlock(
    DateTime start,
    DateTime end,
    List<CalendarBusyBlock> busyBlocks,
  ) => busyBlocks.any(
    (block) => block.startsAt.isBefore(end) && block.endsAt.isAfter(start),
  );

  static FocusForecastWindow _windowForHour(int hour) {
    if (hour >= 5 && hour < 8) return FocusForecastWindow.earlyMorning;
    if (hour >= 8 && hour < 12) return FocusForecastWindow.morning;
    if (hour >= 12 && hour < 17) return FocusForecastWindow.afternoon;
    if (hour >= 17 && hour < 21) return FocusForecastWindow.evening;
    return FocusForecastWindow.lateNight;
  }

  static String _windowLabel(FocusForecastWindow window) => switch (window) {
    FocusForecastWindow.earlyMorning => 'the early-morning forecast window',
    FocusForecastWindow.morning => 'the morning forecast window',
    FocusForecastWindow.afternoon => 'the afternoon forecast window',
    FocusForecastWindow.evening => 'the evening forecast window',
    FocusForecastWindow.lateNight => 'the late-night forecast window',
  };
}
