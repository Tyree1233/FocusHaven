import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/system_focus_command.dart';
import 'package:focushaven/models/system_focus_snapshot.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/system_focus_command_router.dart';

void main() {
  final generatedAt = DateTime.utc(2026, 8, 16, 20);

  SystemFocusSnapshot snapshot(SystemFocusActivity activity) {
    final secondsRemaining = activity == SystemFocusActivity.completed
        ? 0
        : 300;
    return SystemFocusSnapshot(
      session: SystemFocusSession.focus,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: 300,
      generatedAt: generatedAt,
      endsAt: activity == SystemFocusActivity.running
          ? generatedAt.add(Duration(seconds: secondsRemaining))
          : null,
    );
  }

  SystemFocusCommand command(
    SystemFocusAction action, {
    String requestId = 'request_0001',
    DateTime? snapshotGeneratedAt,
  }) => SystemFocusCommand(
    requestId: requestId,
    action: action,
    snapshotGeneratedAt: snapshotGeneratedAt ?? generatedAt,
  );

  test('commands serialize as one bounded text-free envelope', () {
    final original = command(SystemFocusAction.pause);
    final json = original.toJson();

    expect(json.keys, {
      'schemaVersion',
      'requestId',
      'action',
      'snapshotGeneratedAt',
    });
    expect(json.toString(), isNot(contains('task')));

    final restored = SystemFocusCommand.fromJson(json);
    expect(restored.requestId, original.requestId);
    expect(restored.action, original.action);
    expect(restored.snapshotGeneratedAt, generatedAt);
  });

  test('unknown fields and schema versions fail closed', () {
    final unknown = command(SystemFocusAction.start).toJson()
      ..['task'] = 'private task';
    final future = command(SystemFocusAction.start).toJson()
      ..['schemaVersion'] = 2;

    expect(() => SystemFocusCommand.fromJson(unknown), throwsFormatException);
    expect(() => SystemFocusCommand.fromJson(future), throwsFormatException);
  });

  test('malformed IDs actions and timestamps fail closed', () {
    expect(
      () => SystemFocusCommand(
        requestId: 'short',
        action: SystemFocusAction.start,
        snapshotGeneratedAt: generatedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => SystemFocusCommand(
        requestId: ' request_0001 ',
        action: SystemFocusAction.start,
        snapshotGeneratedAt: generatedAt,
      ),
      throwsArgumentError,
    );

    final malformedAction = command(SystemFocusAction.start).toJson()
      ..['action'] = 'deleteEverything';
    final localTimestamp = command(SystemFocusAction.start).toJson()
      ..['snapshotGeneratedAt'] = '2026-08-16T20:00:00';
    expect(
      () => SystemFocusCommand.fromJson(malformedAction),
      throwsFormatException,
    );
    expect(
      () => SystemFocusCommand.fromJson(localTimestamp),
      throwsFormatException,
    );
  });

  test('routes every action only through its advertised state', () {
    final scenarios =
        <
          ({
            SystemFocusActivity activity,
            SystemFocusAction action,
            String expectedCall,
          })
        >[
          (
            activity: SystemFocusActivity.ready,
            action: SystemFocusAction.start,
            expectedCall: 'start',
          ),
          (
            activity: SystemFocusActivity.running,
            action: SystemFocusAction.pause,
            expectedCall: 'pause',
          ),
          (
            activity: SystemFocusActivity.running,
            action: SystemFocusAction.reset,
            expectedCall: 'reset',
          ),
          (
            activity: SystemFocusActivity.paused,
            action: SystemFocusAction.resume,
            expectedCall: 'start',
          ),
          (
            activity: SystemFocusActivity.paused,
            action: SystemFocusAction.reset,
            expectedCall: 'reset',
          ),
          (
            activity: SystemFocusActivity.completed,
            action: SystemFocusAction.beginNextSession,
            expectedCall: 'beginNextSession',
          ),
          (
            activity: SystemFocusActivity.pendingResume,
            action: SystemFocusAction.resume,
            expectedCall: 'resumePending',
          ),
          (
            activity: SystemFocusActivity.pendingResume,
            action: SystemFocusAction.discardPending,
            expectedCall: 'discardPending',
          ),
        ];

    for (var index = 0; index < scenarios.length; index++) {
      final scenario = scenarios[index];
      final recorder = _RecordingTarget();
      final accepted = SystemFocusCommandRouter().execute(
        command: command(
          scenario.action,
          requestId: 'request_${index.toString().padLeft(4, '0')}',
        ),
        currentSnapshot: snapshot(scenario.activity),
        target: recorder.target,
      );

      expect(accepted, isTrue, reason: '${scenario.action} was rejected');
      expect(recorder.calls, [scenario.expectedCall]);
    }
  });

  test('stale and unavailable actions never reach the timer target', () {
    final recorder = _RecordingTarget();
    final router = SystemFocusCommandRouter();

    final staleAccepted = router.execute(
      command: command(
        SystemFocusAction.start,
        snapshotGeneratedAt: generatedAt.subtract(const Duration(seconds: 1)),
      ),
      currentSnapshot: snapshot(SystemFocusActivity.ready),
      target: recorder.target,
    );
    final unavailableAccepted = router.execute(
      command: command(SystemFocusAction.pause, requestId: 'request_0002'),
      currentSnapshot: snapshot(SystemFocusActivity.ready),
      target: recorder.target,
    );

    expect(staleAccepted, isFalse);
    expect(unavailableAccepted, isFalse);
    expect(recorder.calls, isEmpty);
  });

  test('one accepted snapshot cannot be replayed with any request ID', () {
    final recorder = _RecordingTarget();
    final router = SystemFocusCommandRouter();
    final current = snapshot(SystemFocusActivity.ready);

    expect(
      router.execute(
        command: command(SystemFocusAction.start),
        currentSnapshot: current,
        target: recorder.target,
      ),
      isTrue,
    );
    expect(
      router.execute(
        command: command(SystemFocusAction.start, requestId: 'request_0002'),
        currentSnapshot: current,
        target: recorder.target,
      ),
      isFalse,
    );
    expect(recorder.calls, ['start']);
  });

  test('callback failures are contained and remain consumed', () {
    final recorder = _RecordingTarget(failingCall: 'pause');
    final router = SystemFocusCommandRouter();
    final current = snapshot(SystemFocusActivity.running);
    final request = command(SystemFocusAction.pause);

    expect(
      router.execute(
        command: request,
        currentSnapshot: current,
        target: recorder.target,
      ),
      isFalse,
    );
    expect(
      router.execute(
        command: request,
        currentSnapshot: current,
        target: recorder.target,
      ),
      isFalse,
    );
    expect(recorder.calls, ['pause']);
  });

  test('Riverpod owns one replay-protected router per app container', () {
    final firstContainer = ProviderContainer();
    final secondContainer = ProviderContainer();
    addTearDown(firstContainer.dispose);
    addTearDown(secondContainer.dispose);

    final first = firstContainer.read(systemFocusCommandRouterProvider);

    expect(firstContainer.read(systemFocusCommandRouterProvider), same(first));
    expect(
      secondContainer.read(systemFocusCommandRouterProvider),
      isNot(same(first)),
    );
  });
}

final class _RecordingTarget {
  _RecordingTarget({this.failingCall});

  final String? failingCall;
  final List<String> calls = [];

  late final SystemFocusCommandTarget target = (
    start: () => _record('start'),
    pause: () => _record('pause'),
    resumePending: () => _record('resumePending'),
    reset: () => _record('reset'),
    beginNextSession: () => _record('beginNextSession'),
    discardPending: () => _record('discardPending'),
  );

  void _record(String call) {
    calls.add(call);
    if (failingCall == call) throw StateError('$call unavailable');
  }
}
