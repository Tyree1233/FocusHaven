import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/system_focus_command.dart';
import 'package:focushaven/models/system_focus_snapshot.dart';
import 'package:focushaven/services/system_focus_command_router.dart';
import 'package:focushaven/services/system_focus_platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final generatedAt = DateTime.utc(2026, 8, 16, 21);

  SystemFocusSnapshot snapshot({
    SystemFocusActivity activity = SystemFocusActivity.ready,
    DateTime? at,
    int? remaining,
    DateTime? deadline,
  }) {
    final snapshotTime = at ?? generatedAt;
    final secondsRemaining = activity == SystemFocusActivity.completed
        ? 0
        : remaining ?? 300;
    return SystemFocusSnapshot(
      session: SystemFocusSession.focus,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: 300,
      generatedAt: snapshotTime,
      endsAt: activity == SystemFocusActivity.running
          ? deadline ?? snapshotTime.add(Duration(seconds: secondsRemaining))
          : null,
    );
  }

  SystemFocusCommand command({
    SystemFocusAction action = SystemFocusAction.start,
    DateTime? snapshotGeneratedAt,
  }) => SystemFocusCommand(
    requestId: 'request_0001',
    action: action,
    snapshotGeneratedAt: snapshotGeneratedAt ?? generatedAt,
  );

  test(
    'method channel backend publishes only the approved method and map',
    () async {
      const channel = MethodChannel('com.focushaven/test_system_focus');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final backend = MethodChannelSystemFocusBackend(channel: channel);
      final approved = snapshot().toJson();

      await backend.publishSnapshot(approved);

      expect(calls, hasLength(1));
      expect(
        calls.single.method,
        MethodChannelSystemFocusBackend.publishMethod,
      );
      expect(calls.single.arguments, approved);
    },
  );

  test(
    'bridge stays dormant until a native host explicitly starts it',
    () async {
      final backend = _RecordingPlatformBackend();
      final bridge = _bridge(backend: backend, readSnapshot: snapshot);

      expect(bridge.isStarted, isFalse);
      expect(await bridge.publishCurrent(), isFalse);
      expect(backend.handler, isNull);
      expect(backend.published, isEmpty);
    },
  );

  test(
    'startup installs the handler and publishes the current snapshot',
    () async {
      final backend = _RecordingPlatformBackend();
      final bridge = _bridge(backend: backend, readSnapshot: snapshot);

      expect(await bridge.start(), isTrue);

      expect(bridge.isStarted, isTrue);
      expect(backend.handler, isNotNull);
      expect(backend.published, [snapshot().toJson()]);
    },
  );

  test('failed initial publication disables native command handling', () async {
    final backend = _RecordingPlatformBackend(
      publishError: StateError('native adapter unavailable'),
    );
    final bridge = _bridge(backend: backend, readSnapshot: snapshot);

    expect(await bridge.start(), isFalse);

    expect(bridge.isStarted, isFalse);
    expect(backend.handler, isNull);
    expect(await bridge.publishCurrent(), isFalse);
  });

  test(
    'valid native commands mutate once and publish the resulting state',
    () async {
      final backend = _RecordingPlatformBackend();
      var current = snapshot();
      final calls = <String>[];
      late final SystemFocusPlatformBridge bridge;
      bridge = SystemFocusPlatformBridge(
        backend: backend,
        router: SystemFocusCommandRouter(),
        readSnapshot: () => current,
        target: _target(
          calls,
          start: () {
            current = snapshot(
              activity: SystemFocusActivity.running,
              at: generatedAt.add(const Duration(seconds: 1)),
            );
          },
        ),
      );
      expect(await bridge.start(), isTrue);

      final accepted = await backend.handler!(command().toJson());

      expect(accepted, isTrue);
      expect(calls, ['start']);
      expect(backend.published, hasLength(2));
      expect(backend.published.last['activity'], 'running');
      expect(
        backend.published.last['generatedAt'],
        current.generatedAt.toIso8601String(),
      );
    },
  );

  test(
    'one running deadline skips ticks while its published command stays valid',
    () async {
      final backend = _RecordingPlatformBackend();
      var current = snapshot(activity: SystemFocusActivity.running);
      final publishedAt = current.generatedAt;
      final deadline = current.endsAt!;
      final calls = <String>[];
      final bridge = SystemFocusPlatformBridge(
        backend: backend,
        router: SystemFocusCommandRouter(),
        readSnapshot: () => current,
        target: _target(
          calls,
          pause: () {
            current = snapshot(
              activity: SystemFocusActivity.paused,
              at: generatedAt.add(const Duration(seconds: 11)),
              remaining: 290,
            );
          },
        ),
      );
      expect(await bridge.start(), isTrue);
      current = snapshot(
        activity: SystemFocusActivity.running,
        at: generatedAt.add(const Duration(seconds: 10)),
        remaining: 290,
        deadline: deadline,
      );

      expect(await bridge.publishCurrent(), isTrue);
      expect(backend.published, hasLength(1));

      final accepted = await backend.handler!(
        command(
          action: SystemFocusAction.pause,
          snapshotGeneratedAt: publishedAt,
        ).toJson(),
      );

      expect(accepted, isTrue);
      expect(calls, ['pause']);
      expect(backend.published, hasLength(2));
      expect(backend.published.last['activity'], 'paused');
    },
  );

  test('malformed stale and unavailable commands remain contained', () async {
    final backend = _RecordingPlatformBackend();
    final calls = <String>[];
    final bridge = _bridge(
      backend: backend,
      readSnapshot: snapshot,
      calls: calls,
    );
    expect(await bridge.start(), isTrue);

    final malformed = await backend.handler!({
      'schemaVersion': 1,
      'requestId': 'request_0001',
    });
    final stale = await backend.handler!(
      command(
        snapshotGeneratedAt: generatedAt.subtract(const Duration(seconds: 1)),
      ).toJson(),
    );
    final unavailable = await backend.handler!(
      command(action: SystemFocusAction.pause).toJson(),
    );

    expect(malformed, isFalse);
    expect(stale, isFalse);
    expect(unavailable, isFalse);
    expect(calls, isEmpty);
    expect(backend.published, hasLength(1));
  });

  test('overlapping publications preserve snapshot order', () async {
    final backend = _RecordingPlatformBackend();
    final bridge = _bridge(backend: backend, readSnapshot: snapshot);
    expect(await bridge.start(), isTrue);
    final gate = Completer<void>();
    backend.publishGate = gate.future;
    final second = snapshot(
      activity: SystemFocusActivity.paused,
      at: generatedAt.add(const Duration(seconds: 1)),
    );
    final third = snapshot(
      activity: SystemFocusActivity.ready,
      at: generatedAt.add(const Duration(seconds: 2)),
    );

    final secondPublish = bridge.publish(second);
    final thirdPublish = bridge.publish(third);
    await Future<void>.delayed(Duration.zero);

    expect(backend.maximumConcurrentPublishes, 1);
    gate.complete();
    expect(await secondPublish, isTrue);
    expect(await thirdPublish, isTrue);
    expect(backend.published.map((entry) => entry['generatedAt']), [
      generatedAt.toIso8601String(),
      second.generatedAt.toIso8601String(),
      third.generatedAt.toIso8601String(),
    ]);
  });

  test('dispose clears the handler and prevents later publication', () async {
    final backend = _RecordingPlatformBackend();
    final bridge = _bridge(backend: backend, readSnapshot: snapshot);
    expect(await bridge.start(), isTrue);

    bridge.dispose();

    expect(bridge.isStarted, isFalse);
    expect(backend.handler, isNull);
    expect(await bridge.publishCurrent(), isFalse);
    expect(await bridge.start(), isFalse);
  });
}

SystemFocusPlatformBridge _bridge({
  required _RecordingPlatformBackend backend,
  required SystemFocusSnapshot Function() readSnapshot,
  List<String>? calls,
}) {
  final recordedCalls = calls ?? <String>[];
  return SystemFocusPlatformBridge(
    backend: backend,
    router: SystemFocusCommandRouter(),
    readSnapshot: readSnapshot,
    target: _target(recordedCalls),
  );
}

SystemFocusCommandTarget _target(
  List<String> calls, {
  void Function()? start,
  void Function()? pause,
}) => (
  start: () {
    calls.add('start');
    start?.call();
  },
  pause: () {
    calls.add('pause');
    pause?.call();
  },
  resumePending: () => calls.add('resumePending'),
  reset: () => calls.add('reset'),
  beginNextSession: () => calls.add('beginNextSession'),
  discardPending: () => calls.add('discardPending'),
);

final class _RecordingPlatformBackend implements SystemFocusPlatformBackend {
  _RecordingPlatformBackend({this.publishError});

  final Object? publishError;
  SystemFocusPlatformCommandHandler? handler;
  Future<void>? publishGate;
  final List<Map<String, Object?>> published = [];
  int _activePublishes = 0;
  int maximumConcurrentPublishes = 0;

  @override
  void setCommandHandler(SystemFocusPlatformCommandHandler? handler) {
    this.handler = handler;
  }

  @override
  Future<void> publishSnapshot(Map<String, Object?> snapshot) async {
    _activePublishes += 1;
    if (_activePublishes > maximumConcurrentPublishes) {
      maximumConcurrentPublishes = _activePublishes;
    }
    try {
      final error = publishError;
      if (error != null) throw error;
      final gate = publishGate;
      if (gate != null) await gate;
      published.add(Map.unmodifiable(snapshot));
    } finally {
      _activePublishes -= 1;
    }
  }
}
