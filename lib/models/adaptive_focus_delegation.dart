enum AdaptiveFocusDelegationOutcome { applied, keptCurrent, rejected }

/// One text-free result from the timer-owner delegation boundary.
///
/// Rejection intentionally carries no stale values. Applied and kept-current
/// results expose only the exact whole-minute defaults settled by the owner.
class AdaptiveFocusDelegationResult {
  const AdaptiveFocusDelegationResult._({
    required this.outcome,
    this.focusMinutes,
    this.breakMinutes,
  });

  const AdaptiveFocusDelegationResult.applied({
    required int focusMinutes,
    required int breakMinutes,
  }) : this._(
         outcome: AdaptiveFocusDelegationOutcome.applied,
         focusMinutes: focusMinutes,
         breakMinutes: breakMinutes,
       );

  const AdaptiveFocusDelegationResult.keptCurrent({
    required int focusMinutes,
    required int breakMinutes,
  }) : this._(
         outcome: AdaptiveFocusDelegationOutcome.keptCurrent,
         focusMinutes: focusMinutes,
         breakMinutes: breakMinutes,
       );

  static const rejected = AdaptiveFocusDelegationResult._(
    outcome: AdaptiveFocusDelegationOutcome.rejected,
  );

  final AdaptiveFocusDelegationOutcome outcome;
  final int? focusMinutes;
  final int? breakMinutes;

  bool get wasApplied => outcome == AdaptiveFocusDelegationOutcome.applied;
  bool get keptCurrent => outcome == AdaptiveFocusDelegationOutcome.keptCurrent;
  bool get wasRejected => outcome == AdaptiveFocusDelegationOutcome.rejected;
}
