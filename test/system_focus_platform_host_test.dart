import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/system_focus_platform_bridge.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/system_focus_platform_host.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('disabled hosts never install or publish a native bridge', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: false, child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(backend.handler, isNull);
    expect(backend.published, isEmpty);
  });

  testWidgets('enabled Android host publishes controls without private text', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    final timer = TimerService();
    await timer.initialized;
    timer.setFocusTask('Private launch details');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerServiceProvider.overrideWith((ref) => timer),
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(backend.handler, isNotNull);
    expect(backend.published, hasLength(1));
    expect(backend.published.single['activity'], 'ready');
    expect(backend.published.single.toString(), isNot(contains('Private')));

    timer.start();
    await tester.pump();
    await tester.pump();
    timer.pause();

    expect(backend.published.last['activity'], 'running');
    expect(backend.published.last['endsAt'], isNotNull);
  });

  testWidgets('iOS enables its strict native snapshot adapter by default', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final backend = _RecordingHostBackend();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemFocusPlatformBackendProvider.overrideWithValue(backend),
          ],
          child: const SystemFocusPlatformHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(backend.handler, isNotNull);
      expect(backend.published, hasLength(1));
      expect(backend.published.single.keys, isNot(contains('focusTask')));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native sync waits for restored timer initialization', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    final restoration = Completer<void>();
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerServiceProvider.overrideWith((ref) => timer),
          timerInitializationProvider.overrideWithValue(restoration.future),
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(backend.handler, isNull);
    expect(backend.published, isEmpty);

    restoration.complete();
    await tester.pump();
    await tester.pump();

    expect(backend.handler, isNotNull);
    expect(backend.published, hasLength(1));
  });

  testWidgets('bounded cold recovery publishes one pending-resume snapshot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 120,
      'secondsRemaining': 90,
      'totalSessionSeconds': 120,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
    });
    final timer = TimerService();
    await timer.initialized;
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerServiceProvider.overrideWith((ref) => timer),
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(backend.handler, isNotNull);
    expect(backend.published, hasLength(1));
    expect(backend.published.single['activity'], 'pendingResume');
    expect(backend.published.single['secondsRemaining'], 120);
    expect(backend.published.single['totalSessionSeconds'], 120);
    expect(backend.published.single['endsAt'], isNull);
  });

  testWidgets('legacy completed storage republishes a completed snapshot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1500,
      'secondsRemaining': 0,
      'totalSessionSeconds': 1500,
      'sessionType': SessionType.focus.index,
    });
    final timer = TimerService();
    await timer.initialized;
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerServiceProvider.overrideWith((ref) => timer),
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(timer.isComplete, isTrue);
    expect(backend.handler, isNotNull);
    expect(backend.published, hasLength(1));
    expect(backend.published.single['activity'], 'completed');
    expect(backend.published.single['secondsRemaining'], 0);
    expect(backend.published.single['endsAt'], isNull);
  });

  testWidgets('host disposal removes the native command handler', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemFocusPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const SystemFocusPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(backend.handler, isNotNull);

    await tester.pumpWidget(const SizedBox());

    expect(backend.handler, isNull);
  });
}

final class _RecordingHostBackend implements SystemFocusPlatformBackend {
  SystemFocusPlatformCommandHandler? handler;
  final List<Map<String, Object?>> published = [];

  @override
  Future<void> publishSnapshot(Map<String, Object?> snapshot) async {
    published.add(Map.unmodifiable(snapshot));
  }

  @override
  void setCommandHandler(SystemFocusPlatformCommandHandler? handler) {
    this.handler = handler;
  }
}
