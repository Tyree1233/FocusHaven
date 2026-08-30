import '../models/haven_action.dart';
import 'focus_queue_service.dart';
import 'haven_action_policy.dart';
import 'timer_service.dart';

typedef HavenSurfaceOpener = Future<bool> Function(HavenActionSurface surface);

class HavenActionExecutor {
  const HavenActionExecutor({
    required this.timer,
    required this.focusQueue,
    required this.openSurface,
  });

  final TimerService timer;
  final FocusQueueService focusQueue;
  final HavenSurfaceOpener openSurface;

  HavenActionState snapshot() {
    final activity = timer.isComplete
        ? HavenTimerActivity.completed
        : timer.hasPendingResume
        ? HavenTimerActivity.pendingResume
        : timer.isRunning
        ? HavenTimerActivity.running
        : _isPaused
        ? HavenTimerActivity.paused
        : HavenTimerActivity.ready;
    return HavenActionState(
      session: switch (timer.sessionType) {
        SessionType.focus => HavenSessionKind.focus,
        SessionType.shortBreak => HavenSessionKind.shortBreak,
        SessionType.longBreak => HavenSessionKind.longBreak,
      },
      activity: activity,
      secondsRemaining: timer.secondsRemaining,
      totalSessionSeconds: timer.totalSessionSeconds,
      queueRevision: focusQueue.queueRevision,
      canStartHavenPlan: timer.canStartHavenPlan,
      canOfferSmartReset: timer.canOfferSmartReset,
    );
  }

  bool get _isPaused =>
      !timer.isComplete &&
      !timer.hasPendingResume &&
      !timer.isRunning &&
      (timer.secondsRemaining < timer.totalSessionSeconds ||
          timer.canOfferSmartReset);

  Future<bool> execute(HavenActionProposal proposal) async {
    switch (proposal.kind) {
      case HavenActionKind.readTimerStatus:
        return true;
      case HavenActionKind.startTimer:
        final requested = proposal.arguments.session;
        if (requested == null) return false;
        timer.selectSession(switch (requested) {
          HavenSessionKind.focus => SessionType.focus,
          HavenSessionKind.shortBreak => SessionType.shortBreak,
          HavenSessionKind.longBreak => SessionType.longBreak,
        });
        timer.start();
        return timer.isRunning;
      case HavenActionKind.pauseTimer:
        timer.pause();
        return !timer.isRunning;
      case HavenActionKind.resumeTimer:
        if (timer.hasPendingResume) {
          timer.resumePendingSession();
        } else {
          timer.start();
        }
        return timer.isRunning;
      case HavenActionKind.addTime:
        final seconds = proposal.arguments.durationSeconds;
        return seconds != null && timer.addTime(Duration(seconds: seconds));
      case HavenActionKind.openSurface:
        final surface = proposal.arguments.surface;
        return surface != null && await openSurface(surface);
      case HavenActionKind.draftQueueItem:
        final title = proposal.arguments.queueTitle;
        if (title == null) return false;
        final revision = focusQueue.queueRevision;
        await focusQueue.add(title);
        return focusQueue.queueRevision == revision + 1;
    }
  }
}

class HavenActionEngine {
  factory HavenActionEngine({
    required HavenActionExecutor executor,
    HavenActionPolicy? policy,
    DateTime Function()? clock,
  }) => HavenActionEngine._(
    executor: executor,
    policy: policy ?? HavenActionPolicy(),
    clock: clock ?? DateTime.now,
  );

  HavenActionEngine._({
    required this._executor,
    required this._policy,
    required this._clock,
  });

  static const _maxRememberedProposalIds = 128;

  final HavenActionExecutor _executor;
  final HavenActionPolicy _policy;
  final DateTime Function() _clock;
  final Set<String> _consumedProposalIds = <String>{};
  final List<String> _consumptionOrder = <String>[];

  HavenActionPolicyDecision evaluate(HavenActionProposal proposal) {
    if (_consumedProposalIds.contains(proposal.id)) {
      return const HavenActionPolicyDecision.rejected(
        HavenActionReason.duplicateProposal,
        'That proposal was already handled. Nothing was replayed.',
      );
    }
    return _policy.evaluate(
      proposal: proposal,
      state: _executor.snapshot(),
      nowUtc: _clock().toUtc(),
    );
  }

  Future<HavenActionResult> execute(
    HavenActionProposal proposal, {
    HavenActionConfirmation? confirmation,
  }) async {
    final decision = evaluate(proposal);
    if (!decision.allowed) {
      _rememberConsumed(proposal.id);
      return _result(
        proposal,
        HavenActionOutcome.rejected,
        decision.reason,
        decision.message,
      );
    }
    if (proposal.confirmationRequired) {
      if (confirmation == null) {
        _rememberConsumed(proposal.id);
        return _result(
          proposal,
          HavenActionOutcome.rejected,
          HavenActionReason.confirmationRequired,
          'Review and confirm this exact proposal before it can run.',
        );
      }
      if (confirmation.proposalId != proposal.id ||
          confirmation.proposalFingerprint !=
              proposal.confirmationFingerprint ||
          confirmation.confirmedAtUtc.isBefore(proposal.createdAtUtc) ||
          confirmation.confirmedAtUtc.isAfter(proposal.expiresAtUtc)) {
        _rememberConsumed(proposal.id);
        return _result(
          proposal,
          HavenActionOutcome.rejected,
          HavenActionReason.confirmationMismatch,
          'The confirmation does not match this proposal. Nothing changed.',
        );
      }
    }

    _rememberConsumed(proposal.id);
    try {
      final executed = await _executor.execute(proposal);
      if (!executed) {
        return _result(
          proposal,
          HavenActionOutcome.rejected,
          HavenActionReason.serviceRejected,
          'The owning FocusHaven service declined the action. Nothing changed.',
        );
      }
      return _result(
        proposal,
        HavenActionOutcome.executed,
        HavenActionReason.none,
        _successMessage(proposal),
      );
    } catch (_) {
      return _result(
        proposal,
        HavenActionOutcome.failed,
        HavenActionReason.serviceFailure,
        'The action could not be completed. No success was recorded.',
      );
    }
  }

  void _rememberConsumed(String id) {
    if (!_consumedProposalIds.add(id)) return;
    _consumptionOrder.add(id);
    if (_consumptionOrder.length > _maxRememberedProposalIds) {
      _consumedProposalIds.remove(_consumptionOrder.removeAt(0));
    }
  }

  HavenActionResult _result(
    HavenActionProposal proposal,
    HavenActionOutcome outcome,
    HavenActionReason reason,
    String message,
  ) => HavenActionResult(
    receipt: HavenActionReceipt(
      proposalId: proposal.id,
      kind: proposal.kind,
      outcome: outcome,
      reason: reason,
      occurredAtUtc: _clock().toUtc(),
      resultingStateToken: _executor.snapshot().token,
    ),
    message: message,
  );

  String _successMessage(HavenActionProposal proposal) =>
      switch (proposal.kind) {
        HavenActionKind.readTimerStatus => proposal.effect,
        HavenActionKind.startTimer => 'The timer started.',
        HavenActionKind.pauseTimer => 'The timer paused.',
        HavenActionKind.resumeTimer => 'The timer resumed.',
        HavenActionKind.addTime => 'Time was added to the current timer.',
        HavenActionKind.openSurface =>
          'The requested FocusHaven screen opened.',
        HavenActionKind.draftQueueItem =>
          'The reviewed item was added to Focus Queue.',
      };
}
