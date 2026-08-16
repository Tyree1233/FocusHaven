enum HavenRhythmKind {
  learning,
  gentleReturn,
  gentlerPace,
  sustainablePace,
  roomToGrow,
  variablePace,
  completionPattern,
}

/// A transparent, ephemeral interpretation of private focus-event signals.
///
/// Insights contain no task text, mood labels, scores, diagnoses, or remote
/// identifiers. They are rebuilt locally and are never persisted themselves.
class HavenRhythmInsight {
  const HavenRhythmInsight({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.evidence,
    required this.signalCount,
    required this.usesSessionReflections,
    this.suggestedFocusMinutes,
  });

  final HavenRhythmKind kind;
  final String headline;
  final String detail;
  final String evidence;
  final int signalCount;
  final bool usesSessionReflections;
  final int? suggestedFocusMinutes;

  bool get isLearning => kind == HavenRhythmKind.learning;
  bool get hasSuggestedPace => suggestedFocusMinutes != null;
}
