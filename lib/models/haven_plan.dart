enum HavenEnergy { low, steady, strong }

enum HavenPlanBasis {
  freshStart,
  gentleStart,
  recentRecovery,
  sessionReflection,
  personalRhythm,
}

/// A sanitized queue candidate provided to the local Haven planning engine.
class HavenTaskCandidate {
  const HavenTaskCandidate({required this.id, required this.title});

  final String id;
  final String title;
}

/// A transparent, ephemeral recommendation that is never persisted by itself.
class HavenPlan {
  const HavenPlan({
    required this.queueItemId,
    required this.taskTitle,
    required this.firstStep,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.availableMinutes,
    required this.basis,
    required this.explanation,
    required this.wasTimeBound,
    required this.wasEnergyBound,
  });

  final String? queueItemId;
  final String taskTitle;
  final String firstStep;
  final int focusMinutes;
  final int breakMinutes;
  final int availableMinutes;
  final HavenPlanBasis basis;
  final String explanation;
  final bool wasTimeBound;
  final bool wasEnergyBound;

  int get totalPlannedMinutes => focusMinutes + breakMinutes;
  bool get usesPersonalHistory =>
      basis == HavenPlanBasis.sessionReflection ||
      basis == HavenPlanBasis.personalRhythm;
  bool get usesSessionReflection => basis == HavenPlanBasis.sessionReflection;
  bool get supportsRecovery => basis == HavenPlanBasis.recentRecovery;
}
