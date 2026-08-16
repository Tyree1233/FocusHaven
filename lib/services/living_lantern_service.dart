import '../models/focus_event.dart';
import '../models/living_lantern_state.dart';
import 'timer_service.dart';

/// Creates one deterministic, local-only Living Lantern state.
///
/// Recovery changes the lantern's language, never its worth or accumulated
/// progress. The service observes timer state and cannot mutate a session.
class LivingLanternService {
  const LivingLanternService();

  static const _recentEventLimit = 3;
  static const _repeatedRecoveryThreshold = 2;

  LivingLanternState createState({
    required SessionType sessionType,
    required bool isRunning,
    required bool isComplete,
    required bool hasPendingResume,
    required List<FocusEvent> recentEvents,
  }) {
    if (isRunning && isComplete) {
      throw ArgumentError('The Living Lantern requires a valid timer state.');
    }

    if (hasPendingResume) {
      return const LivingLanternState(
        phase: LivingLanternPhase.gentleReturn,
        headline: 'Your light is waiting with you',
        detail:
            'This attempt can be resumed, reshaped, or released. Nothing about the pause erased your effort.',
        supportingSignalCount: 0,
      );
    }

    if (sessionType != SessionType.focus) {
      if (isRunning) {
        return const LivingLanternState(
          phase: LivingLanternPhase.resting,
          headline: 'Rest keeps the light steady',
          detail:
              'This break belongs in your rhythm. There is nothing else to earn right now.',
          supportingSignalCount: 0,
        );
      }
      if (isComplete) {
        return const LivingLanternState(
          phase: LivingLanternPhase.ready,
          headline: 'Begin again when you choose',
          detail:
              'The break is complete, and the lantern can wait without rushing you.',
          supportingSignalCount: 0,
        );
      }
      return const LivingLanternState(
        phase: LivingLanternPhase.resting,
        headline: 'The lantern can rest too',
        detail:
            'A quiet pause is part of sustainable focus, not time taken away from it.',
        supportingSignalCount: 0,
      );
    }

    if (isComplete) {
      return const LivingLanternState(
        phase: LivingLanternPhase.celebrating,
        headline: 'Your light grew because you showed up',
        detail:
            'The session is complete. Its value does not depend on doing anything more.',
        supportingSignalCount: 0,
      );
    }

    if (isRunning) {
      return const LivingLanternState(
        phase: LivingLanternPhase.focusing,
        headline: 'Your light is steady',
        detail:
            'One chosen moment has your attention. The lantern is here without keeping score.',
        supportingSignalCount: 0,
      );
    }

    final recent = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final meaningful = recent
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .take(_recentEventLimit)
        .toList(growable: false);
    final recoveryCount = meaningful
        .where((event) => event.canSupportRecovery)
        .length;
    if (meaningful.length >= _repeatedRecoveryThreshold &&
        recoveryCount >= _repeatedRecoveryThreshold) {
      return LivingLanternState(
        phase: LivingLanternPhase.gentleReturn,
        headline: 'A smaller return still carries light',
        detail:
            'Recent attempts needed room to reset. The lantern stays whole while you choose a gentler next step.',
        supportingSignalCount: recoveryCount,
      );
    }

    return LivingLanternState(
      phase: LivingLanternPhase.ready,
      headline: 'Your light is ready when you are',
      detail: meaningful.any((event) => event.wasCompleted)
          ? 'Past focus still counts. This next session can begin without proving anything.'
          : 'Choose one reachable step. The lantern begins with presence, not pressure.',
      supportingSignalCount: meaningful.isEmpty ? 0 : 1,
    );
  }
}
