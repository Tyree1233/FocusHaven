import '../models/haven_action.dart';

class HavenActionPolicyDecision {
  const HavenActionPolicyDecision.allowed()
    : allowed = true,
      reason = HavenActionReason.none,
      message = '';

  const HavenActionPolicyDecision.rejected(this.reason, this.message)
    : allowed = false;

  final bool allowed;
  final HavenActionReason reason;
  final String message;
}

class HavenActionPolicy {
  static const maxSessionSeconds = 24 * 60 * 60;
  static const maxAddedSeconds = 60 * 60;
  static const maxQueueTitleLength = 100;

  HavenActionPolicyDecision evaluate({
    required HavenActionProposal proposal,
    required HavenActionState state,
    required DateTime nowUtc,
  }) {
    if (proposal.schemaVersion != 1 ||
        proposal.id.isEmpty ||
        proposal.source != HavenActionSource.typed ||
        proposal.createdAtUtc.isAfter(proposal.expiresAtUtc)) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        'The proposal is invalid. Nothing was changed.',
      );
    }
    if (nowUtc.isBefore(proposal.createdAtUtc)) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        'The proposal time is invalid. Nothing was changed.',
      );
    }
    if (nowUtc.isAfter(proposal.expiresAtUtc)) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.expiredProposal,
        'That proposal expired. Review the request again.',
      );
    }
    if (proposal.stateToken != state.token) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.staleProposal,
        'The timer or queue changed. Review a fresh proposal.',
      );
    }

    return switch (proposal.kind) {
      HavenActionKind.readTimerStatus =>
        const HavenActionPolicyDecision.allowed(),
      HavenActionKind.startTimer => _startDecision(proposal, state),
      HavenActionKind.pauseTimer =>
        state.activity == HavenTimerActivity.running
            ? const HavenActionPolicyDecision.allowed()
            : _unavailable(
                'The timer must be running before it can be paused.',
              ),
      HavenActionKind.resumeTimer =>
        state.activity == HavenTimerActivity.paused ||
                state.activity == HavenTimerActivity.pendingResume
            ? const HavenActionPolicyDecision.allowed()
            : _unavailable('There is no paused timer to resume.'),
      HavenActionKind.addTime => _addTimeDecision(proposal, state),
      HavenActionKind.openSurface => _surfaceDecision(proposal, state),
      HavenActionKind.draftQueueItem => _queueDecision(proposal),
    };
  }

  HavenActionPolicyDecision _startDecision(
    HavenActionProposal proposal,
    HavenActionState state,
  ) {
    if (proposal.arguments.session == null) {
      return _invalid();
    }
    if (state.activity != HavenTimerActivity.ready) {
      return _unavailable(
        'A timer can start here only when the current session is ready.',
      );
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _addTimeDecision(
    HavenActionProposal proposal,
    HavenActionState state,
  ) {
    final seconds = proposal.arguments.durationSeconds;
    if (seconds == null || seconds < 1 || seconds > maxAddedSeconds) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        'Added time must be from 1 to 60 minutes. Nothing was changed.',
      );
    }
    if (state.activity != HavenTimerActivity.running &&
        state.activity != HavenTimerActivity.paused) {
      return _unavailable(
        'Time can be added only to a running or paused timer.',
      );
    }
    if (state.totalSessionSeconds + seconds > maxSessionSeconds) {
      return _unavailable(
        'That would exceed the 24-hour timer limit. Nothing was changed.',
      );
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _surfaceDecision(
    HavenActionProposal proposal,
    HavenActionState state,
  ) {
    final surface = proposal.arguments.surface;
    if (surface == null) return _invalid();
    if (surface == HavenActionSurface.havenPlan && !state.canStartHavenPlan) {
      return _unavailable(
        'Haven Plan is available only before a ready Focus session starts.',
      );
    }
    if (surface == HavenActionSurface.smartReset && !state.canOfferSmartReset) {
      return _unavailable(
        'Smart Reset is available only for eligible active Focus sessions.',
      );
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _queueDecision(HavenActionProposal proposal) {
    final title = proposal.arguments.queueTitle;
    if (title == null ||
        title.trim().isEmpty ||
        title != title.trim() ||
        title.length > maxQueueTitleLength) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        'The queue item is invalid. Nothing was changed.',
      );
    }
    if (!proposal.confirmationRequired) return _invalid();
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _invalid() =>
      const HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        'The proposal is invalid. Nothing was changed.',
      );

  HavenActionPolicyDecision _unavailable(String message) =>
      HavenActionPolicyDecision.rejected(
        HavenActionReason.unavailableInCurrentState,
        message,
      );
}
