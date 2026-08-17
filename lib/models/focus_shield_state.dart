import 'system_focus_snapshot.dart';

enum FocusShieldAuthorization { notRequested, denied, approved }

enum FocusShieldNativeStatus { unavailable, inactive, protecting, failed }

enum FocusShieldPhase {
  off,
  unsupported,
  needsAuthorization,
  needsSelection,
  ready,
  starting,
  protecting,
  paused,
  needsAttention,
}

enum FocusShieldAction {
  enable,
  disable,
  requestAuthorization,
  chooseDistractions,
  pauseProtection,
  resumeProtection,
  retryProtection,
}

/// Text-free capability state supplied by a future native Focus Shield host.
///
/// Selected applications and websites never cross this boundary. Each native
/// platform owns those private choices and reports only whether a non-empty
/// selection exists.
typedef FocusShieldCapability = ({
  bool isEnabled,
  bool nativeSupportAvailable,
  FocusShieldAuthorization authorization,
  bool hasSelection,
  bool temporarilyPaused,
  FocusShieldNativeStatus nativeStatus,
});

/// One honest, local-only interpretation of Focus Shield readiness.
///
/// This model cannot block an application or mutate the timer. It says whether
/// protection should be requested and separately records whether the native
/// adapter reports that protection is active.
class FocusShieldState {
  const FocusShieldState({
    required this.phase,
    required this.headline,
    required this.detail,
    required this.shouldProtect,
    required this.nativeProtectionReported,
    required this.availableActions,
  });

  final FocusShieldPhase phase;
  final String headline;
  final String detail;

  /// Desired native enforcement for the current timer moment.
  final bool shouldProtect;

  /// Whether the native adapter independently reports active enforcement.
  final bool nativeProtectionReported;

  final Set<FocusShieldAction> availableActions;

  bool get isProtectionConfirmed =>
      phase == FocusShieldPhase.protecting &&
      shouldProtect &&
      nativeProtectionReported;

  bool get needsAdapterUpdate => shouldProtect != nativeProtectionReported;

  bool get needsUserSetup =>
      phase == FocusShieldPhase.needsAuthorization ||
      phase == FocusShieldPhase.needsSelection;

  bool allows(FocusShieldAction action) => availableActions.contains(action);
}

/// Timer state admitted into the Focus Shield decision boundary.
typedef FocusShieldTimerState = ({
  SystemFocusSession session,
  SystemFocusActivity activity,
});
