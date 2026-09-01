import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
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
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
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
      localizations: l10n,
    );

    final (kind, headline, detail) = switch (forecast.kind) {
      FocusForecastKind.learning => (
        FocusForecastReflectionConnectionKind.learning,
        l10n.focusForecastConnectionLearningHeadline,
        l10n.focusForecastConnectionLearningDetail,
      ),
      FocusForecastKind.flexible => (
        FocusForecastReflectionConnectionKind.flexibleTiming,
        l10n.focusForecastConnectionFlexibleHeadline,
        l10n.focusForecastConnectionFlexibleDetail,
      ),
      FocusForecastKind.emergingWindow
          when forecast.window == completedWindow =>
        (
          FocusForecastReflectionConnectionKind.alignsWithPossibleWindow,
          l10n.focusForecastConnectionInsideHeadline,
          l10n.focusForecastConnectionInsideDetail,
        ),
      FocusForecastKind.emergingWindow => (
        FocusForecastReflectionConnectionKind.outsidePossibleWindow,
        l10n.focusForecastConnectionOutsideHeadline,
        l10n.focusForecastConnectionOutsideDetail,
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
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
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
        headline: l10n.focusForecastLearningHeadline,
        detail: l10n.focusForecastLearningDetail,
        evidence: completed.isEmpty
            ? l10n.focusForecastLearningNoEvidence
            : l10n.focusForecastLearningEvidence(
                completed.length,
                _minimumCompletedSignals,
              ),
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
        headline: l10n.focusForecastFlexibleHeadline,
        detail: l10n.focusForecastFlexibleDetail,
        evidence: l10n.focusForecastFlexibleEvidence(
          completed.length,
          highestCount,
        ),
        signalCount: completed.length,
      );
    }

    final window = leaders.single;
    return FocusForecast(
      kind: FocusForecastKind.emergingWindow,
      headline: l10n.focusForecastEmergingHeadline(_label(window, l10n)),
      detail: l10n.focusForecastEmergingDetail,
      evidence: l10n.focusForecastEmergingEvidence(
        highestCount,
        completed.length,
        _range(window, l10n),
      ),
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

  static String _label(FocusForecastWindow window, AppLocalizations l10n) =>
      switch (window) {
        FocusForecastWindow.earlyMorning => l10n.focusForecastEarlyMorningLabel,
        FocusForecastWindow.morning => l10n.focusForecastMorningLabel,
        FocusForecastWindow.afternoon => l10n.focusForecastAfternoonLabel,
        FocusForecastWindow.evening => l10n.focusForecastEveningLabel,
        FocusForecastWindow.lateNight => l10n.focusForecastLateNightLabel,
      };

  static String _range(FocusForecastWindow window, AppLocalizations l10n) =>
      switch (window) {
        FocusForecastWindow.earlyMorning => l10n.focusForecastEarlyMorningRange,
        FocusForecastWindow.morning => l10n.focusForecastMorningRange,
        FocusForecastWindow.afternoon => l10n.focusForecastAfternoonRange,
        FocusForecastWindow.evening => l10n.focusForecastEveningRange,
        FocusForecastWindow.lateNight => l10n.focusForecastLateNightRange,
      };
}
