enum FocusEventOutcome { completed, reset, changedSession, discardedResume }

enum FocusSessionFit { tooMuch, aboutRight, couldDoMore }

/// A bounded, text-free record of how one focus attempt ended.
///
/// Focus events intentionally exclude task names, journal text, mood labels,
/// and other user-authored content. They provide enough local signal for
/// compassionate recovery and rhythm insights without building a second copy
/// of the user's private content.
class FocusEvent {
  const FocusEvent({
    required this.startedAt,
    required this.endedAt,
    required this.plannedDurationSeconds,
    required this.focusedDurationSeconds,
    required this.pauseCount,
    required this.didResume,
    required this.outcome,
    this.sessionFit,
  });

  static const schemaVersion = 1;

  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedDurationSeconds;
  final int focusedDurationSeconds;
  final int pauseCount;
  final bool didResume;
  final FocusEventOutcome outcome;
  final FocusSessionFit? sessionFit;

  bool get wasCompleted => outcome == FocusEventOutcome.completed;
  bool get canSupportRecovery =>
      outcome == FocusEventOutcome.reset ||
      outcome == FocusEventOutcome.discardedResume;

  bool get hasSessionReflection => sessionFit != null;

  FocusEvent withSessionFit(FocusSessionFit value) {
    if (!wasCompleted) return this;
    return FocusEvent(
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: plannedDurationSeconds,
      focusedDurationSeconds: focusedDurationSeconds,
      pauseCount: pauseCount,
      didResume: didResume,
      outcome: outcome,
      sessionFit: value,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'plannedDurationSeconds': plannedDurationSeconds,
    'focusedDurationSeconds': focusedDurationSeconds,
    'pauseCount': pauseCount,
    'didResume': didResume,
    'outcome': outcome.name,
    if (sessionFit != null) 'sessionFit': sessionFit!.name,
  };

  factory FocusEvent.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported focus event schema.');
    }

    final startedAtValue = json['startedAt'];
    final endedAtValue = json['endedAt'];
    final plannedDurationSeconds = json['plannedDurationSeconds'];
    final focusedDurationSeconds = json['focusedDurationSeconds'];
    final pauseCount = json['pauseCount'];
    final didResume = json['didResume'];
    final outcomeValue = json['outcome'];
    final sessionFitValue = json['sessionFit'];

    if (startedAtValue is! String ||
        endedAtValue is! String ||
        plannedDurationSeconds is! int ||
        focusedDurationSeconds is! int ||
        pauseCount is! int ||
        didResume is! bool ||
        outcomeValue is! String ||
        (sessionFitValue != null && sessionFitValue is! String)) {
      throw const FormatException('Invalid focus event shape.');
    }

    final startedAt = DateTime.tryParse(startedAtValue);
    final endedAt = DateTime.tryParse(endedAtValue);
    FocusEventOutcome? outcome;
    for (final value in FocusEventOutcome.values) {
      if (value.name == outcomeValue) {
        outcome = value;
        break;
      }
    }
    FocusSessionFit? sessionFit;
    if (sessionFitValue != null) {
      for (final value in FocusSessionFit.values) {
        if (value.name == sessionFitValue) {
          sessionFit = value;
          break;
        }
      }
    }
    if (startedAt == null ||
        endedAt == null ||
        endedAt.isBefore(startedAt) ||
        plannedDurationSeconds < 1 ||
        focusedDurationSeconds < 0 ||
        focusedDurationSeconds > plannedDurationSeconds ||
        pauseCount < 0 ||
        outcome == null ||
        (sessionFitValue != null && sessionFit == null) ||
        (sessionFit != null && outcome != FocusEventOutcome.completed)) {
      throw const FormatException('Invalid focus event values.');
    }

    return FocusEvent(
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      plannedDurationSeconds: plannedDurationSeconds,
      focusedDurationSeconds: focusedDurationSeconds,
      pauseCount: pauseCount,
      didResume: didResume,
      outcome: outcome,
      sessionFit: sessionFit,
    );
  }
}
