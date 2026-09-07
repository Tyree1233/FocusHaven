import 'dart:math' as math;

import '../models/adaptive_focus_suggestion.dart';
import '../models/focus_event.dart';
import '../models/focus_forecast.dart';
import '../models/haven_rhythm_insight.dart';

/// Builds one bounded, local-only adaptive preview from text-free signals.
///
/// The service cannot alter a timer, schedule a session, persist a preference,
/// or contact a remote service. An explicit keep-current choice and recovery
/// signals take precedence over learned rhythm or timing observations.
class AdaptiveFocusService {
  const AdaptiveFocusService();

  static const _recentEventLimit = 12;
  static const _recoveryWindow = 3;
  static const _minimumRhythmSignals = 3;
  static const _minimumForecastSignals = 6;
  static const _focusOptions = <int>[5, 10, 15, 25, 45, 60, 90];

  AdaptiveFocusSuggestion? createSuggestion({
    required int currentFocusMinutes,
    required int currentBreakMinutes,
    required bool preserveCurrentChoice,
    required List<FocusEvent> recentEvents,
    required HavenRhythmInsight rhythm,
    required FocusForecast forecast,
  }) {
    if (currentFocusMinutes < 1 ||
        currentFocusMinutes > 180 ||
        currentBreakMinutes < 0 ||
        currentBreakMinutes > 60) {
      return null;
    }

    final possibleWindow = _qualifiedWindow(forecast);
    if (preserveCurrentChoice) {
      return _suggestion(
        currentFocusMinutes: currentFocusMinutes,
        currentBreakMinutes: currentBreakMinutes,
        suggestedFocusMinutes: currentFocusMinutes,
        suggestedBreakMinutes: currentBreakMinutes,
        basis: AdaptiveFocusBasis.explicitChoice,
        relevantSignalCount: 0,
        possibleWindow: possibleWindow,
      );
    }

    final recent = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final meaningful = recent
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .take(_recentEventLimit)
        .toList(growable: false);
    final recoverySignals = meaningful
        .take(_recoveryWindow)
        .where((event) => event.canSupportRecovery)
        .length;
    if (recoverySignals >= 2) {
      final suggestedFocus = _recoveryFocus(currentFocusMinutes);
      final suggestedBreak = math
          .max(currentBreakMinutes, _supportiveBreak(suggestedFocus))
          .clamp(0, 60)
          .toInt();
      return _suggestion(
        currentFocusMinutes: currentFocusMinutes,
        currentBreakMinutes: currentBreakMinutes,
        suggestedFocusMinutes: suggestedFocus,
        suggestedBreakMinutes: suggestedBreak,
        basis: AdaptiveFocusBasis.recoveryPriority,
        relevantSignalCount: recoverySignals,
        usesRecoveryPattern: true,
        possibleWindow: possibleWindow,
      );
    }

    final latestReflection = _latestReflection(meaningful);
    if (latestReflection != null) {
      return switch (latestReflection.sessionFit!) {
        FocusSessionFit.tooMuch => _gentlerFromReflection(
          currentFocusMinutes: currentFocusMinutes,
          currentBreakMinutes: currentBreakMinutes,
          event: latestReflection,
          possibleWindow: possibleWindow,
        ),
        FocusSessionFit.aboutRight => _suggestion(
          currentFocusMinutes: currentFocusMinutes,
          currentBreakMinutes: currentBreakMinutes,
          suggestedFocusMinutes: currentFocusMinutes,
          suggestedBreakMinutes: currentBreakMinutes,
          basis: AdaptiveFocusBasis.latestReflection,
          relevantSignalCount: 1,
          usesLatestReflection: true,
          possibleWindow: possibleWindow,
        ),
        FocusSessionFit.couldDoMore => _growthAfterReflection(
          currentFocusMinutes: currentFocusMinutes,
          currentBreakMinutes: currentBreakMinutes,
          rhythm: rhythm,
          possibleWindow: possibleWindow,
        ),
      };
    }

    if (_isQualifiedRhythm(rhythm)) {
      final target = rhythm.suggestedFocusMinutes;
      final suggestedFocus = switch (rhythm.kind) {
        HavenRhythmKind.gentleReturn || HavenRhythmKind.gentlerPace =>
          _gentlerToward(currentFocusMinutes, target),
        HavenRhythmKind.sustainablePace => _oneStepToward(
          currentFocusMinutes,
          target,
        ),
        HavenRhythmKind.roomToGrow => _oneStepUpToward(
          currentFocusMinutes,
          target,
        ),
        HavenRhythmKind.learning ||
        HavenRhythmKind.variablePace ||
        HavenRhythmKind.completionPattern => currentFocusMinutes,
      };
      final recoveryLed = rhythm.kind == HavenRhythmKind.gentleReturn;
      final suggestedBreak = recoveryLed
          ? math
                .max(currentBreakMinutes, _supportiveBreak(suggestedFocus))
                .clamp(0, 60)
                .toInt()
          : currentBreakMinutes;
      return _suggestion(
        currentFocusMinutes: currentFocusMinutes,
        currentBreakMinutes: currentBreakMinutes,
        suggestedFocusMinutes: suggestedFocus,
        suggestedBreakMinutes: suggestedBreak,
        basis: recoveryLed
            ? AdaptiveFocusBasis.recoveryPriority
            : AdaptiveFocusBasis.repeatedRhythm,
        relevantSignalCount: rhythm.signalCount,
        usesRecoveryPattern: recoveryLed,
        usesRepeatedRhythm: true,
        possibleWindow: possibleWindow,
      );
    }

    return _suggestion(
      currentFocusMinutes: currentFocusMinutes,
      currentBreakMinutes: currentBreakMinutes,
      suggestedFocusMinutes: currentFocusMinutes,
      suggestedBreakMinutes: currentBreakMinutes,
      basis: AdaptiveFocusBasis.currentBaseline,
      relevantSignalCount: 0,
      possibleWindow: possibleWindow,
    );
  }

  AdaptiveFocusSuggestion _gentlerFromReflection({
    required int currentFocusMinutes,
    required int currentBreakMinutes,
    required FocusEvent event,
    required FocusForecastWindow? possibleWindow,
  }) {
    final reflectedMinutes = (event.focusedDurationSeconds ~/ 60)
        .clamp(1, 180)
        .toInt();
    final baseline = math.min(currentFocusMinutes, reflectedMinutes);
    final suggestedFocus = _previousOption(baseline, currentFocusMinutes);
    final suggestedBreak = math
        .max(currentBreakMinutes, _supportiveBreak(suggestedFocus))
        .clamp(0, 60)
        .toInt();
    return _suggestion(
      currentFocusMinutes: currentFocusMinutes,
      currentBreakMinutes: currentBreakMinutes,
      suggestedFocusMinutes: suggestedFocus,
      suggestedBreakMinutes: suggestedBreak,
      basis: AdaptiveFocusBasis.latestReflection,
      relevantSignalCount: 1,
      usesLatestReflection: true,
      possibleWindow: possibleWindow,
    );
  }

  AdaptiveFocusSuggestion _growthAfterReflection({
    required int currentFocusMinutes,
    required int currentBreakMinutes,
    required HavenRhythmInsight rhythm,
    required FocusForecastWindow? possibleWindow,
  }) {
    final canGrow =
        rhythm.kind == HavenRhythmKind.roomToGrow && _isQualifiedRhythm(rhythm);
    final suggestedFocus = canGrow
        ? _oneStepUpToward(currentFocusMinutes, rhythm.suggestedFocusMinutes)
        : currentFocusMinutes;
    return _suggestion(
      currentFocusMinutes: currentFocusMinutes,
      currentBreakMinutes: currentBreakMinutes,
      suggestedFocusMinutes: suggestedFocus,
      suggestedBreakMinutes: currentBreakMinutes,
      basis: canGrow
          ? AdaptiveFocusBasis.repeatedRhythm
          : AdaptiveFocusBasis.latestReflection,
      relevantSignalCount: canGrow ? rhythm.signalCount + 1 : 1,
      usesLatestReflection: true,
      usesRepeatedRhythm: canGrow,
      possibleWindow: possibleWindow,
    );
  }

  AdaptiveFocusSuggestion _suggestion({
    required int currentFocusMinutes,
    required int currentBreakMinutes,
    required int suggestedFocusMinutes,
    required int suggestedBreakMinutes,
    required AdaptiveFocusBasis basis,
    required int relevantSignalCount,
    bool usesRecoveryPattern = false,
    bool usesLatestReflection = false,
    bool usesRepeatedRhythm = false,
    required FocusForecastWindow? possibleWindow,
  }) {
    final usesForecast = possibleWindow != null;
    final supportingSources = <bool>[
      usesRecoveryPattern,
      usesLatestReflection,
      usesRepeatedRhythm,
      usesForecast,
    ].where((value) => value).length;
    final evidenceStrength = supportingSources >= 2
        ? AdaptiveFocusEvidenceStrength.reinforced
        : usesRecoveryPattern || usesRepeatedRhythm
        ? AdaptiveFocusEvidenceStrength.supported
        : AdaptiveFocusEvidenceStrength.limited;
    return AdaptiveFocusSuggestion(
      currentFocusMinutes: currentFocusMinutes,
      currentBreakMinutes: currentBreakMinutes,
      suggestedFocusMinutes: suggestedFocusMinutes,
      suggestedBreakMinutes: suggestedBreakMinutes,
      direction: suggestedFocusMinutes < currentFocusMinutes
          ? AdaptiveFocusDirection.gentler
          : suggestedFocusMinutes > currentFocusMinutes
          ? AdaptiveFocusDirection.roomToGrow
          : AdaptiveFocusDirection.keepCurrent,
      breakDirection: suggestedBreakMinutes > currentBreakMinutes
          ? AdaptiveFocusBreakDirection.moreRecovery
          : AdaptiveFocusBreakDirection.keepCurrent,
      basis: basis,
      evidenceStrength: evidenceStrength,
      relevantSignalCount: relevantSignalCount,
      usesRecoveryPattern: usesRecoveryPattern,
      usesLatestReflection: usesLatestReflection,
      usesRepeatedRhythm: usesRepeatedRhythm,
      usesForecast: usesForecast,
      possibleWindow: possibleWindow,
    );
  }

  static FocusEvent? _latestReflection(List<FocusEvent> recentEvents) {
    for (final event in recentEvents) {
      if (event.wasCompleted && event.sessionFit != null) return event;
    }
    return null;
  }

  static bool _isQualifiedRhythm(HavenRhythmInsight rhythm) =>
      rhythm.signalCount >= _minimumRhythmSignals &&
      rhythm.suggestedFocusMinutes != null &&
      rhythm.kind != HavenRhythmKind.learning &&
      rhythm.kind != HavenRhythmKind.variablePace &&
      rhythm.kind != HavenRhythmKind.completionPattern;

  static FocusForecastWindow? _qualifiedWindow(FocusForecast forecast) =>
      forecast.kind == FocusForecastKind.emergingWindow &&
          forecast.signalCount >= _minimumForecastSignals
      ? forecast.window
      : null;

  static int _recoveryFocus(int current) {
    if (current <= _focusOptions.first) return current;
    return _focusOptions.lastWhere(
      (minutes) => minutes <= math.min(current, 10),
      orElse: () => _focusOptions.first,
    );
  }

  static int _gentlerToward(int current, int? target) {
    if (target == null || target >= current) return current;
    return _focusOptions.lastWhere(
      (minutes) => minutes <= target && minutes < current,
      orElse: () =>
          _focusOptions.first < current ? _focusOptions.first : current,
    );
  }

  static int _previousOption(int baseline, int current) {
    final candidates = _focusOptions
        .where((minutes) => minutes < baseline && minutes < current)
        .toList(growable: false);
    return candidates.isEmpty ? current : candidates.last;
  }

  static int _oneStepUpToward(int current, int? target) {
    if (target == null || target <= current) return current;
    for (final option in _focusOptions) {
      if (option > current && option <= target) return option;
    }
    return current;
  }

  static int _oneStepToward(int current, int? target) {
    if (target == null || target == current) return current;
    if (target > current) return _oneStepUpToward(current, target);
    return _gentlerToward(current, target);
  }

  static int _supportiveBreak(int focusMinutes) {
    if (focusMinutes <= 10) return 5;
    if (focusMinutes <= 25) return 5;
    if (focusMinutes <= 60) return 10;
    return 15;
  }
}
