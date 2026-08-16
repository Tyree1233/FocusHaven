enum LivingLanternPhase { ready, focusing, resting, celebrating, gentleReturn }

/// One calm, ephemeral interpretation of the current focus moment.
///
/// The lantern has no health, score, level, streak, or failure state. It is
/// rebuilt locally from timer controls and bounded text-free focus events and
/// is never persisted by itself.
class LivingLanternState {
  const LivingLanternState({
    required this.phase,
    required this.headline,
    required this.detail,
    required this.supportingSignalCount,
  });

  final LivingLanternPhase phase;
  final String headline;
  final String detail;

  /// Number of recent private focus events that shaped this state.
  ///
  /// Live timer states do not need historical evidence and use zero.
  final int supportingSignalCount;

  bool get isActive =>
      phase == LivingLanternPhase.focusing ||
      phase == LivingLanternPhase.resting;
  bool get isCelebrating => phase == LivingLanternPhase.celebrating;
  bool get isGentleReturn => phase == LivingLanternPhase.gentleReturn;
  bool get usesRecentEvents => supportingSignalCount > 0;
}
