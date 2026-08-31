import '../models/focus_event.dart';
import '../models/focus_forecast.dart';

/// Builds one private, explainable timing observation from focus events.
///
/// Only completed focus sessions can support a possible window. Interrupted
/// attempts remain valid recovery signals elsewhere, but are never treated as
/// evidence that a time of day is weak or unsuccessful.
class FocusForecastService {
  const FocusForecastService();

  static const _recentMeaningfulLimit = 30;
  static const _minimumCompletedSignals = 6;
  static const _minimumWindowSignals = 3;
  static const _minimumWindowShare = 0.5;

  FocusForecastReflectionConnection? createReflectionConnection({
    required FocusCompletionIdentity completion,
    required List<FocusEvent> recentEvents,
    DateTime Function(DateTime utcTime)? localize,
  }) {
    final ordered = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    if (ordered.isEmpty || ordered.first.completionIdentity != completion) {
      return null;
    }

    final matches = ordered
        .where((event) => event.completionIdentity == completion)
        .toList(growable: false);
    if (matches.length != 1 || matches.single.sessionFit == null) return null;

    final current = matches.single;
    final toLocal = localize ?? _defaultLocalize;
    final completedWindow = _windowForHour(
      toLocal(current.startedAt.toUtc()).hour,
    );
    final forecast = createForecast(
      recentEvents: recentEvents,
      localize: toLocal,
    );

    final (kind, headline, detail) = switch (forecast.kind) {
      FocusForecastKind.learning => (
        FocusForecastReflectionConnectionKind.learning,
        'One reflection does not create a timing pattern',
        'Focus Forecast is still learning from completed-session timing. Your saved fit adds private context without turning this one session into a prediction.',
      ),
      FocusForecastKind.flexible => (
        FocusForecastReflectionConnectionKind.flexibleTiming,
        'Your timing still looks flexible',
        'Recent completions move across the day. This saved fit does not rank one time above your current energy or real-life availability.',
      ),
      FocusForecastKind.emergingWindow
          when forecast.window == completedWindow =>
        (
          FocusForecastReflectionConnectionKind.alignsWithPossibleWindow,
          'This completion sits inside a possible focus window',
          'Its completed timing already contributes to the local observation. Your saved fit adds context, not proof that this time will always work.',
        ),
      FocusForecastKind.emergingWindow => (
        FocusForecastReflectionConnectionKind.outsidePossibleWindow,
        'One session can sit outside a possible window',
        'Your saved fit remains valid even when this completion happened at another time. Focus Forecast is an observation, not a rule.',
      ),
    };

    return FocusForecastReflectionConnection(
      kind: kind,
      completion: completion,
      selectedFit: current.sessionFit!,
      forecast: forecast,
      completedWindow: completedWindow,
      headline: headline,
      detail: detail,
    );
  }

  FocusForecast createForecast({
    required List<FocusEvent> recentEvents,
    DateTime Function(DateTime utcTime)? localize,
  }) {
    final toLocal = localize ?? _defaultLocalize;
    final sorted = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final meaningful = sorted
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .take(_recentMeaningfulLimit)
        .toList(growable: false);
    final completed = meaningful
        .where((event) => event.wasCompleted)
        .toList(growable: false);

    if (completed.length < _minimumCompletedSignals) {
      return FocusForecast(
        kind: FocusForecastKind.learning,
        headline: 'Your Focus Forecast is still forming',
        detail:
            'Complete a few sessions at the times that naturally fit. FocusHaven will wait for a clear pattern instead of guessing.',
        evidence: completed.isEmpty
            ? 'No completed timing signals are available yet.'
            : '${completed.length} completed timing signal${completed.length == 1 ? '' : 's'} are available; at least $_minimumCompletedSignals are needed.',
        signalCount: completed.length,
      );
    }

    final counts = <FocusForecastWindow, int>{
      for (final window in FocusForecastWindow.values) window: 0,
    };
    for (final event in completed) {
      final localStart = toLocal(event.startedAt.toUtc());
      final window = _windowForHour(localStart.hour);
      counts[window] = counts[window]! + 1;
    }

    final highestCount = counts.values.reduce(
      (highest, count) => count > highest ? count : highest,
    );
    final leaders = counts.entries
        .where((entry) => entry.value == highestCount)
        .map((entry) => entry.key)
        .toList(growable: false);
    final hasDominantWindow =
        leaders.length == 1 &&
        highestCount >= _minimumWindowSignals &&
        highestCount / completed.length >= _minimumWindowShare;

    if (!hasDominantWindow) {
      return FocusForecast(
        kind: FocusForecastKind.flexible,
        headline: 'Your completed focus moves across the day',
        detail:
            'Recent sessions do not gather around one repeated window. Current energy and real-life availability should keep leading.',
        evidence:
            '${completed.length} recent completed sessions are spread across the day; the largest window contains $highestCount.',
        signalCount: completed.length,
      );
    }

    final window = leaders.single;
    return FocusForecast(
      kind: FocusForecastKind.emergingWindow,
      headline: 'Completed focus often begins ${_label(window)}',
      detail:
          'Recent completions have gathered here. Treat this as a possible planning window, not a rule or prediction.',
      evidence:
          '$highestCount of ${completed.length} recent completed sessions began ${_range(window)} in your local time.',
      signalCount: completed.length,
      window: window,
    );
  }

  static FocusForecastWindow _windowForHour(int hour) {
    if (hour >= 5 && hour < 8) return FocusForecastWindow.earlyMorning;
    if (hour >= 8 && hour < 12) return FocusForecastWindow.morning;
    if (hour >= 12 && hour < 17) return FocusForecastWindow.afternoon;
    if (hour >= 17 && hour < 21) return FocusForecastWindow.evening;
    return FocusForecastWindow.lateNight;
  }

  static DateTime _defaultLocalize(DateTime value) => value.toLocal();

  static String _label(FocusForecastWindow window) => switch (window) {
    FocusForecastWindow.earlyMorning => 'early in the morning',
    FocusForecastWindow.morning => 'in the morning',
    FocusForecastWindow.afternoon => 'in the afternoon',
    FocusForecastWindow.evening => 'in the evening',
    FocusForecastWindow.lateNight => 'late at night',
  };

  static String _range(FocusForecastWindow window) => switch (window) {
    FocusForecastWindow.earlyMorning => 'between 5 AM and 8 AM',
    FocusForecastWindow.morning => 'between 8 AM and noon',
    FocusForecastWindow.afternoon => 'between noon and 5 PM',
    FocusForecastWindow.evening => 'between 5 PM and 9 PM',
    FocusForecastWindow.lateNight => 'between 9 PM and 5 AM',
  };
}
