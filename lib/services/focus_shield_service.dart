import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/focus_shield_state.dart';
import '../models/system_focus_snapshot.dart';

/// Builds a deterministic Focus Shield request without invoking platform code.
///
/// Protection is opt-in, requires native support, authorization, and at least
/// one native-owned selection, and is requested only while a focus session is
/// actively running. Breaks, pauses, recovery decisions, and completed
/// sessions remain open by design.
class FocusShieldService {
  const FocusShieldService();

  FocusShieldState createState({
    required FocusShieldCapability capability,
    required FocusShieldTimerState timer,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    final nativeProtecting =
        capability.nativeStatus == FocusShieldNativeStatus.protecting;

    if (!capability.isEnabled) {
      return FocusShieldState(
        phase: FocusShieldPhase.off,
        headline: l10n.focusShieldOffHeadline,
        detail: l10n.focusShieldOffDetail,
        shouldProtect: false,
        nativeProtectionReported: nativeProtecting,
        availableActions: capability.nativeSupportAvailable
            ? const {FocusShieldAction.enable}
            : const {},
      );
    }

    if (!capability.nativeSupportAvailable ||
        capability.nativeStatus == FocusShieldNativeStatus.unavailable) {
      return FocusShieldState(
        phase: FocusShieldPhase.unsupported,
        headline: l10n.focusShieldUnsupportedHeadline,
        detail: l10n.focusShieldUnsupportedDetail,
        shouldProtect: false,
        nativeProtectionReported: false,
        availableActions: const {FocusShieldAction.disable},
      );
    }

    if (capability.authorization != FocusShieldAuthorization.approved) {
      final wasDenied =
          capability.authorization == FocusShieldAuthorization.denied;
      return FocusShieldState(
        phase: FocusShieldPhase.needsAuthorization,
        headline: wasDenied
            ? l10n.focusShieldPermissionDeniedHeadline
            : l10n.focusShieldPermissionRequiredHeadline,
        detail: wasDenied
            ? l10n.focusShieldPermissionDeniedDetail
            : l10n.focusShieldPermissionRequiredDetail,
        shouldProtect: false,
        nativeProtectionReported: nativeProtecting,
        availableActions: const {
          FocusShieldAction.requestAuthorization,
          FocusShieldAction.disable,
        },
      );
    }

    if (!capability.hasSelection) {
      return FocusShieldState(
        phase: FocusShieldPhase.needsSelection,
        headline: l10n.focusShieldSelectionHeadline,
        detail: l10n.focusShieldSelectionDetail,
        shouldProtect: false,
        nativeProtectionReported: nativeProtecting,
        availableActions: const {
          FocusShieldAction.chooseDistractions,
          FocusShieldAction.disable,
        },
      );
    }

    final shouldProtect =
        timer.session == SystemFocusSession.focus &&
        timer.activity == SystemFocusActivity.running &&
        !capability.temporarilyPaused;

    if (shouldProtect) {
      if (capability.nativeStatus == FocusShieldNativeStatus.failed) {
        return FocusShieldState(
          phase: FocusShieldPhase.needsAttention,
          headline: l10n.focusShieldFailedHeadline,
          detail: l10n.focusShieldFailedDetail,
          shouldProtect: true,
          nativeProtectionReported: false,
          availableActions: const {
            FocusShieldAction.retryProtection,
            FocusShieldAction.pauseProtection,
            FocusShieldAction.disable,
          },
        );
      }
      if (!nativeProtecting) {
        return FocusShieldState(
          phase: FocusShieldPhase.starting,
          headline: l10n.focusShieldStartingHeadline,
          detail: l10n.focusShieldStartingDetail,
          shouldProtect: true,
          nativeProtectionReported: false,
          availableActions: {
            FocusShieldAction.pauseProtection,
            FocusShieldAction.disable,
          },
        );
      }
      return FocusShieldState(
        phase: FocusShieldPhase.protecting,
        headline: l10n.focusShieldProtectingHeadline,
        detail: l10n.focusShieldProtectingDetail,
        shouldProtect: true,
        nativeProtectionReported: true,
        availableActions: {
          FocusShieldAction.pauseProtection,
          FocusShieldAction.disable,
        },
      );
    }

    if (capability.temporarilyPaused &&
        timer.session == SystemFocusSession.focus &&
        timer.activity == SystemFocusActivity.running) {
      return FocusShieldState(
        phase: FocusShieldPhase.paused,
        headline: l10n.focusShieldPausedHeadline,
        detail: l10n.focusShieldPausedDetail,
        shouldProtect: false,
        nativeProtectionReported: nativeProtecting,
        availableActions: const {
          FocusShieldAction.resumeProtection,
          FocusShieldAction.disable,
        },
      );
    }

    final isBreak = timer.session != SystemFocusSession.focus;
    final isRecovery = timer.activity == SystemFocusActivity.pendingResume;
    return FocusShieldState(
      phase: FocusShieldPhase.ready,
      headline: isBreak
          ? l10n.focusShieldBreakHeadline
          : isRecovery
          ? l10n.focusShieldRecoveryHeadline
          : l10n.focusShieldReadyHeadline,
      detail: isBreak
          ? l10n.focusShieldBreakDetail
          : isRecovery
          ? l10n.focusShieldRecoveryDetail
          : l10n.focusShieldReadyDetail,
      shouldProtect: false,
      nativeProtectionReported: nativeProtecting,
      availableActions: const {
        FocusShieldAction.chooseDistractions,
        FocusShieldAction.disable,
      },
    );
  }
}
