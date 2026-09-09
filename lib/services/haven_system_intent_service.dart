import '../models/haven_system_intent.dart';

/// Prepares the Phase 217A system-assistant allowlist without executing it.
///
/// This service owns no platform registration, presentation, localization,
/// timer, queue, persistence, network, AI, or Haven Action Engine capability.
/// It emits only an ephemeral, non-executable route that a later reviewed
/// in-app bridge must rebind to current state.
final class HavenSystemIntentService {
  static const schemaVersion = 1;
  static const maxInvocationIdLength = 128;
  static const maxRememberedInvocationIds = 128;

  static final RegExp _invocationIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
  );

  final Set<String> _consumedInvocationIds = <String>{};

  HavenSystemIntentPreparation prepare(HavenSystemIntentRequest request) {
    if (request.schemaVersion != schemaVersion) {
      return const HavenSystemIntentPreparation.rejected(
        HavenSystemIntentPreparationStatus.invalid,
        HavenSystemIntentRejectionReason.unsupportedSchema,
      );
    }
    if (request.invocationId.isEmpty ||
        request.invocationId.length > maxInvocationIdLength ||
        !_invocationIdPattern.hasMatch(request.invocationId)) {
      return const HavenSystemIntentPreparation.rejected(
        HavenSystemIntentPreparationStatus.invalid,
        HavenSystemIntentRejectionReason.invalidInvocationId,
      );
    }
    if (_consumedInvocationIds.contains(request.invocationId)) {
      return const HavenSystemIntentPreparation.rejected(
        HavenSystemIntentPreparationStatus.replayed,
        HavenSystemIntentRejectionReason.duplicateInvocation,
      );
    }
    if (_consumedInvocationIds.length >= maxRememberedInvocationIds) {
      return const HavenSystemIntentPreparation.rejected(
        HavenSystemIntentPreparationStatus.unavailable,
        HavenSystemIntentRejectionReason.capacityReached,
      );
    }

    _consumedInvocationIds.add(request.invocationId);
    return HavenSystemIntentPreparation.prepared(_draftFor(request));
  }

  HavenSystemIntentDraft _draftFor(HavenSystemIntentRequest request) {
    switch (request.kind) {
      case HavenSystemIntentKind.readTimerStatus:
        return HavenSystemIntentDraft.readTimerStatus(request.invocationId);
      case HavenSystemIntentKind.startFocusTimer:
        return HavenSystemIntentDraft.startFocusTimer(request.invocationId);
      case HavenSystemIntentKind.pauseTimer:
        return HavenSystemIntentDraft.pauseTimer(request.invocationId);
      case HavenSystemIntentKind.resumeTimer:
        return HavenSystemIntentDraft.resumeTimer(request.invocationId);
      case HavenSystemIntentKind.openFocusQueue:
        return HavenSystemIntentDraft.openFocusQueue(request.invocationId);
    }
  }
}
