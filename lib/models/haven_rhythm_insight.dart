import 'focus_event.dart';

enum HavenRhythmKind {
  learning,
  gentleReturn,
  gentlerPace,
  sustainablePace,
  roomToGrow,
  variablePace,
  completionPattern,
}

enum HavenRhythmReflectionConnectionKind {
  learning,
  reflectionPattern,
  recoveryLeads,
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

/// One ephemeral explanation of how an exact private session reflection
/// relates to the current Haven Rhythm observation.
///
/// The connection is rebuilt from text-free focus events and is never
/// persisted. It cannot change the timer, choose a pace, or schedule work.
class HavenRhythmReflectionConnection {
  const HavenRhythmReflectionConnection({
    required this.kind,
    required this.completion,
    required this.selectedFit,
    required this.insight,
    required this.headline,
    required this.detail,
  });

  final HavenRhythmReflectionConnectionKind kind;
  final FocusCompletionIdentity completion;
  final FocusSessionFit selectedFit;
  final HavenRhythmInsight insight;
  final String headline;
  final String detail;

  bool get usesRepeatedReflections =>
      kind == HavenRhythmReflectionConnectionKind.reflectionPattern;
}
