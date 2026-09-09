import 'haven_action.dart';

/// The complete Phase 217A system-assistant allowlist.
///
/// These values describe a requested destination inside FocusHaven. They do
/// not grant Siri, Shortcuts, Android App Actions, or this model authority to
/// read state or execute an action.
enum HavenSystemIntentKind {
  readTimerStatus,
  startFocusTimer,
  pauseTimer,
  resumeTimer,
  openFocusQueue,
}

enum HavenSystemIntentPreparationStatus {
  prepared,
  invalid,
  replayed,
  unavailable,
}

enum HavenSystemIntentRejectionReason {
  none,
  unsupportedSchema,
  invalidInvocationId,
  duplicateInvocation,
  capacityReached,
}

/// One bounded, text-free request received from a future platform adapter.
///
/// The opaque invocation ID is correlation state only. No utterance, task,
/// coaching, journal, reflection, account, or other user-authored content can
/// enter this contract.
final class HavenSystemIntentRequest {
  const HavenSystemIntentRequest({
    required this.schemaVersion,
    required this.invocationId,
    required this.kind,
  });

  final int schemaVersion;
  final String invocationId;
  final HavenSystemIntentKind kind;
}

/// A prepared route into the existing Haven Action vocabulary.
///
/// This is deliberately not a [HavenActionProposal]. It has no proposal ID,
/// current-state token, localized explanation, expiry, confirmation, or
/// execution capability. A later reviewed in-app bridge must construct and
/// display a fresh state-bound proposal before [HavenActionSource.systemIntent]
/// can ever reach the Haven Action Engine.
final class HavenSystemIntentDraft {
  const HavenSystemIntentDraft._({
    required this.invocationId,
    required this.intentKind,
    required this.actionKind,
    required this.arguments,
  });

  const HavenSystemIntentDraft.readTimerStatus(String invocationId)
    : this._(
        invocationId: invocationId,
        intentKind: HavenSystemIntentKind.readTimerStatus,
        actionKind: HavenActionKind.readTimerStatus,
        arguments: const HavenActionArguments.none(),
      );

  const HavenSystemIntentDraft.startFocusTimer(String invocationId)
    : this._(
        invocationId: invocationId,
        intentKind: HavenSystemIntentKind.startFocusTimer,
        actionKind: HavenActionKind.startTimer,
        arguments: const HavenActionArguments.start(HavenSessionKind.focus),
      );

  const HavenSystemIntentDraft.pauseTimer(String invocationId)
    : this._(
        invocationId: invocationId,
        intentKind: HavenSystemIntentKind.pauseTimer,
        actionKind: HavenActionKind.pauseTimer,
        arguments: const HavenActionArguments.none(),
      );

  const HavenSystemIntentDraft.resumeTimer(String invocationId)
    : this._(
        invocationId: invocationId,
        intentKind: HavenSystemIntentKind.resumeTimer,
        actionKind: HavenActionKind.resumeTimer,
        arguments: const HavenActionArguments.none(),
      );

  const HavenSystemIntentDraft.openFocusQueue(String invocationId)
    : this._(
        invocationId: invocationId,
        intentKind: HavenSystemIntentKind.openFocusQueue,
        actionKind: HavenActionKind.openSurface,
        arguments: const HavenActionArguments.open(
          HavenActionSurface.focusQueue,
        ),
      );

  final String invocationId;
  final HavenSystemIntentKind intentKind;
  final HavenActionKind actionKind;
  final HavenActionArguments arguments;

  HavenActionSource get source => HavenActionSource.systemIntent;
  bool get requiresInAppReview => true;
  bool get canExecute => false;
}

final class HavenSystemIntentPreparation {
  const HavenSystemIntentPreparation._({
    required this.status,
    required this.rejectionReason,
    this.draft,
  });

  const HavenSystemIntentPreparation.prepared(HavenSystemIntentDraft draft)
    : this._(
        status: HavenSystemIntentPreparationStatus.prepared,
        rejectionReason: HavenSystemIntentRejectionReason.none,
        draft: draft,
      );

  const HavenSystemIntentPreparation.rejected(
    HavenSystemIntentPreparationStatus status,
    HavenSystemIntentRejectionReason rejectionReason,
  ) : this._(status: status, rejectionReason: rejectionReason);

  final HavenSystemIntentPreparationStatus status;
  final HavenSystemIntentRejectionReason rejectionReason;
  final HavenSystemIntentDraft? draft;

  bool get isPrepared => status == HavenSystemIntentPreparationStatus.prepared;
}
