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
  }) {
    final nativeProtecting =
        capability.nativeStatus == FocusShieldNativeStatus.protecting;

    if (!capability.isEnabled) {
      return FocusShieldState(
        phase: FocusShieldPhase.off,
        headline: 'Focus Shield is off',
        detail: 'Nothing is restricted until you choose to turn protection on.',
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
        headline: 'Focus Shield is not available here yet',
        detail:
            'This device has no authorized blocking adapter, so FocusHaven will not claim that distractions are restricted.',
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
            ? 'Focus Shield permission is off'
            : 'Permission stays in your hands',
        detail: wasDenied
            ? 'Protection remains inactive. You can revisit device permission whenever it feels useful.'
            : 'FocusHaven will ask before using the device tools needed to limit selected distractions.',
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
        headline: 'Choose what feels distracting',
        detail:
            'Your private choices stay on this device. Focus Shield remains inactive until you select at least one app or website.',
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
          headline: 'Focus Shield could not start',
          detail:
              'The timer can continue without pretending protection is active. Retry when you are ready.',
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
        return const FocusShieldState(
          phase: FocusShieldPhase.starting,
          headline: 'Preparing your Haven',
          detail:
              'FocusHaven is waiting for the device to confirm that your selected distractions are restricted.',
          shouldProtect: true,
          nativeProtectionReported: false,
          availableActions: {
            FocusShieldAction.pauseProtection,
            FocusShieldAction.disable,
          },
        );
      }
      return const FocusShieldState(
        phase: FocusShieldPhase.protecting,
        headline: 'Your Haven is protected',
        detail:
            'Only the distractions you selected are restricted during this focus session.',
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
        headline: 'Focus Shield is taking a pause',
        detail:
            'You remain in control. Resume protection when it feels supportive.',
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
          ? 'Breaks stay open by design'
          : isRecovery
          ? 'Focus Shield can wait with you'
          : 'Focus Shield is ready',
      detail: isBreak
          ? 'Selected distractions are not restricted during a FocusHaven break.'
          : isRecovery
          ? 'Protection stays inactive while you choose whether to resume or release this attempt.'
          : 'Protection begins only when you start a focus session.',
      shouldProtect: false,
      nativeProtectionReported: nativeProtecting,
      availableActions: const {
        FocusShieldAction.chooseDistractions,
        FocusShieldAction.disable,
      },
    );
  }
}
