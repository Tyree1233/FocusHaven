import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/system_focus_snapshot.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/system_focus_surface_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  const service = SystemFocusSurfaceService();
  final generatedAt = DateTime.utc(2026, 8, 16, 18);

  SystemFocusSnapshot snapshot({
    SessionType sessionType = SessionType.focus,
    bool isRunning = false,
    bool isComplete = false,
    bool hasPendingResume = false,
    int secondsRemaining = 25 * 60,
    int totalSessionSeconds = 25 * 60,
  }) => service.createSnapshot(
    sessionType: sessionType,
    isRunning: isRunning,
    isComplete: isComplete,
    hasPendingResume: hasPendingResume,
    secondsRemaining: secondsRemaining,
    totalSessionSeconds: totalSessionSeconds,
    generatedAt: generatedAt,
  );

  test('ready surfaces expose only a safe start command', () {
    final state = snapshot();

    expect(state.session, SystemFocusSession.focus);
    expect(state.activity, SystemFocusActivity.ready);
    expect(state.availableActions, {SystemFocusAction.start});
    expect(state.endsAt, isNull);
    expect(state.progress, 0);
  });

  test('running surfaces receive one matching UTC deadline', () {
    final state = snapshot(isRunning: true, secondsRemaining: 83);

    expect(state.activity, SystemFocusActivity.running);
    expect(state.availableActions, {
      SystemFocusAction.pause,
      SystemFocusAction.reset,
    });
    expect(state.generatedAt, generatedAt);
    expect(state.endsAt, generatedAt.add(const Duration(seconds: 83)));
  });

  test('paused sessions can resume or reset without becoming ready', () {
    final state = snapshot(secondsRemaining: 1200);

    expect(state.activity, SystemFocusActivity.paused);
    expect(state.availableActions, {
      SystemFocusAction.resume,
      SystemFocusAction.reset,
    });
  });

  test('completed sessions expose only the next-session command', () {
    final state = snapshot(isComplete: true, secondsRemaining: 0);

    expect(state.activity, SystemFocusActivity.completed);
    expect(state.progress, 1);
    expect(state.availableActions, {SystemFocusAction.beginNextSession});
  });

  test('pending recovery offers explicit resume and discard commands', () {
    final state = snapshot(hasPendingResume: true, secondsRemaining: 600);

    expect(state.activity, SystemFocusActivity.pendingResume);
    expect(state.availableActions, {
      SystemFocusAction.resume,
      SystemFocusAction.discardPending,
    });
  });

  test('every timer session maps to one stable surface value', () {
    expect(
      snapshot(sessionType: SessionType.focus).session,
      SystemFocusSession.focus,
    );
    expect(
      snapshot(
        sessionType: SessionType.shortBreak,
        secondsRemaining: 300,
        totalSessionSeconds: 300,
      ).session,
      SystemFocusSession.shortBreak,
    );
    expect(
      snapshot(
        sessionType: SessionType.longBreak,
        secondsRemaining: 900,
        totalSessionSeconds: 900,
      ).session,
      SystemFocusSession.longBreak,
    );
  });

  test('serialized snapshots contain only the versioned bounded contract', () {
    final json = snapshot(isRunning: true).toJson();

    expect(json.keys, {
      'schemaVersion',
      'session',
      'activity',
      'secondsRemaining',
      'totalSessionSeconds',
      'generatedAt',
      'endsAt',
    });
    expect(json.values.whereType<String>(), isNot(contains('private task')));
  });

  test('serialized snapshots round trip with UTC timestamps', () {
    final original = snapshot(isRunning: true, secondsRemaining: 42);

    final restored = SystemFocusSnapshot.fromJson(original.toJson());

    expect(restored.session, original.session);
    expect(restored.activity, original.activity);
    expect(restored.secondsRemaining, original.secondsRemaining);
    expect(restored.totalSessionSeconds, original.totalSessionSeconds);
    expect(restored.generatedAt, original.generatedAt);
    expect(restored.generatedAt.isUtc, isTrue);
    expect(restored.endsAt, original.endsAt);
  });

  test('unknown fields and schema versions fail closed', () {
    final unknownField = snapshot().toJson()..['task'] = 'private task';
    final futureSchema = snapshot().toJson()..['schemaVersion'] = 2;

    expect(
      () => SystemFocusSnapshot.fromJson(unknownField),
      throwsFormatException,
    );
    expect(
      () => SystemFocusSnapshot.fromJson(futureSchema),
      throwsFormatException,
    );
  });

  test('malformed timestamps and durations fail closed', () {
    final localTimestamp = snapshot().toJson()
      ..['generatedAt'] = '2026-08-16T18:00:00';
    final oversized = snapshot().toJson()
      ..['secondsRemaining'] = SystemFocusSnapshot.maximumSessionSeconds + 1
      ..['totalSessionSeconds'] = SystemFocusSnapshot.maximumSessionSeconds + 1;

    expect(
      () => SystemFocusSnapshot.fromJson(localTimestamp),
      throwsFormatException,
    );
    expect(
      () => SystemFocusSnapshot.fromJson(oversized),
      throwsFormatException,
    );
  });

  test('impossible timer states are rejected before publication', () {
    expect(
      () => snapshot(isRunning: true, isComplete: true, secondsRemaining: 0),
      throwsArgumentError,
    );
    expect(
      () => snapshot(isComplete: true, hasPendingResume: true),
      throwsArgumentError,
    );
  });

  test('Riverpod composes a text-free snapshot from narrow timer state', () {
    const session = (
      sessionType: SessionType.focus,
      isRunning: true,
      isComplete: false,
      hasPendingResume: false,
      focusTask: 'Private launch plan',
      parkedThoughtCount: 4,
      completionMessage: 'Private completion text',
      completedFocusSessionFit: null,
    );
    const countdown = (
      secondsRemaining: 90,
      totalSessionSeconds: 300,
      progress: 0.7,
    );
    final container = ProviderContainer(
      overrides: [
        timerSessionStateProvider.overrideWithValue(session),
        timerCountdownStateProvider.overrideWithValue(countdown),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(systemFocusSnapshotProvider);
    final jsonText = state.toJson().toString();

    expect(state.activity, SystemFocusActivity.running);
    expect(state.secondsRemaining, 90);
    expect(jsonText, isNot(contains('Private launch plan')));
    expect(jsonText, isNot(contains('Private completion text')));
    expect(state.toJson(), isNot(contains('parkedThoughtCount')));
  });
}
