import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_engine.dart';
import 'package:focushaven/services/haven_action_policy.dart';
import 'package:focushaven/services/haven_system_intent_review_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<_Fixture> fixture({
    DateTime? now,
    Future<bool> Function(HavenActionSurface surface)? openSurface,
    HavenSystemIntentReviewIdGenerator? idGenerator,
  }) async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    final currentTime = now ?? DateTime.utc(2026, 9, 9, 14);
    final executor = HavenActionExecutor(
      timer: timer,
      focusQueue: queue,
      openSurface: openSurface ?? (_) async => true,
    );
    final engine = HavenActionEngine(
      executor: executor,
      clock: () => currentTime,
    );
    var nextId = 0;
    final bridge = HavenSystemIntentReviewService(
      engine: engine,
      clock: () => currentTime,
      idGenerator: idGenerator ?? () => 'system-review-${++nextId}',
    );
    return _Fixture(
      timer: timer,
      queue: queue,
      executor: executor,
      engine: engine,
      bridge: bridge,
      now: currentTime,
    );
  }

  test('builds exact localized in-app reviews without executing', () async {
    final owned = await fixture();
    final l10n = lookupAppLocalizations(const Locale('es'));

    final status = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.readTimerStatus('status-1'),
      localizations: l10n,
    );
    final statusReview = status.review!;
    expect(status.isReady, isTrue);
    expect(statusReview.actionKind, HavenActionKind.readTimerStatus);
    expect(
      statusReview.interpretation,
      l10n.havenActionServiceTimerStatusInterpretation,
    );
    expect(
      statusReview.effect,
      l10n.havenActionServiceTimerStatusEffect(
        l10n.havenActionServiceSessionFocus,
        l10n.havenActionServiceActivityReady,
        '25:00',
      ),
    );
    expect(statusReview.risk, HavenActionRisk.informational);

    final start = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.startFocusTimer('start-1'),
      localizations: l10n,
    );
    final startReview = start.review!;
    expect(startReview.actionKind, HavenActionKind.startTimer);
    expect(
      startReview.interpretation,
      l10n.havenActionServiceStartTimerInterpretation(
        l10n.havenActionServiceSessionFocus,
      ),
    );
    expect(
      startReview.effect,
      l10n.havenActionServiceStartTimerEffect(
        l10n.havenActionServiceSessionFocus,
      ),
    );
    expect(startReview.risk, HavenActionRisk.reversibleControl);

    final queue = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.openFocusQueue('queue-1'),
      localizations: l10n,
    );
    final queueReview = queue.review!;
    expect(queueReview.actionKind, HavenActionKind.openSurface);
    expect(
      queueReview.interpretation,
      l10n.havenActionServiceOpenInterpretation(
        l10n.havenActionServiceSurfaceFocusQueue,
      ),
    );
    expect(
      queueReview.effect,
      l10n.havenActionServiceOpenEffect(
        l10n.havenActionServiceSurfaceFocusQueue,
      ),
    );
    expect(queueReview.risk, HavenActionRisk.informational);

    for (final review in <HavenSystemIntentReview>[
      statusReview,
      startReview,
      queueReview,
    ]) {
      expect(review.source, HavenActionSource.systemIntent);
      expect(review.requiresExactConfirmation, isTrue);
      expect(review.safeUndoAvailable, isTrue);
      expect(review.canExecuteWithoutConfirmation, isFalse);
      expect(
        review.expiresAtUtc,
        owned.now.add(HavenActionPolicy.systemIntentProposalLifetime),
      );
      expect(review.interpretation, isNot(contains('status-1')));
      expect(review.effect, isNot(contains('status-1')));
    }
    expect(owned.timer.isRunning, isFalse);
    expect(owned.queue.items, isEmpty);
  });

  test(
    'explicit confirmation delegates one exact start through the engine',
    () async {
      final owned = await fixture();
      final preparation = owned.bridge.prepareReview(
        const HavenSystemIntentDraft.startFocusTimer('start-once'),
      );
      final review = preparation.review!;

      expect(preparation.isReady, isTrue);
      expect(owned.timer.isRunning, isFalse);

      final first = await owned.bridge.confirm(review);
      final replay = await owned.bridge.confirm(review);

      expect(first.executed, isTrue);
      expect(first.actionResult!.receipt.kind, HavenActionKind.startTimer);
      expect(first.actionResult!.receipt.outcome, HavenActionOutcome.executed);
      expect(owned.timer.isRunning, isTrue);
      expect(
        replay.status,
        HavenSystemIntentReviewSettlementStatus.staleReview,
      );
      expect(replay.actionResult, isNull);
    },
  );

  test('fresh owner state permits pause and resume reviews', () async {
    final owned = await fixture();
    owned.timer.start();

    final pause = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.pauseTimer('pause-1'),
    );
    expect(pause.review!.interpretation, isNotEmpty);
    expect((await owned.bridge.confirm(pause.review!)).executed, isTrue);
    expect(owned.timer.isRunning, isFalse);

    final resume = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.resumeTimer('resume-1'),
    );
    expect(resume.review!.effect, isNotEmpty);
    expect((await owned.bridge.confirm(resume.review!)).executed, isTrue);
    expect(owned.timer.isRunning, isTrue);
  });

  test('changed live state rejects and consumes the exact review', () async {
    final owned = await fixture();
    final review = owned.bridge
        .prepareReview(
          const HavenSystemIntentDraft.startFocusTimer('stale-start'),
        )
        .review!;
    owned.timer.selectSession(SessionType.shortBreak);

    final stale = await owned.bridge.confirm(review);
    final replay = await owned.bridge.confirm(review);

    expect(stale.executed, isFalse);
    expect(stale.status, HavenSystemIntentReviewSettlementStatus.rejected);
    expect(stale.actionResult!.receipt.reason, HavenActionReason.staleProposal);
    expect(replay.status, HavenSystemIntentReviewSettlementStatus.staleReview);
    expect(owned.timer.isRunning, isFalse);
  });

  test('unavailable drafts are consumed before later owner changes', () async {
    final owned = await fixture();
    const draft = HavenSystemIntentDraft.pauseTimer('pause-later');

    final unavailable = owned.bridge.prepareReview(draft);
    owned.timer.start();
    final replay = owned.bridge.prepareReview(draft);

    expect(
      unavailable.status,
      HavenSystemIntentReviewPreparationStatus.unavailable,
    );
    expect(
      unavailable.rejectionReason,
      HavenSystemIntentReviewRejectionReason.policyRejected,
    );
    expect(
      unavailable.policyReason,
      HavenActionReason.unavailableInCurrentState,
    );
    expect(unavailable.review, isNull);
    expect(replay.status, HavenSystemIntentReviewPreparationStatus.replayed);
    expect(
      replay.rejectionReason,
      HavenSystemIntentReviewRejectionReason.duplicateInvocation,
    );
  });

  test('newer review supersedes older and dismiss is single use', () async {
    final owned = await fixture();
    final first = owned.bridge
        .prepareReview(
          const HavenSystemIntentDraft.readTimerStatus('first-review'),
        )
        .review!;
    final second = owned.bridge
        .prepareReview(
          const HavenSystemIntentDraft.openFocusQueue('second-review'),
        )
        .review!;

    expect(
      (await owned.bridge.confirm(first)).status,
      HavenSystemIntentReviewSettlementStatus.staleReview,
    );
    expect(owned.bridge.dismiss(second), isTrue);
    expect(owned.bridge.dismiss(second), isFalse);
    expect(
      (await owned.bridge.confirm(second)).status,
      HavenSystemIntentReviewSettlementStatus.staleReview,
    );
  });

  test('bounded replay memory fails closed without eviction', () async {
    final owned = await fixture();

    for (
      var index = 0;
      index < HavenSystemIntentReviewService.maxRememberedInvocationIds;
      index += 1
    ) {
      final result = owned.bridge.prepareReview(
        HavenSystemIntentDraft.readTimerStatus('bounded-$index'),
      );
      expect(result.isReady, isTrue, reason: 'index $index');
    }
    final capacity = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.readTimerStatus('beyond-capacity'),
    );
    final oldReplay = owned.bridge.prepareReview(
      const HavenSystemIntentDraft.readTimerStatus('bounded-0'),
    );

    expect(
      capacity.status,
      HavenSystemIntentReviewPreparationStatus.capacityReached,
    );
    expect(
      capacity.rejectionReason,
      HavenSystemIntentReviewRejectionReason.capacityReached,
    );
    expect(oldReplay.status, HavenSystemIntentReviewPreparationStatus.replayed);
  });

  test('duplicate or malformed proposal identifiers fail closed', () async {
    final duplicate = await fixture(idGenerator: () => 'same-proposal');
    final first = duplicate.bridge
        .prepareReview(
          const HavenSystemIntentDraft.readTimerStatus('first-invocation'),
        )
        .review!;
    final repeatedId = duplicate.bridge.prepareReview(
      const HavenSystemIntentDraft.openFocusQueue('second-invocation'),
    );

    expect(repeatedId.status, HavenSystemIntentReviewPreparationStatus.invalid);
    expect(
      repeatedId.rejectionReason,
      HavenSystemIntentReviewRejectionReason.invalidDraft,
    );
    expect(
      (await duplicate.bridge.confirm(first)).status,
      HavenSystemIntentReviewSettlementStatus.staleReview,
    );

    final malformed = await fixture(idGenerator: () => 'private text');
    expect(
      malformed.bridge
          .prepareReview(
            const HavenSystemIntentDraft.readTimerStatus('valid-invocation'),
          )
          .status,
      HavenSystemIntentReviewPreparationStatus.invalid,
    );
  });

  test('policy admits only the exact confirmed five-route shape', () async {
    final owned = await fixture();
    final state = owned.engine.snapshot();
    final policy = HavenActionPolicy();

    HavenActionProposal proposal({
      HavenActionKind kind = HavenActionKind.startTimer,
      HavenActionArguments arguments = const HavenActionArguments.start(
        HavenSessionKind.focus,
      ),
      HavenActionRisk risk = HavenActionRisk.reversibleControl,
      bool confirmationRequired = true,
      bool safeUndoAvailable = true,
      Duration lifetime = HavenActionPolicy.systemIntentProposalLifetime,
    }) => HavenActionProposal(
      schemaVersion: 1,
      id: 'forged-shape',
      source: HavenActionSource.systemIntent,
      kind: kind,
      arguments: arguments,
      interpretation: 'Review one bounded action',
      effect: 'Apply it only through the current owner.',
      stateToken: state.token,
      createdAtUtc: owned.now,
      expiresAtUtc: owned.now.add(lifetime),
      risk: risk,
      confirmationRequired: confirmationRequired,
      safeUndoAvailable: safeUndoAvailable,
    );

    expect(
      policy
          .evaluate(proposal: proposal(), state: state, nowUtc: owned.now)
          .allowed,
      isTrue,
    );
    for (final invalid in <HavenActionProposal>[
      proposal(confirmationRequired: false),
      proposal(safeUndoAvailable: false),
      proposal(lifetime: const Duration(minutes: 3)),
      proposal(
        arguments: const HavenActionArguments.start(
          HavenSessionKind.shortBreak,
        ),
      ),
      proposal(
        kind: HavenActionKind.addTime,
        arguments: const HavenActionArguments.addTime(300),
      ),
      proposal(
        kind: HavenActionKind.openSurface,
        arguments: const HavenActionArguments.open(HavenActionSurface.settings),
        risk: HavenActionRisk.informational,
      ),
    ]) {
      final decision = policy.evaluate(
        proposal: invalid,
        state: state,
        nowUtc: owned.now,
      );
      expect(decision.allowed, isFalse);
      expect(decision.reason, HavenActionReason.invalidProposal);
    }
  });
}

final class _Fixture {
  const _Fixture({
    required this.timer,
    required this.queue,
    required this.executor,
    required this.engine,
    required this.bridge,
    required this.now,
  });

  final TimerService timer;
  final FocusQueueService queue;
  final HavenActionExecutor executor;
  final HavenActionEngine engine;
  final HavenSystemIntentReviewService bridge;
  final DateTime now;
}
