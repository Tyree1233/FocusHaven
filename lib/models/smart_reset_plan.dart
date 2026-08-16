enum SmartResetBasis { gentleReturn, meaningfulProgress, repeatedRecovery }

/// A private, text-free suggestion for restarting an interrupted focus attempt.
class SmartResetPlan {
  const SmartResetPlan({
    required this.restartDurationSeconds,
    required this.originalDurationSeconds,
    required this.focusedDurationSeconds,
    required this.basis,
    required this.explanation,
  });

  final int restartDurationSeconds;
  final int originalDurationSeconds;
  final int focusedDurationSeconds;
  final SmartResetBasis basis;
  final String explanation;

  bool get acknowledgesProgress => basis == SmartResetBasis.meaningfulProgress;
  bool get respondsToRepeatedRecovery =>
      basis == SmartResetBasis.repeatedRecovery;
}
