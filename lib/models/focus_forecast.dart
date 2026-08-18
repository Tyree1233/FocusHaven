enum FocusForecastKind { learning, emergingWindow, flexible }

enum FocusForecastWindow {
  earlyMorning,
  morning,
  afternoon,
  evening,
  lateNight,
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
