import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/focus_event.dart';
import '../models/haven_plan.dart';

/// Builds a calm focus recommendation entirely on the user's device.
///
/// The engine is intentionally deterministic and explainable. It does not
/// schedule work, start timers, persist plans, or contact a remote service.
class HavenPlanService {
  const HavenPlanService();

  static const _minimumAvailableMinutes = 5;
  static const _maximumAvailableMinutes = 180;
  static const _historyThreshold = 3;
  static const _recentEventLimit = 12;
  static const _completedEventLimit = 8;
  static const _sessionOptions = <({int focusMinutes, int breakMinutes})>[
    (focusMinutes: 5, breakMinutes: 0),
    (focusMinutes: 10, breakMinutes: 2),
    (focusMinutes: 15, breakMinutes: 3),
    (focusMinutes: 25, breakMinutes: 5),
    (focusMinutes: 45, breakMinutes: 10),
    (focusMinutes: 60, breakMinutes: 10),
    (focusMinutes: 90, breakMinutes: 15),
  ];

  HavenPlan createPlan({
    required List<HavenTaskCandidate> queue,
    required List<FocusEvent> recentEvents,
    required HavenEnergy energy,
    required int availableMinutes,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    final boundedAvailable = availableMinutes
        .clamp(_minimumAvailableMinutes, _maximumAvailableMinutes)
        .toInt();
    final sortedEvents = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final recent = sortedEvents.take(_recentEventLimit).toList(growable: false);
    final completedDurations = recent
        .where((event) => event.outcome == FocusEventOutcome.completed)
        .map((event) => event.focusedDurationSeconds ~/ 60)
        .where((minutes) => minutes >= 5 && minutes <= 90)
        .take(_completedEventLimit)
        .toList(growable: false);

    final hasRecoveryPattern = _hasRecentRecoveryPattern(recent);
    final reflectedCompletion = _latestReflectedCompletion(recent);
    final hasPersonalRhythm = completedDurations.length >= _historyThreshold;
    final basis = hasRecoveryPattern
        ? HavenPlanBasis.recentRecovery
        : reflectedCompletion != null
        ? HavenPlanBasis.sessionReflection
        : hasPersonalRhythm
        ? HavenPlanBasis.personalRhythm
        : energy == HavenEnergy.low
        ? HavenPlanBasis.gentleStart
        : HavenPlanBasis.freshStart;

    final uncappedTargetMinutes = switch (basis) {
      HavenPlanBasis.recentRecovery => 10,
      HavenPlanBasis.sessionReflection => _reflectedTarget(
        reflectedCompletion!,
      ),
      HavenPlanBasis.personalRhythm => _median(completedDurations),
      HavenPlanBasis.gentleStart => 10,
      HavenPlanBasis.freshStart => switch (energy) {
        HavenEnergy.low => 10,
        HavenEnergy.steady => 25,
        HavenEnergy.strong => 45,
      },
    };
    final energyMaximum = _energyMaximum(energy);
    final targetMinutes = uncappedTargetMinutes.clamp(5, energyMaximum).toInt();
    final wasEnergyBound = targetMinutes < uncappedTargetMinutes;

    final recommendation = _closestFittingOption(
      targetMinutes: targetMinutes,
      availableMinutes: boundedAvailable,
    );
    final selectedTask = _firstValidTask(queue);
    final taskTitle =
        selectedTask?.title ?? l10n.havenPlanServiceChooseSmallStep;
    final wasTimeBound = recommendation.focusMinutes < targetMinutes;

    return HavenPlan(
      queueItemId: selectedTask?.id,
      taskTitle: taskTitle,
      firstStep: selectedTask == null
          ? l10n.havenPlanServiceNameVisibleAction
          : l10n.havenPlanServiceOpenSmallestAction(taskTitle),
      focusMinutes: recommendation.focusMinutes,
      breakMinutes: recommendation.breakMinutes,
      availableMinutes: boundedAvailable,
      basis: basis,
      explanation: _explanation(
        basis: basis,
        energy: energy,
        sessionFit: reflectedCompletion?.sessionFit,
        wasTimeBound: wasTimeBound,
        wasEnergyBound: wasEnergyBound,
        localizations: l10n,
      ),
      wasTimeBound: wasTimeBound,
      wasEnergyBound: wasEnergyBound,
    );
  }

  static bool _hasRecentRecoveryPattern(List<FocusEvent> recentEvents) {
    final meaningful = recentEvents
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .take(3);
    return meaningful.where((event) => event.canSupportRecovery).length >= 2;
  }

  static FocusEvent? _latestReflectedCompletion(List<FocusEvent> events) {
    for (final event in events) {
      if (event.wasCompleted && event.sessionFit != null) return event;
    }
    return null;
  }

  static int _reflectedTarget(FocusEvent event) {
    final completedMinutes = (event.focusedDurationSeconds ~/ 60).clamp(1, 90);
    final focusOptions = _sessionOptions
        .map((option) => option.focusMinutes)
        .toList(growable: false);
    return switch (event.sessionFit!) {
      FocusSessionFit.tooMuch => focusOptions.lastWhere(
        (minutes) => minutes < completedMinutes,
        orElse: () => focusOptions.first,
      ),
      FocusSessionFit.aboutRight => focusOptions.reduce(
        (best, candidate) =>
            (candidate - completedMinutes).abs() <
                (best - completedMinutes).abs()
            ? candidate
            : best,
      ),
      FocusSessionFit.couldDoMore => focusOptions.firstWhere(
        (minutes) => minutes > completedMinutes,
        orElse: () => focusOptions.last,
      ),
    };
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  static int _energyMaximum(HavenEnergy energy) => switch (energy) {
    HavenEnergy.low => 15,
    HavenEnergy.steady => 45,
    HavenEnergy.strong => 90,
  };

  static ({int focusMinutes, int breakMinutes}) _closestFittingOption({
    required int targetMinutes,
    required int availableMinutes,
  }) {
    final fitting = _sessionOptions
        .where(
          (option) =>
              option.focusMinutes + option.breakMinutes <= availableMinutes,
        )
        .toList(growable: false);
    final candidates = fitting.isEmpty ? [_sessionOptions.first] : fitting;
    var best = candidates.first;
    var bestDistance = (best.focusMinutes - targetMinutes).abs();
    for (final candidate in candidates.skip(1)) {
      final distance = (candidate.focusMinutes - targetMinutes).abs();
      if (distance < bestDistance ||
          (distance == bestDistance &&
              candidate.focusMinutes < best.focusMinutes)) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  static HavenTaskCandidate? _firstValidTask(List<HavenTaskCandidate> queue) {
    for (final candidate in queue) {
      final id = candidate.id.trim();
      final title = candidate.title.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (id.isEmpty || title.isEmpty) continue;
      return HavenTaskCandidate(
        id: id,
        title: title.length > 100 ? title.substring(0, 100) : title,
      );
    }
    return null;
  }

  static String _explanation({
    required HavenPlanBasis basis,
    required HavenEnergy energy,
    required FocusSessionFit? sessionFit,
    required bool wasTimeBound,
    required bool wasEnergyBound,
    required AppLocalizations localizations,
  }) {
    final l10n = localizations;
    final base = switch (basis) {
      HavenPlanBasis.recentRecovery => l10n.havenPlanServiceRecentRecovery,
      HavenPlanBasis.sessionReflection => switch (sessionFit!) {
        FocusSessionFit.tooMuch => l10n.havenPlanServiceReflectionTooMuch,
        FocusSessionFit.aboutRight => l10n.havenPlanServiceReflectionAboutRight,
        FocusSessionFit.couldDoMore =>
          l10n.havenPlanServiceReflectionCouldDoMore,
      },
      HavenPlanBasis.personalRhythm => l10n.havenPlanServicePersonalRhythm,
      HavenPlanBasis.gentleStart => l10n.havenPlanServiceGentleStart,
      HavenPlanBasis.freshStart =>
        energy == HavenEnergy.strong
            ? l10n.havenPlanServiceFreshStartSpacious
            : l10n.havenPlanServiceFreshStartSteady,
    };
    final details = <String>[
      if (wasEnergyBound) l10n.havenPlanServiceEnergyBound,
      if (wasTimeBound) l10n.havenPlanServiceTimeBound,
    ];
    return details.isEmpty
        ? base
        : l10n.havenPlanServiceExplanationWithDetails(base, details.join(' '));
  }
}
