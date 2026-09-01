import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/focus_event.dart';
import '../models/smart_reset_plan.dart';

/// Creates a deterministic, local-only recovery suggestion from time signals.
class SmartResetService {
  const SmartResetService();

  static const _fiveMinutes = 5 * 60;
  static const _tenMinutes = 10 * 60;
  static const _meaningfulProgress = 5 * 60;

  SmartResetPlan createPlan({
    required int plannedDurationSeconds,
    required int focusedDurationSeconds,
    required List<FocusEvent> recentEvents,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    if (plannedDurationSeconds < 2 ||
        focusedDurationSeconds < 0 ||
        focusedDurationSeconds > plannedDurationSeconds) {
      throw ArgumentError(l10n.smartResetInvalidAttempt);
    }

    final recent = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final meaningful = recent
        .where((event) => event.outcome != FocusEventOutcome.changedSession)
        .take(3);
    final hasRepeatedRecovery =
        meaningful.where((event) => event.canSupportRecovery).length >= 2;
    final basis = hasRepeatedRecovery
        ? SmartResetBasis.repeatedRecovery
        : focusedDurationSeconds >= _meaningfulProgress
        ? SmartResetBasis.meaningfulProgress
        : SmartResetBasis.gentleReturn;
    final targetSeconds = hasRepeatedRecovery
        ? _fiveMinutes
        : plannedDurationSeconds >= 20 * 60
        ? _tenMinutes
        : _fiveMinutes;
    final restartSeconds =
        (targetSeconds < plannedDurationSeconds
                ? targetSeconds
                : (plannedDurationSeconds ~/ 2).clamp(
                    1,
                    plannedDurationSeconds - 1,
                  ))
            .toInt();

    return SmartResetPlan(
      restartDurationSeconds: restartSeconds,
      originalDurationSeconds: plannedDurationSeconds,
      focusedDurationSeconds: focusedDurationSeconds,
      basis: basis,
      explanation: switch (basis) {
        SmartResetBasis.repeatedRecovery =>
          l10n.smartResetRepeatedRecoveryExplanation,
        SmartResetBasis.meaningfulProgress =>
          l10n.smartResetMeaningfulProgressExplanation,
        SmartResetBasis.gentleReturn => l10n.smartResetGentleReturnExplanation,
      },
    );
  }
}
