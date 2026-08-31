import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/services/haven_action_interpreter.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 18);

  HavenActionState state({
    HavenSessionKind session = HavenSessionKind.focus,
    HavenTimerActivity activity = HavenTimerActivity.running,
    int secondsRemaining = 1200,
    int totalSessionSeconds = 1500,
    int queueRevision = 0,
    bool canStartHavenPlan = false,
    bool canOfferSmartReset = true,
  }) => HavenActionState(
    session: session,
    activity: activity,
    secondsRemaining: secondsRemaining,
    totalSessionSeconds: totalSessionSeconds,
    queueRevision: queueRevision,
    canStartHavenPlan: canStartHavenPlan,
    canOfferSmartReset: canOfferSmartReset,
  );

  HavenActionInterpreter interpreter() =>
      HavenActionInterpreter(clock: () => now, idGenerator: () => 'proposal-1');

  test('creates a short-lived typed proposal for one bounded action', () {
    final result = interpreter().interpret('add 5 minutes', state());
    final proposal = result.proposal;

    expect(result.status, HavenActionInterpretationStatus.proposed);
    expect(proposal, isNotNull);
    expect(proposal!.source, HavenActionSource.typed);
    expect(proposal.kind, HavenActionKind.addTime);
    expect(proposal.arguments.durationSeconds, 300);
    expect(proposal.stateToken, state().token);
    expect(proposal.createdAtUtc, now);
    expect(proposal.expiresAtUtc, now.add(const Duration(minutes: 2)));
    expect(proposal.confirmationRequired, isFalse);
  });

  test(
    'creates the same bounded proposal from a reviewed voice transcript',
    () {
      final result = interpreter().interpret(
        'pause',
        state(),
        source: HavenActionSource.voiceTranscript,
      );

      expect(result.status, HavenActionInterpretationStatus.proposed);
      expect(result.proposal, isNotNull);
      expect(result.proposal!.source, HavenActionSource.voiceTranscript);
      expect(result.proposal!.kind, HavenActionKind.pauseTimer);
      expect(result.proposal!.stateToken, state().token);
    },
  );

  test('rejects coach and system text as action-authority sources', () {
    for (final source in <HavenActionSource>[
      HavenActionSource.localCoach,
      HavenActionSource.systemIntent,
    ]) {
      final result = interpreter().interpret('pause', state(), source: source);

      expect(result.status, HavenActionInterpretationStatus.unsupported);
      expect(result.proposal, isNull);
      expect(
        result.message,
        'That input source cannot create a Haven action proposal.',
      );
    }
  });

  test('refuses ambiguous multi-action input', () {
    final result = interpreter().interpret(
      'pause and open Focus Queue',
      state(),
    );

    expect(result.status, HavenActionInterpretationStatus.ambiguous);
    expect(result.proposal, isNull);
  });

  test(
    'rejects recognized words embedded in an unsupported larger request',
    () {
      for (final input in <String>[
        'pause the timer and send a message',
        'start focus then open the queue',
        'add 5 minutes and change settings',
        'open Focus Queue after deleting something',
      ]) {
        final result = interpreter().interpret(input, state());
        expect(result.status, isNot(HavenActionInterpretationStatus.proposed));
        expect(result.proposal, isNull);
      }
    },
  );

  test('keeps protected operations outside the action engine', () {
    for (final input in <String>[
      'delete my account',
      'reset timer',
      'enable App Check',
      'deploy the function',
      'buy a subscription',
    ]) {
      final result = interpreter().interpret(input, state());
      expect(result.status, HavenActionInterpretationStatus.unsupported);
      expect(result.proposal, isNull);
    }
  });

  test('rejects unsafe duration and queue-title bounds without clamping', () {
    final duration = interpreter().interpret('add 61 minutes', state());
    final title = interpreter().interpret(
      'add task: ${List.filled(101, 'x').join()}',
      state(),
    );

    expect(duration.proposal, isNull);
    expect(title.proposal, isNull);
    expect(duration.status, HavenActionInterpretationStatus.unsupported);
    expect(title.status, HavenActionInterpretationStatus.unsupported);
  });

  test('queue edits require exact confirmation while navigation does not', () {
    final queue = interpreter().interpret(
      'add task: Review project notes',
      state(),
    );
    final navigation = interpreter().interpret('open Focus Queue', state());

    expect(queue.proposal!.kind, HavenActionKind.draftQueueItem);
    expect(queue.proposal!.confirmationRequired, isTrue);
    expect(queue.proposal!.arguments.queueTitle, 'Review project notes');
    expect(navigation.proposal!.kind, HavenActionKind.openSurface);
    expect(navigation.proposal!.confirmationRequired, isFalse);
  });
}
