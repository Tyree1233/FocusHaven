import 'dart:math';

import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/haven_action.dart';
import '../models/haven_system_intent.dart';
import 'haven_action_engine.dart';
import 'haven_action_policy.dart';

typedef HavenSystemIntentReviewClock = DateTime Function();
typedef HavenSystemIntentReviewIdGenerator = String Function();

enum HavenSystemIntentReviewPreparationStatus {
  ready,
  invalid,
  replayed,
  unavailable,
  capacityReached,
}

enum HavenSystemIntentReviewRejectionReason {
  none,
  invalidDraft,
  duplicateInvocation,
  capacityReached,
  policyRejected,
}

enum HavenSystemIntentReviewSettlementStatus { executed, rejected, staleReview }

/// One opaque, short-lived in-app review capability.
///
/// The underlying [HavenActionProposal] never leaves this library. Presentation
/// can read only the already-localized explanation and bounded action metadata;
/// execution still requires an explicit call through the issuing service.
final class HavenSystemIntentReview {
  const HavenSystemIntentReview._(this._generation, this._proposal);

  final int _generation;
  final HavenActionProposal _proposal;

  HavenActionKind get actionKind => _proposal.kind;
  String get interpretation => _proposal.interpretation;
  String get effect => _proposal.effect;
  HavenActionRisk get risk => _proposal.risk;
  DateTime get expiresAtUtc => _proposal.expiresAtUtc;
  HavenActionSource get source => _proposal.source;
  bool get requiresExactConfirmation => _proposal.confirmationRequired;
  bool get safeUndoAvailable => _proposal.safeUndoAvailable;
  bool get canExecuteWithoutConfirmation => false;
}

final class HavenSystemIntentReviewPreparation {
  const HavenSystemIntentReviewPreparation._({
    required this.status,
    required this.rejectionReason,
    required this.message,
    required this.policyReason,
    this.review,
  });

  const HavenSystemIntentReviewPreparation.ready(HavenSystemIntentReview review)
    : this._(
        status: HavenSystemIntentReviewPreparationStatus.ready,
        rejectionReason: HavenSystemIntentReviewRejectionReason.none,
        message: '',
        policyReason: HavenActionReason.none,
        review: review,
      );

  const HavenSystemIntentReviewPreparation.rejected({
    required HavenSystemIntentReviewPreparationStatus status,
    required HavenSystemIntentReviewRejectionReason rejectionReason,
    required String message,
    HavenActionReason policyReason = HavenActionReason.none,
  }) : this._(
         status: status,
         rejectionReason: rejectionReason,
         message: message,
         policyReason: policyReason,
       );

  final HavenSystemIntentReviewPreparationStatus status;
  final HavenSystemIntentReviewRejectionReason rejectionReason;
  final String message;
  final HavenActionReason policyReason;
  final HavenSystemIntentReview? review;

  bool get isReady => status == HavenSystemIntentReviewPreparationStatus.ready;
}

final class HavenSystemIntentReviewSettlement {
  const HavenSystemIntentReviewSettlement._({
    required this.status,
    this.actionResult,
  });

  HavenSystemIntentReviewSettlement.completed(HavenActionResult result)
    : this._(
        status: result.executed
            ? HavenSystemIntentReviewSettlementStatus.executed
            : HavenSystemIntentReviewSettlementStatus.rejected,
        actionResult: result,
      );

  static const stale = HavenSystemIntentReviewSettlement._(
    status: HavenSystemIntentReviewSettlementStatus.staleReview,
  );

  final HavenSystemIntentReviewSettlementStatus status;
  final HavenActionResult? actionResult;

  bool get executed =>
      status == HavenSystemIntentReviewSettlementStatus.executed;
}

/// Converts one Phase 217A draft into one reviewed, state-bound Haven action.
///
/// This bridge owns no timer, queue, platform, persistence, network, or AI
/// capability. It snapshots and settles only through [HavenActionEngine],
/// consumes each external invocation once, exposes no raw proposal, and keeps
/// at most one in-app review active. Every route requires an exact confirmation
/// generated only when the person accepts that active review.
final class HavenSystemIntentReviewService {
  HavenSystemIntentReviewService({
    required this._engine,
    HavenSystemIntentReviewClock? clock,
    HavenSystemIntentReviewIdGenerator? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _secureId;

  static const maxRememberedInvocationIds = 128;
  static const maxInvocationIdLength = 128;

  static final RegExp _invocationIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
  );

  final HavenActionEngine _engine;
  final HavenSystemIntentReviewClock _clock;
  final HavenSystemIntentReviewIdGenerator _idGenerator;
  final Set<String> _consumedInvocationIds = <String>{};
  final Set<String> _issuedProposalIds = <String>{};
  int _nextGeneration = 0;
  int? _activeGeneration;

  HavenSystemIntentReviewPreparation prepareReview(
    HavenSystemIntentDraft draft, {
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    if (!_isExactDraft(draft)) {
      return HavenSystemIntentReviewPreparation.rejected(
        status: HavenSystemIntentReviewPreparationStatus.invalid,
        rejectionReason: HavenSystemIntentReviewRejectionReason.invalidDraft,
        message: l10n.havenActionServiceInvalidProposal,
      );
    }
    if (_consumedInvocationIds.contains(draft.invocationId)) {
      return HavenSystemIntentReviewPreparation.rejected(
        status: HavenSystemIntentReviewPreparationStatus.replayed,
        rejectionReason:
            HavenSystemIntentReviewRejectionReason.duplicateInvocation,
        message: l10n.havenActionServiceDuplicateProposal,
      );
    }
    if (_consumedInvocationIds.length >= maxRememberedInvocationIds) {
      return HavenSystemIntentReviewPreparation.rejected(
        status: HavenSystemIntentReviewPreparationStatus.capacityReached,
        rejectionReason: HavenSystemIntentReviewRejectionReason.capacityReached,
        message: l10n.havenActionServiceInvalidProposal,
      );
    }

    _consumedInvocationIds.add(draft.invocationId);
    _activeGeneration = null;
    final state = _engine.snapshot();
    final now = _clock().toUtc();
    final proposalId = _idGenerator();
    if (proposalId.isEmpty ||
        proposalId.length > maxInvocationIdLength ||
        !_invocationIdPattern.hasMatch(proposalId) ||
        !_issuedProposalIds.add(proposalId)) {
      return HavenSystemIntentReviewPreparation.rejected(
        status: HavenSystemIntentReviewPreparationStatus.invalid,
        rejectionReason: HavenSystemIntentReviewRejectionReason.invalidDraft,
        message: l10n.havenActionServiceInvalidProposal,
      );
    }
    final copy = _copyFor(draft, state, l10n);
    final proposal = HavenActionProposal(
      schemaVersion: 1,
      id: proposalId,
      source: HavenActionSource.systemIntent,
      kind: draft.actionKind,
      arguments: draft.arguments,
      interpretation: copy.interpretation,
      effect: copy.effect,
      stateToken: state.token,
      createdAtUtc: now,
      expiresAtUtc: now.add(HavenActionPolicy.systemIntentProposalLifetime),
      risk: copy.risk,
      confirmationRequired: true,
      safeUndoAvailable: true,
    );
    final decision = _engine.evaluate(proposal, localizations: l10n);
    if (!decision.allowed) {
      return HavenSystemIntentReviewPreparation.rejected(
        status: HavenSystemIntentReviewPreparationStatus.unavailable,
        rejectionReason: HavenSystemIntentReviewRejectionReason.policyRejected,
        message: decision.message,
        policyReason: decision.reason,
      );
    }

    final generation = ++_nextGeneration;
    _activeGeneration = generation;
    return HavenSystemIntentReviewPreparation.ready(
      HavenSystemIntentReview._(generation, proposal),
    );
  }

  Future<HavenSystemIntentReviewSettlement> confirm(
    HavenSystemIntentReview review, {
    AppLocalizations? localizations,
  }) async {
    if (_activeGeneration != review._generation) {
      return HavenSystemIntentReviewSettlement.stale;
    }
    _activeGeneration = null;
    final confirmation = HavenActionConfirmation.forProposal(
      review._proposal,
      confirmedAtUtc: _clock().toUtc(),
    );
    final result = await _engine.execute(
      review._proposal,
      confirmation: confirmation,
      localizations: localizations,
    );
    return HavenSystemIntentReviewSettlement.completed(result);
  }

  bool dismiss(HavenSystemIntentReview review) {
    if (_activeGeneration != review._generation) return false;
    _activeGeneration = null;
    return true;
  }

  bool _isExactDraft(HavenSystemIntentDraft draft) {
    if (draft.source != HavenActionSource.systemIntent ||
        draft.invocationId.isEmpty ||
        draft.invocationId.length > maxInvocationIdLength ||
        !_invocationIdPattern.hasMatch(draft.invocationId)) {
      return false;
    }
    return switch (draft.intentKind) {
      HavenSystemIntentKind.readTimerStatus =>
        draft.actionKind == HavenActionKind.readTimerStatus &&
            _hasNoArguments(draft.arguments),
      HavenSystemIntentKind.startFocusTimer =>
        draft.actionKind == HavenActionKind.startTimer &&
            draft.arguments.session == HavenSessionKind.focus &&
            draft.arguments.durationSeconds == null &&
            draft.arguments.surface == null &&
            draft.arguments.queueTitle == null,
      HavenSystemIntentKind.pauseTimer =>
        draft.actionKind == HavenActionKind.pauseTimer &&
            _hasNoArguments(draft.arguments),
      HavenSystemIntentKind.resumeTimer =>
        draft.actionKind == HavenActionKind.resumeTimer &&
            _hasNoArguments(draft.arguments),
      HavenSystemIntentKind.openFocusQueue =>
        draft.actionKind == HavenActionKind.openSurface &&
            draft.arguments.session == null &&
            draft.arguments.durationSeconds == null &&
            draft.arguments.surface == HavenActionSurface.focusQueue &&
            draft.arguments.queueTitle == null,
    };
  }

  _HavenSystemIntentCopy _copyFor(
    HavenSystemIntentDraft draft,
    HavenActionState state,
    AppLocalizations l10n,
  ) => switch (draft.intentKind) {
    HavenSystemIntentKind.readTimerStatus => _HavenSystemIntentCopy(
      interpretation: l10n.havenActionServiceTimerStatusInterpretation,
      effect: l10n.havenActionServiceTimerStatusEffect(
        _sessionLabel(state.session, l10n),
        _activityLabel(state.activity, l10n),
        _remainingTime(state),
      ),
      risk: HavenActionRisk.informational,
    ),
    HavenSystemIntentKind.startFocusTimer => _HavenSystemIntentCopy(
      interpretation: l10n.havenActionServiceStartTimerInterpretation(
        l10n.havenActionServiceSessionFocus,
      ),
      effect: l10n.havenActionServiceStartTimerEffect(
        l10n.havenActionServiceSessionFocus,
      ),
      risk: HavenActionRisk.reversibleControl,
    ),
    HavenSystemIntentKind.pauseTimer => _HavenSystemIntentCopy(
      interpretation: l10n.havenActionServicePauseTimerInterpretation,
      effect: l10n.havenActionServicePauseTimerEffect,
      risk: HavenActionRisk.reversibleControl,
    ),
    HavenSystemIntentKind.resumeTimer => _HavenSystemIntentCopy(
      interpretation: l10n.havenActionServiceResumeTimerInterpretation,
      effect: l10n.havenActionServiceResumeTimerEffect,
      risk: HavenActionRisk.reversibleControl,
    ),
    HavenSystemIntentKind.openFocusQueue => _HavenSystemIntentCopy(
      interpretation: l10n.havenActionServiceOpenInterpretation(
        l10n.havenActionServiceSurfaceFocusQueue,
      ),
      effect: l10n.havenActionServiceOpenEffect(
        l10n.havenActionServiceSurfaceFocusQueue,
      ),
      risk: HavenActionRisk.informational,
    ),
  };

  bool _hasNoArguments(HavenActionArguments arguments) =>
      arguments.session == null &&
      arguments.durationSeconds == null &&
      arguments.surface == null &&
      arguments.queueTitle == null;

  String _remainingTime(HavenActionState state) {
    final minutes = state.secondsRemaining ~/ 60;
    final seconds = state.secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _sessionLabel(HavenSessionKind session, AppLocalizations l10n) =>
      switch (session) {
        HavenSessionKind.focus => l10n.havenActionServiceSessionFocus,
        HavenSessionKind.shortBreak => l10n.havenActionServiceSessionShortBreak,
        HavenSessionKind.longBreak => l10n.havenActionServiceSessionLongBreak,
      };

  String _activityLabel(HavenTimerActivity activity, AppLocalizations l10n) =>
      switch (activity) {
        HavenTimerActivity.ready => l10n.havenActionServiceActivityReady,
        HavenTimerActivity.running => l10n.havenActionServiceActivityRunning,
        HavenTimerActivity.paused => l10n.havenActionServiceActivityPaused,
        HavenTimerActivity.pendingResume =>
          l10n.havenActionServiceActivityPendingResume,
        HavenTimerActivity.completed =>
          l10n.havenActionServiceActivityCompleted,
      };

  static String _secureId() {
    final random = Random.secure();
    final values = List<int>.generate(4, (_) => random.nextInt(1 << 32));
    return '${DateTime.now().microsecondsSinceEpoch}-${values.map((value) => value.toRadixString(16).padLeft(8, '0')).join()}';
  }
}

final class _HavenSystemIntentCopy {
  const _HavenSystemIntentCopy({
    required this.interpretation,
    required this.effect,
    required this.risk,
  });

  final String interpretation;
  final String effect;
  final HavenActionRisk risk;
}
