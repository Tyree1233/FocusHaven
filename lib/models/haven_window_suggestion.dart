import 'focus_forecast.dart';

enum PrivateCalendarAvailabilityStatus { disconnected, denied, ready }

enum HavenWindowKind { unavailable, learning, opening, noOpening }

/// One calendar-busy boundary without a title, calendar, person, or note.
class CalendarBusyBlock {
  const CalendarBusyBlock({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;
}

/// A bounded, ephemeral availability snapshot from a future native adapter.
///
/// All timestamps use device-local civil time so they align with the private
/// Focus Forecast. The snapshot carries only busy boundaries; event content
/// and calendar identities cannot enter this contract.
class PrivateCalendarAvailability {
  const PrivateCalendarAvailability({
    required this.status,
    this.rangeStart,
    this.rangeEnd,
    this.busyBlocks = const [],
  });

  final PrivateCalendarAvailabilityStatus status;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<CalendarBusyBlock> busyBlocks;
}

/// One optional, user-controlled opening aligned with a cautious forecast.
///
/// This is not a booking, success prediction, performance score, or command.
class HavenWindowSuggestion {
  const HavenWindowSuggestion({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.evidence,
    this.startsAt,
    this.endsAt,
    this.forecastWindow,
  });

  final HavenWindowKind kind;
  final String headline;
  final String detail;
  final String evidence;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final FocusForecastWindow? forecastWindow;

  bool get hasOpening =>
      kind == HavenWindowKind.opening && startsAt != null && endsAt != null;
}
