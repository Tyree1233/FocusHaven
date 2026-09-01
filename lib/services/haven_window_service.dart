import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
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
  static const _maximumSnapshotAge = Duration(minutes: 15);
  static const _maximumBusyBlocks = 64;

  HavenWindowSuggestion createSuggestion({
    required FocusForecast forecast,
    required PrivateCalendarAvailability availability,
    required DateTime now,
    Duration preferredDuration = const Duration(minutes: 25),
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    _validatePreferredDuration(preferredDuration, l10n);

    switch (availability.status) {
      case PrivateCalendarAvailabilityStatus.unsupported:
        return HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: l10n.havenWindowUnsupportedHeadline,
          detail: l10n.havenWindowUnsupportedDetail,
          evidence: l10n.havenWindowNoAvailabilityEvidence,
        );
      case PrivateCalendarAvailabilityStatus.disconnected:
        return HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: l10n.havenWindowDisconnectedHeadline,
          detail: l10n.havenWindowDisconnectedDetail,
          evidence: l10n.havenWindowNoAvailabilityEvidence,
        );
      case PrivateCalendarAvailabilityStatus.denied:
        return HavenWindowSuggestion(
          kind: HavenWindowKind.unavailable,
          headline: l10n.havenWindowDeniedHeadline,
          detail: l10n.havenWindowDeniedDetail,
          evidence: l10n.havenWindowNoAvailabilityEvidence,
        );
      case PrivateCalendarAvailabilityStatus.ready:
        break;
    }

    if (!_isValidAvailability(availability, now)) {
      return HavenWindowSuggestion(
        kind: HavenWindowKind.unavailable,
        headline: l10n.havenWindowInvalidHeadline,
        detail: l10n.havenWindowInvalidDetail,
        evidence: l10n.havenWindowInvalidEvidence,
      );
    }

    final rangeStart = availability.rangeStart!;
    final rangeEnd = availability.rangeEnd!;
    if (now.isBefore(rangeStart) ||
        now.difference(rangeStart) > _maximumSnapshotAge ||
        !rangeEnd.isAfter(now)) {
      return HavenWindowSuggestion(
        kind: HavenWindowKind.unavailable,
        headline: l10n.havenWindowStaleHeadline,
        detail: l10n.havenWindowStaleDetail,
        evidence: l10n.havenWindowStaleEvidence,
      );
    }

    final forecastWindow = forecast.window;
    if (forecast.kind != FocusForecastKind.emergingWindow ||
        forecastWindow == null) {
      return HavenWindowSuggestion(
        kind: HavenWindowKind.learning,
        headline: l10n.havenWindowLearningHeadline,
        detail: l10n.havenWindowLearningDetail,
        evidence: forecast.isLearning
            ? l10n.havenWindowForecastLearningEvidence
            : l10n.havenWindowForecastFlexibleEvidence,
      );
    }

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
          headline: l10n.havenWindowOpeningHeadline,
          detail: l10n.havenWindowOpeningDetail,
          evidence: l10n.havenWindowOpeningEvidence(
            minutes,
            _windowLabel(forecastWindow, l10n),
          ),
          startsAt: candidate,
          endsAt: candidateEnd,
          forecastWindow: forecastWindow,
        );
      }
      candidate = candidate.add(_step);
    }

    return HavenWindowSuggestion(
      kind: HavenWindowKind.noOpening,
      headline: l10n.havenWindowNoOpeningHeadline,
      detail: l10n.havenWindowNoOpeningDetail,
      evidence: l10n.havenWindowNoOpeningEvidence(
        preferredDuration.inMinutes,
        _windowLabel(forecastWindow, l10n),
      ),
      forecastWindow: forecastWindow,
    );
  }

  static void _validatePreferredDuration(
    Duration duration,
    AppLocalizations l10n,
  ) {
    if (duration < _minimumDuration ||
        duration > _maximumDuration ||
        duration.inSeconds % _step.inSeconds != 0) {
      throw ArgumentError.value(
        duration,
        'preferredDuration',
        l10n.havenWindowInvalidPreferredDuration,
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
          block.endsAt.isUtc ||
          block.startsAt.isBefore(start) ||
          block.endsAt.isAfter(end)) {
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

  static String _windowLabel(
    FocusForecastWindow window,
    AppLocalizations l10n,
  ) => switch (window) {
    FocusForecastWindow.earlyMorning => l10n.havenWindowEarlyMorningLabel,
    FocusForecastWindow.morning => l10n.havenWindowMorningLabel,
    FocusForecastWindow.afternoon => l10n.havenWindowAfternoonLabel,
    FocusForecastWindow.evening => l10n.havenWindowEveningLabel,
    FocusForecastWindow.lateNight => l10n.havenWindowLateNightLabel,
  };
}
