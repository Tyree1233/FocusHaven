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

  HavenRhythmInsight createInsight({required List<FocusEvent> recentEvents}) {
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
        headline: 'A gentler return may fit right now',
        detail:
            'Recent attempts suggest lowering the starting pressure before trying to optimize your pace.',
        evidence:
            '$recoverySignals of the last ${latestMeaningful.length} meaningful attempts needed a reset.',
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
            headline: 'Less may fit better right now',
            detail:
                'Several recent reflections said the session felt like too much. A shorter next session may lower the pressure.',
            evidence:
                '$highestCount of ${reflected.length} recent reflections said “Too much.”',
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _previousFocusOption(center),
          ),
          FocusSessionFit.aboutRight => HavenRhythmInsight(
            kind: HavenRhythmKind.sustainablePace,
            headline:
                '${_nearestFocusOption(center)} minutes has felt sustainable',
            detail:
                'Recent sessions you marked “About right” cluster near this pace.',
            evidence:
                '$highestCount of ${reflected.length} recent reflections said “About right.”',
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _nearestFocusOption(center),
          ),
          FocusSessionFit.couldDoMore => HavenRhythmInsight(
            kind: HavenRhythmKind.roomToGrow,
            headline: 'You may have room for one small step up',
            detail:
                'Recent reflections suggest a slightly longer session could fit, while current energy and available time still lead.',
            evidence:
                '$highestCount of ${reflected.length} recent reflections said “Could do more.”',
            signalCount: reflected.length,
            usesSessionReflections: true,
            suggestedFocusMinutes: _nextFocusOption(center),
          ),
        };
      }

      if (reflected.length >= _minimumPatternSignals) {
        return HavenRhythmInsight(
          kind: HavenRhythmKind.variablePace,
          headline: 'Your rhythm changes with the day',
          detail:
              'Recent reflections are mixed, so FocusHaven will let current energy and available time lead instead of forcing one pace.',
          evidence:
              '${reflected.length} recent reflections do not show one repeated fit yet.',
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
        headline: 'A completion rhythm is emerging',
        detail:
            'Recent completed sessions cluster near $pace minutes. Only your reflections can tell whether that pace actually feels right.',
        evidence:
            '${completedDurations.length} recent completed sessions shaped this observation.',
        signalCount: completedDurations.length,
        usesSessionReflections: false,
        suggestedFocusMinutes: pace,
      );
    }

    return HavenRhythmInsight(
      kind: HavenRhythmKind.learning,
      headline: 'Your Haven Rhythm is still forming',
      detail:
          'Complete and optionally reflect on a few sessions. FocusHaven will keep suggestions gentle until a pattern is clear.',
      evidence: meaningful.isEmpty
          ? 'No private focus-attempt signals are available yet.'
          : '${meaningful.length} recent attempt${meaningful.length == 1 ? '' : 's'} do not show one repeated pattern yet.',
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
