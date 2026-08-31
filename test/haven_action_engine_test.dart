import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_engine.dart';
import 'package:focushaven/services/haven_action_interpreter.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<({TimerService timer, FocusQueueService queue})> services() async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    return (timer: timer, queue: queue);
  }

  HavenActionInterpreter interpreter(DateTime now, String id) =>
      HavenActionInterpreter(clock: () => now, idGenerator: () => id);

  HavenActionProposal proposal(
    HavenActionInterpreter interpreter,
    HavenActionExecutor executor,
    String input, {
    HavenActionSource source = HavenActionSource.typed,
  }) => interpreter
      .interpret(input, executor.snapshot(), source: source)
      .proposal!;

  test('executes through the timer service and prevents replay', () async {
    final owned = await services();
    final now = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final action = proposal(
      interpreter(now, 'start-once'),
      executor,
      'start focus',
    );
    final actionEngine = HavenActionEngine(
      executor: executor,
      clock: () => now,
    );

    final first = await actionEngine.execute(action);
    final second = await actionEngine.execute(action);

    expect(first.executed, isTrue);
    expect(owned.timer.isRunning, isTrue);
    expect(second.executed, isFalse);
    expect(second.receipt.reason, HavenActionReason.duplicateProposal);
  });

  test('voice transcripts use the same state and replay policy', () async {
    final owned = await services();
    final now = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final action = proposal(
      interpreter(now, 'voice-start-once'),
      executor,
      'start focus',
      source: HavenActionSource.voiceTranscript,
    );
    final actionEngine = HavenActionEngine(
      executor: executor,
      clock: () => now,
    );

    expect(action.source, HavenActionSource.voiceTranscript);
    final first = await actionEngine.execute(action);
    final second = await actionEngine.execute(action);

    expect(first.executed, isTrue);
    expect(owned.timer.isRunning, isTrue);
    expect(second.executed, isFalse);
    expect(second.receipt.reason, HavenActionReason.duplicateProposal);
  });

  test('rejects a proposal when its reviewed control state is stale', () async {
    final owned = await services();
    final now = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final action = proposal(
      interpreter(now, 'stale-start'),
      executor,
      'start focus',
    );
    owned.timer.selectSession(SessionType.shortBreak);

    final result = await HavenActionEngine(
      executor: executor,
      clock: () => now,
    ).execute(action);

    expect(result.executed, isFalse);
    expect(result.receipt.reason, HavenActionReason.staleProposal);
    expect(owned.timer.isRunning, isFalse);
  });

  test('binds a queue edit to the exact reviewed confirmation', () async {
    final owned = await services();
    final now = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final missingAction = proposal(
      interpreter(now, 'queue-missing'),
      executor,
      'add task: Review the launch checklist',
    );
    final mismatchedAction = proposal(
      interpreter(now, 'queue-mismatched'),
      executor,
      'add task: Review the launch checklist',
    );
    final acceptedAction = proposal(
      interpreter(now, 'queue-accepted'),
      executor,
      'add task: Review the launch checklist',
    );
    final actionEngine = HavenActionEngine(
      executor: executor,
      clock: () => now,
    );

    final missing = await actionEngine.execute(missingAction);
    final mismatched = await actionEngine.execute(
      mismatchedAction,
      confirmation: HavenActionConfirmation(
        proposalId: mismatchedAction.id,
        proposalFingerprint: 'different-proposal',
        confirmedAtUtc: now,
      ),
    );

    expect(missing.receipt.reason, HavenActionReason.confirmationRequired);
    expect(mismatched.receipt.reason, HavenActionReason.confirmationMismatch);
    expect(owned.queue.items, isEmpty);

    final accepted = await actionEngine.execute(
      acceptedAction,
      confirmation: HavenActionConfirmation.forProposal(
        acceptedAction,
        confirmedAtUtc: now,
      ),
    );

    expect(accepted.executed, isTrue);
    expect(owned.queue.items.single.title, 'Review the launch checklist');
    expect(accepted.receipt.kind, HavenActionKind.draftQueueItem);
    expect(accepted.receipt.outcome, HavenActionOutcome.executed);
  });

  test('consumes rejected and expired execution attempts', () async {
    final owned = await services();
    final createdAt = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final action = proposal(
      interpreter(createdAt, 'expired-once'),
      executor,
      'start focus',
    );
    final actionEngine = HavenActionEngine(
      executor: executor,
      clock: () => createdAt.add(const Duration(minutes: 3)),
    );

    final expired = await actionEngine.execute(action);
    final replay = await actionEngine.execute(action);

    expect(expired.executed, isFalse);
    expect(expired.receipt.reason, HavenActionReason.expiredProposal);
    expect(replay.executed, isFalse);
    expect(replay.receipt.reason, HavenActionReason.duplicateProposal);
    expect(owned.timer.isRunning, isFalse);
  });

  test('adds bounded time without changing a ready timer', () async {
    final owned = await services();
    final now = DateTime.utc(2026, 8, 30, 18);
    final executor = HavenActionExecutor(
      timer: owned.timer,
      focusQueue: owned.queue,
      openSurface: (_) async => true,
    );
    final readyAction = proposal(
      interpreter(now, 'ready-add'),
      executor,
      'add 5 minutes',
    );
    final readyResult = await HavenActionEngine(
      executor: executor,
      clock: () => now,
    ).execute(readyAction);

    expect(readyResult.executed, isFalse);
    expect(owned.timer.totalSessionSeconds, 1500);

    owned.timer.start();
    final runningAction = proposal(
      interpreter(now, 'running-add'),
      executor,
      'add 5 minutes',
    );
    final runningResult = await HavenActionEngine(
      executor: executor,
      clock: () => now,
    ).execute(runningAction);

    expect(runningResult.executed, isTrue);
    expect(owned.timer.totalSessionSeconds, 1800);
    expect(owned.timer.secondsRemaining, inInclusiveRange(1799, 1800));
  });
}
