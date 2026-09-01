import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
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
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    final supportedSource =
        proposal.source == HavenActionSource.typed ||
        proposal.source == HavenActionSource.voiceTranscript;
    if (proposal.schemaVersion != 1 ||
        proposal.id.isEmpty ||
        !supportedSource ||
        proposal.createdAtUtc.isAfter(proposal.expiresAtUtc)) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        l10n.havenActionServiceInvalidProposal,
      );
    }
    if (nowUtc.isBefore(proposal.createdAtUtc)) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        l10n.havenActionServiceInvalidProposalTime,
      );
    }
    if (nowUtc.isAfter(proposal.expiresAtUtc)) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.expiredProposal,
        l10n.havenActionServiceExpiredProposal,
      );
    }
    if (proposal.stateToken != state.token) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.staleProposal,
        l10n.havenActionServiceStaleProposal,
      );
    }

    return switch (proposal.kind) {
      HavenActionKind.readTimerStatus =>
        const HavenActionPolicyDecision.allowed(),
      HavenActionKind.startTimer => _startDecision(proposal, state, l10n),
      HavenActionKind.pauseTimer =>
        state.activity == HavenTimerActivity.running
            ? const HavenActionPolicyDecision.allowed()
            : _unavailable(l10n.havenActionServicePauseUnavailable),
      HavenActionKind.resumeTimer =>
        state.activity == HavenTimerActivity.paused ||
                state.activity == HavenTimerActivity.pendingResume
            ? const HavenActionPolicyDecision.allowed()
            : _unavailable(l10n.havenActionServiceResumeUnavailable),
      HavenActionKind.addTime => _addTimeDecision(proposal, state, l10n),
      HavenActionKind.openSurface => _surfaceDecision(proposal, state, l10n),
      HavenActionKind.draftQueueItem => _queueDecision(proposal, l10n),
    };
  }

  HavenActionPolicyDecision _startDecision(
    HavenActionProposal proposal,
    HavenActionState state,
    AppLocalizations l10n,
  ) {
    if (proposal.arguments.session == null) {
      return _invalid(l10n);
    }
    if (state.activity != HavenTimerActivity.ready) {
      return _unavailable(l10n.havenActionServiceStartUnavailable);
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _addTimeDecision(
    HavenActionProposal proposal,
    HavenActionState state,
    AppLocalizations l10n,
  ) {
    final seconds = proposal.arguments.durationSeconds;
    if (seconds == null || seconds < 1 || seconds > maxAddedSeconds) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        l10n.havenActionServiceAddedTimeInvalid,
      );
    }
    if (state.activity != HavenTimerActivity.running &&
        state.activity != HavenTimerActivity.paused) {
      return _unavailable(l10n.havenActionServiceAddTimeUnavailable);
    }
    if (state.totalSessionSeconds + seconds > maxSessionSeconds) {
      return _unavailable(l10n.havenActionServiceTimerLimitExceeded);
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _surfaceDecision(
    HavenActionProposal proposal,
    HavenActionState state,
    AppLocalizations l10n,
  ) {
    final surface = proposal.arguments.surface;
    if (surface == null) return _invalid(l10n);
    if (surface == HavenActionSurface.havenPlan && !state.canStartHavenPlan) {
      return _unavailable(l10n.havenActionServiceHavenPlanUnavailable);
    }
    if (surface == HavenActionSurface.smartReset && !state.canOfferSmartReset) {
      return _unavailable(l10n.havenActionServiceSmartResetUnavailable);
    }
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _queueDecision(
    HavenActionProposal proposal,
    AppLocalizations l10n,
  ) {
    final title = proposal.arguments.queueTitle;
    if (title == null ||
        title.trim().isEmpty ||
        title != title.trim() ||
        title.length > maxQueueTitleLength) {
      return HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        l10n.havenActionServiceQueueItemInvalidProposal,
      );
    }
    if (!proposal.confirmationRequired) return _invalid(l10n);
    return const HavenActionPolicyDecision.allowed();
  }

  HavenActionPolicyDecision _invalid(AppLocalizations l10n) =>
      HavenActionPolicyDecision.rejected(
        HavenActionReason.invalidProposal,
        l10n.havenActionServiceInvalidProposal,
      );

  HavenActionPolicyDecision _unavailable(String message) =>
      HavenActionPolicyDecision.rejected(
        HavenActionReason.unavailableInCurrentState,
        message,
      );
}
