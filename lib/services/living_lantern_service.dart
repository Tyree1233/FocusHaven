import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
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
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    if (isRunning && isComplete) {
      throw ArgumentError('The Living Lantern requires a valid timer state.');
    }

    if (hasPendingResume) {
      return LivingLanternState(
        phase: LivingLanternPhase.gentleReturn,
        headline: l10n.livingLanternServicePendingHeadline,
        detail: l10n.livingLanternServicePendingDetail,
        supportingSignalCount: 0,
      );
    }

    if (sessionType != SessionType.focus) {
      if (isRunning) {
        return LivingLanternState(
          phase: LivingLanternPhase.resting,
          headline: l10n.livingLanternServiceBreakRunningHeadline,
          detail: l10n.livingLanternServiceBreakRunningDetail,
          supportingSignalCount: 0,
        );
      }
      if (isComplete) {
        return LivingLanternState(
          phase: LivingLanternPhase.ready,
          headline: l10n.livingLanternServiceBreakCompleteHeadline,
          detail: l10n.livingLanternServiceBreakCompleteDetail,
          supportingSignalCount: 0,
        );
      }
      return LivingLanternState(
        phase: LivingLanternPhase.resting,
        headline: l10n.livingLanternServiceBreakIdleHeadline,
        detail: l10n.livingLanternServiceBreakIdleDetail,
        supportingSignalCount: 0,
      );
    }

    if (isComplete) {
      return LivingLanternState(
        phase: LivingLanternPhase.celebrating,
        headline: l10n.livingLanternServiceFocusCompleteHeadline,
        detail: l10n.livingLanternServiceFocusCompleteDetail,
        supportingSignalCount: 0,
      );
    }

    if (isRunning) {
      return LivingLanternState(
        phase: LivingLanternPhase.focusing,
        headline: l10n.livingLanternServiceFocusRunningHeadline,
        detail: l10n.livingLanternServiceFocusRunningDetail,
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
        headline: l10n.livingLanternServiceRecoveryHeadline,
        detail: l10n.livingLanternServiceRecoveryDetail,
        supportingSignalCount: recoveryCount,
      );
    }

    return LivingLanternState(
      phase: LivingLanternPhase.ready,
      headline: l10n.livingLanternServiceReadyHeadline,
      detail: meaningful.any((event) => event.wasCompleted)
          ? l10n.livingLanternServiceReadyWithHistoryDetail
          : l10n.livingLanternServiceReadyWithoutHistoryDetail,
      supportingSignalCount: meaningful.isEmpty ? 0 : 1,
    );
  }
}
