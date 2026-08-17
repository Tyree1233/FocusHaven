import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/focus_shield_state.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_shield_platform_bridge.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/focus_shield_platform_host.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('disabled hosts never install a Focus Shield adapter', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusShieldPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const FocusShieldPlatformHost(enabled: false, child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(backend.handler, isNull);
    expect(backend.protectionRequests, isEmpty);
  });

  testWidgets('iOS enables its private adapter by default', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final backend = _RecordingHostBackend();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            focusShieldPlatformBackendProvider.overrideWithValue(backend),
          ],
          child: const FocusShieldPlatformHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(backend.handler, isNotNull);
      expect(backend.protectionRequests, [false]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native sync waits for restored timer initialization', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    final restoration = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerInitializationProvider.overrideWithValue(restoration.future),
          focusShieldPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const FocusShieldPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(backend.handler, isNull);
    expect(backend.protectionRequests, isEmpty);

    restoration.complete();
    await tester.pump();
    await tester.pump();

    expect(backend.handler, isNotNull);
    expect(backend.protectionRequests, [false]);
  });

  testWidgets('running focus protects while pauses and breaks stay open', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    final timer = TimerService();
    await timer.initialized;
    timer.setFocusTask('Private acquisition plan');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerServiceProvider.overrideWith((ref) => timer),
          focusShieldPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const FocusShieldPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(backend.protectionRequests, [false]);

    timer.start();
    await tester.pump();
    await tester.pump();

    expect(backend.protectionRequests, [false, true]);
    expect(backend.protectionRequests.toString(), isNot(contains('Private')));

    timer.pause();
    await tester.pump();
    await tester.pump();

    expect(backend.protectionRequests, [false, true, false]);
  });

  testWidgets('host disposal removes native capability delivery', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusShieldPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const FocusShieldPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(backend.handler, isNotNull);

    await tester.pumpWidget(const SizedBox());

    expect(backend.handler, isNull);
  });
}

final class _RecordingHostBackend implements FocusShieldPlatformBackend {
  FocusShieldCapabilityHandler? handler;
  final List<bool> protectionRequests = [];

  Map<String, Object?> _capability({bool protecting = false}) => {
    'schemaVersion': 1,
    'isEnabled': true,
    'nativeSupportAvailable': true,
    'authorization': 'approved',
    'hasSelection': true,
    'temporarilyPaused': false,
    'nativeStatus': protecting ? 'protecting' : 'inactive',
  };

  @override
  void setCapabilityHandler(FocusShieldCapabilityHandler? handler) {
    this.handler = handler;
  }

  @override
  Future<Map<String, Object?>> readCapability() async => _capability();

  @override
  Future<Map<String, Object?>> performAction(FocusShieldAction action) async =>
      _capability();

  @override
  Future<Map<String, Object?>> setProtectionRequested(bool requested) async {
    protectionRequests.add(requested);
    return _capability(protecting: requested);
  }
}
