import 'focus_event.dart';

enum FocusForecastKind { learning, emergingWindow, flexible }

enum FocusForecastWindow {
  earlyMorning,
  morning,
  afternoon,
  evening,
  lateNight,
}

enum FocusForecastReflectionConnectionKind {
  learning,
  alignsWithPossibleWindow,
  outsidePossibleWindow,
  flexibleTiming,
}

/// One cautious, local interpretation of completed-session timing.
///
/// A forecast is an observation rather than a promise, performance score, or
/// schedule. It contains no task text, account identity, mood, or journal data.
class FocusForecast {
  const FocusForecast({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.evidence,
    required this.signalCount,
    this.window,
  });

  final FocusForecastKind kind;
  final String headline;
  final String detail;
  final String evidence;
  final int signalCount;
  final FocusForecastWindow? window;

  bool get isLearning => kind == FocusForecastKind.learning;
  bool get hasPossibleWindow => window != null;
}

/// One ephemeral explanation of how an exact saved session-fit reflection
/// relates to the current local Focus Forecast.
///
/// The reflection adds context to the completion that Forecast already sees;
/// it never becomes a score, changes the forecast rules, or controls a timer.
class FocusForecastReflectionConnection {
  const FocusForecastReflectionConnection({
    required this.kind,
    required this.completion,
    required this.selectedFit,
    required this.forecast,
    required this.completedWindow,
    required this.headline,
    required this.detail,
  });

  final FocusForecastReflectionConnectionKind kind;
  final FocusCompletionIdentity completion;
  final FocusSessionFit selectedFit;
  final FocusForecast forecast;
  final FocusForecastWindow completedWindow;
  final String headline;
  final String detail;

  bool get alignsWithPossibleWindow =>
      kind == FocusForecastReflectionConnectionKind.alignsWithPossibleWindow;
}
