import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_shield_state.dart';
import 'package:focushaven/models/system_focus_snapshot.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_shield_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  const service = FocusShieldService();

  FocusShieldCapability capability({
    bool isEnabled = true,
    bool nativeSupportAvailable = true,
    FocusShieldAuthorization authorization = FocusShieldAuthorization.approved,
    bool hasSelection = true,
    bool temporarilyPaused = false,
    FocusShieldNativeStatus nativeStatus = FocusShieldNativeStatus.inactive,
  }) => (
    isEnabled: isEnabled,
    nativeSupportAvailable: nativeSupportAvailable,
    authorization: authorization,
    hasSelection: hasSelection,
    temporarilyPaused: temporarilyPaused,
    nativeStatus: nativeStatus,
  );

  FocusShieldState createState({
    FocusShieldCapability? withCapability,
    SystemFocusSession session = SystemFocusSession.focus,
    SystemFocusActivity activity = SystemFocusActivity.ready,
  }) => service.createState(
    capability: withCapability ?? capability(),
    timer: (session: session, activity: activity),
  );

  test('starts opted out and never implies protection', () {
    final state = createState(
      withCapability: capability(
        isEnabled: false,
        nativeSupportAvailable: false,
        authorization: FocusShieldAuthorization.notRequested,
        hasSelection: false,
        nativeStatus: FocusShieldNativeStatus.unavailable,
      ),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.off);
    expect(state.shouldProtect, isFalse);
    expect(state.isProtectionConfirmed, isFalse);
    expect(state.availableActions, isEmpty);
    expect(state.detail, contains('until you choose'));
  });

  test('unsupported platforms fail open without a protection claim', () {
    final state = createState(
      withCapability: capability(
        nativeSupportAvailable: false,
        authorization: FocusShieldAuthorization.notRequested,
        hasSelection: false,
        nativeStatus: FocusShieldNativeStatus.unavailable,
      ),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.unsupported);
    expect(state.shouldProtect, isFalse);
    expect(state.nativeProtectionReported, isFalse);
    expect(state.headline, contains('not available'));
    expect(state.allows(FocusShieldAction.disable), isTrue);
  });

  test('authorization remains explicit after first use or denial', () {
    final firstUse = createState(
      withCapability: capability(
        authorization: FocusShieldAuthorization.notRequested,
        hasSelection: false,
      ),
    );
    final denied = createState(
      withCapability: capability(
        authorization: FocusShieldAuthorization.denied,
        hasSelection: false,
      ),
    );

    expect(firstUse.phase, FocusShieldPhase.needsAuthorization);
    expect(firstUse.needsUserSetup, isTrue);
    expect(firstUse.headline, contains('your hands'));
    expect(firstUse.allows(FocusShieldAction.requestAuthorization), isTrue);
    expect(denied.phase, FocusShieldPhase.needsAuthorization);
    expect(denied.headline, contains('permission is off'));
    expect(denied.detail, contains('remains inactive'));
  });

  test('an approved empty selection cannot start protection', () {
    final state = createState(
      withCapability: capability(hasSelection: false),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.needsSelection);
    expect(state.needsUserSetup, isTrue);
    expect(state.shouldProtect, isFalse);
    expect(state.detail, contains('stay on this device'));
    expect(state.allows(FocusShieldAction.chooseDistractions), isTrue);
  });

  test('idle focus and every break remain open by design', () {
    final idle = createState();
    final runningBreak = createState(
      session: SystemFocusSession.shortBreak,
      activity: SystemFocusActivity.running,
    );
    final completedBreak = createState(
      session: SystemFocusSession.longBreak,
      activity: SystemFocusActivity.completed,
    );

    expect(idle.phase, FocusShieldPhase.ready);
    expect(idle.shouldProtect, isFalse);
    expect(idle.detail, contains('only when you start'));
    for (final state in [runningBreak, completedBreak]) {
      expect(state.phase, FocusShieldPhase.ready);
      expect(state.shouldProtect, isFalse);
      expect(state.headline, contains('Breaks stay open'));
    }
  });

  test('paused completed and pending focus moments do not protect', () {
    for (final activity in [
      SystemFocusActivity.paused,
      SystemFocusActivity.completed,
      SystemFocusActivity.pendingResume,
    ]) {
      final state = createState(activity: activity);
      expect(state.phase, FocusShieldPhase.ready);
      expect(state.shouldProtect, isFalse);
    }

    final recovery = createState(activity: SystemFocusActivity.pendingResume);
    expect(recovery.headline, contains('wait with you'));
    expect(recovery.detail, contains('choose whether'));
  });

  test('running focus waits for independent native confirmation', () {
    final state = createState(activity: SystemFocusActivity.running);

    expect(state.phase, FocusShieldPhase.starting);
    expect(state.shouldProtect, isTrue);
    expect(state.nativeProtectionReported, isFalse);
    expect(state.isProtectionConfirmed, isFalse);
    expect(state.needsAdapterUpdate, isTrue);
    expect(state.detail, contains('waiting for the device to confirm'));
  });

  test('protection is claimed only after the native report agrees', () {
    final state = createState(
      withCapability: capability(
        nativeStatus: FocusShieldNativeStatus.protecting,
      ),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.protecting);
    expect(state.shouldProtect, isTrue);
    expect(state.nativeProtectionReported, isTrue);
    expect(state.isProtectionConfirmed, isTrue);
    expect(state.needsAdapterUpdate, isFalse);
    expect(state.detail, contains('Only the distractions you selected'));
  });

  test('temporary pause preserves user control and requests release', () {
    final state = createState(
      withCapability: capability(
        temporarilyPaused: true,
        nativeStatus: FocusShieldNativeStatus.protecting,
      ),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.paused);
    expect(state.shouldProtect, isFalse);
    expect(state.nativeProtectionReported, isTrue);
    expect(state.needsAdapterUpdate, isTrue);
    expect(state.allows(FocusShieldAction.resumeProtection), isTrue);
    expect(state.detail, contains('remain in control'));
  });

  test('native failure stays honest and offers a bounded retry', () {
    final state = createState(
      withCapability: capability(nativeStatus: FocusShieldNativeStatus.failed),
      activity: SystemFocusActivity.running,
    );

    expect(state.phase, FocusShieldPhase.needsAttention);
    expect(state.shouldProtect, isTrue);
    expect(state.isProtectionConfirmed, isFalse);
    expect(state.headline, contains('could not start'));
    expect(state.detail, contains('without pretending'));
    expect(state.availableActions, {
      FocusShieldAction.retryProtection,
      FocusShieldAction.pauseProtection,
      FocusShieldAction.disable,
    });
  });

  test('Riverpod composes a confirmed state without private selections', () {
    const runningFocus = (
      sessionType: SessionType.focus,
      isRunning: true,
      isComplete: false,
      hasPendingResume: false,
      focusTask: 'Private task that must not enter Focus Shield',
      parkedThoughtCount: 3,
      completionMessage: '',
      completedFocusSessionFit: null,
    );
    final container = ProviderContainer(
      overrides: [
        timerSessionStateProvider.overrideWithValue(runningFocus),
        timerHasProgressProvider.overrideWithValue(true),
        focusShieldCapabilityProvider.overrideWithValue(
          capability(nativeStatus: FocusShieldNativeStatus.protecting),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(focusShieldStateProvider);

    expect(state.phase, FocusShieldPhase.protecting);
    expect(state.isProtectionConfirmed, isTrue);
    expect(state.headline, isNot(contains('Private task')));
    expect(state.detail, isNot(contains('Private task')));
  });

  test('Riverpod distinguishes a paused timer from a fresh ready timer', () {
    const idleFocus = (
      sessionType: SessionType.focus,
      isRunning: false,
      isComplete: false,
      hasPendingResume: false,
      focusTask: '',
      parkedThoughtCount: 0,
      completionMessage: '',
      completedFocusSessionFit: null,
    );
    final container = ProviderContainer(
      overrides: [
        timerSessionStateProvider.overrideWithValue(idleFocus),
        timerHasProgressProvider.overrideWithValue(true),
        focusShieldCapabilityProvider.overrideWithValue(capability()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(focusShieldStateProvider);

    expect(state.phase, FocusShieldPhase.ready);
    expect(state.shouldProtect, isFalse);
  });
}
