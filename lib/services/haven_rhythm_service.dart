import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/focus_event.dart';
import '../models/haven_rhythm_insight.dart';

/// Builds one calm, explainable insight from bounded private focus events.
///
/// The engine is deterministic and local. It deliberately requires repeated
/// signals before describing a pattern, and it reports mixed feedback instead
/// of forcing a false conclusion.
class HavenRhythmService {
  const HavenRhythmService();

  static const _recentEventLimit = 12;
  static const _reflectionLimit = 5;
  static const _minimumPatternSignals = 3;
  static const _focusOptions = <int>[5, 10, 15, 25, 45, 60, 90];

  HavenRhythmReflectionConnection? createReflectionConnection({
    required FocusCompletionIdentity completion,
    required List<FocusEvent> recentEvents,
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

    final selectedFit = matches.single.sessionFit!;
    final insight = createInsight(
      recentEvents: recentEvents,
      localizations: l10n,
    );
    final kind = switch (insight.kind) {
      HavenRhythmKind.gentlerPace ||
      HavenRhythmKind.sustainablePace ||
      HavenRhythmKind.roomToGrow ||
      HavenRhythmKind.variablePace =>
        HavenRhythmReflectionConnectionKind.reflectionPattern,
      HavenRhythmKind.gentleReturn =>
        HavenRhythmReflectionConnectionKind.recoveryLeads,
      HavenRhythmKind.learning || HavenRhythmKind.completionPattern =>
        HavenRhythmReflectionConnectionKind.learning,
    };

    final (headline, detail) = switch (kind) {
      HavenRhythmReflectionConnectionKind.learning => (
        l10n.havenRhythmConnectionLearningHeadline,
        l10n.havenRhythmConnectionLearningDetail,
      ),
      HavenRhythmReflectionConnectionKind.reflectionPattern => (
        l10n.havenRhythmConnectionPatternHeadline,
        l10n.havenRhythmConnectionPatternDetail(insight.headline),
      ),
      HavenRhythmReflectionConnectionKind.recoveryLeads => (
        l10n.havenRhythmConnectionRecoveryHeadline,
        l10n.havenRhythmConnectionRecoveryDetail,
      ),
    };

    return HavenRhythmReflectionConnection(
      kind: kind,
      completion: completion,
      selectedFit: selectedFit,
      insight: insight,
      headline: headline,
      detail: detail,
    );
  }

  HavenRhythmInsight createInsight({
    required List<FocusEvent> recentEvents,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    final recent = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final bounded = recent.take(_recentEventLimit).toList(growable: false);
    final meaningful = bounded
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .toList(growable: false);

    final latestMeaningful = meaningful.take(3).toList(growable: false);
    final recoverySignals = latestMeaningful
        .where((event) => event.canSupportRecovery)
        .length;
    if (latestMeaningful.length >= 2 && recoverySignals >= 2) {
      return HavenRhythmInsight(
        kind: HavenRhythmKind.gentleReturn,
        headline: l10n.havenRhythmGentleReturnHeadline,
        detail: l10n.havenRhythmGentleReturnDetail,
        evidence: l10n.havenRhythmGentleReturnEvidence(
          recoverySignals,
          latestMeaningful.length,
        ),
        signalCount: latestMeaningful.length,
        usesSessionReflections: false,
        suggestedFocusMinutes: 10,
      );
    }

    final reflected = meaningful
        .where((event) => event.wasCompleted && event.sessionFit != null)
        .take(_reflectionLimit)
        .toList(growable: false);
    if (reflected.isNotEmpty) {
      final counts = <FocusSessionFit, int>{
        for (final fit in FocusSessionFit.values) fit: 0,
      };
      for (final event in reflected) {
        final fit = event.sessionFit!;
        counts[fit] = counts[fit]! + 1;
      }
      final highestCount = counts.values.reduce(
        (highest, count) => count > highest ? count : highest,
      );
      final leaders = counts.entries
          .where((entry) => entry.value == highestCount && entry.value > 0)
          .map((entry) => entry.key)
          .toList(growable: false);

      if (highestCount >= 2 && leaders.length == 1) {
        final leadingFit = leaders.single;
        final matchingDurations = reflected
            .where((event) => event.sessionFit == leadingFit)
            .map(
              (event) =>
                  (event.focusedDurationSeconds ~/ 60).clamp(1, 90).toInt(),
            )
            .toList(growable: false);
        final center = _median(matchingDurations);
        return switch (leadingFit) {
          FocusSessionFit.tooMuch => HavenRhythmInsight(
            kind: HavenRhythmKind.gentlerPace,
            headline: l10n.havenRhythmGentlerPaceHeadline,
            detail: l10n.havenRhythmGentlerPaceDetail,
            evidence: l10n.havenRhythmGentlerPaceEvidence(
              highestCount,
              reflected.length,
            ),
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _previousFocusOption(center),
          ),
          FocusSessionFit.aboutRight => HavenRhythmInsight(
            kind: HavenRhythmKind.sustainablePace,
            headline: l10n.havenRhythmSustainablePaceHeadline(
              _nearestFocusOption(center),
            ),
            detail: l10n.havenRhythmSustainablePaceDetail,
            evidence: l10n.havenRhythmSustainablePaceEvidence(
              highestCount,
              reflected.length,
            ),
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _nearestFocusOption(center),
          ),
          FocusSessionFit.couldDoMore => HavenRhythmInsight(
            kind: HavenRhythmKind.roomToGrow,
            headline: l10n.havenRhythmRoomToGrowHeadline,
            detail: l10n.havenRhythmRoomToGrowDetail,
            evidence: l10n.havenRhythmRoomToGrowEvidence(
              highestCount,
              reflected.length,
            ),
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _nextFocusOption(center),
          ),
        };
      }

      if (reflected.length >= _minimumPatternSignals) {
        return HavenRhythmInsight(
          kind: HavenRhythmKind.variablePace,
          headline: l10n.havenRhythmVariablePaceHeadline,
          detail: l10n.havenRhythmVariablePaceDetail,
          evidence: l10n.havenRhythmVariablePaceEvidence(reflected.length),
          signalCount: reflected.length,
          usesSessionReflections: true,
        );
      }
    }

    final completedDurations = meaningful
        .where((event) => event.wasCompleted)
        .map((event) => event.focusedDurationSeconds ~/ 60)
        .where((minutes) => minutes >= 5 && minutes <= 90)
        .take(8)
        .toList(growable: false);
    if (completedDurations.length >= _minimumPatternSignals) {
      final pace = _nearestFocusOption(_median(completedDurations));
      return HavenRhythmInsight(
        kind: HavenRhythmKind.completionPattern,
        headline: l10n.havenRhythmCompletionPatternHeadline,
        detail: l10n.havenRhythmCompletionPatternDetail(pace),
        evidence: l10n.havenRhythmCompletionPatternEvidence(
          completedDurations.length,
        ),
        signalCount: completedDurations.length,
        usesSessionReflections: false,
        suggestedFocusMinutes: pace,
      );
    }

    return HavenRhythmInsight(
      kind: HavenRhythmKind.learning,
      headline: l10n.havenRhythmLearningHeadline,
      detail: l10n.havenRhythmLearningDetail,
      evidence: meaningful.isEmpty
          ? l10n.havenRhythmLearningNoEvidence
          : l10n.havenRhythmLearningEvidence(meaningful.length),
      signalCount: meaningful.length,
      usesSessionReflections: reflected.isNotEmpty,
    );
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  static int _nearestFocusOption(int minutes) => _focusOptions.reduce(
    (best, candidate) =>
        (candidate - minutes).abs() < (best - minutes).abs() ? candidate : best,
  );

  static int _previousFocusOption(int minutes) => _focusOptions.lastWhere(
    (option) => option < minutes,
    orElse: () => _focusOptions.first,
  );

  static int _nextFocusOption(int minutes) => _focusOptions.firstWhere(
    (option) => option > minutes,
    orElse: () => _focusOptions.last,
  );
}
