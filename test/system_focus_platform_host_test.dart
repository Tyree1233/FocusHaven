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
