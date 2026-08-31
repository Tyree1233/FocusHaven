enum HavenPlannerUncertainty { low, medium, high }

enum HavenPlannerItemKind { queueTask, sessionSuggestion, freeTimeSuggestion }

enum HavenPlannerLocalData { temporaryGoalText, focusQueue }

enum HavenPlannerReviewChoice { pending, accepted, edited, rejected }

class HavenPlannerInput {
  const HavenPlannerInput({
    required this.goal,
    required this.availableMinutes,
    required this.preferredFocusMinutes,
  });

  final String goal;
  final int availableMinutes;
  final int preferredFocusMinutes;
}

class HavenPlannerItem {
  const HavenPlannerItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.explanation,
    required this.affectedLocalData,
    required this.canEdit,
    required this.willMutateWhenAccepted,
  });

  final String id;
  final HavenPlannerItemKind kind;
  final String title;
  final String explanation;
  final Set<HavenPlannerLocalData> affectedLocalData;
  final bool canEdit;
  final bool willMutateWhenAccepted;
}

/// An ephemeral, transparent draft produced only from explicit local input.
///
/// The proposal has no execution authority. A review surface must independently
/// settle every item, and accepted mutations must still pass through the Haven
/// Action Engine and the owning FocusHaven service.
class HavenPlannerProposal {
  const HavenPlannerProposal({
    required this.schemaVersion,
    required this.id,
    required this.createdAtUtc,
    required this.input,
    required this.assumptions,
    required this.uncertainty,
    required this.uncertaintyExplanation,
    required this.affectedLocalData,
    required this.items,
    required this.isLocalOnly,
  });

  final int schemaVersion;
  final String id;
  final DateTime createdAtUtc;
  final HavenPlannerInput input;
  final List<String> assumptions;
  final HavenPlannerUncertainty uncertainty;
  final String uncertaintyExplanation;
  final Set<HavenPlannerLocalData> affectedLocalData;
  final List<HavenPlannerItem> items;
  final bool isLocalOnly;
}
