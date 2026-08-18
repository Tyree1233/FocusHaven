import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_window_platform_bridge.dart';
import 'package:focushaven/widgets/haven_window_platform_host.dart';

void main() {
  testWidgets('disabled hosts never read or request calendar access', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          havenWindowPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const HavenWindowPlatformHost(enabled: false, child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(backend.operations, isEmpty);
  });

  testWidgets('iOS starts with one non-prompting availability read', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final backend = _RecordingHostBackend();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            havenWindowPlatformBackendProvider.overrideWithValue(backend),
          ],
          child: const HavenWindowPlatformHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(backend.operations, ['read']);
      expect(backend.operations, isNot(contains('request')));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android starts with one non-prompting availability read', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final backend = _RecordingHostBackend();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            havenWindowPlatformBackendProvider.overrideWithValue(backend),
          ],
          child: const HavenWindowPlatformHost(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(backend.operations, ['read']);
      expect(backend.operations, isNot(contains('request')));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('unreviewed platforms leave the calendar bridge dormant', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final backend = _RecordingHostBackend();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            havenWindowPlatformBackendProvider.overrideWithValue(backend),
          ],
          child: const HavenWindowPlatformHost(child: SizedBox()),
        ),
      );
      await tester.pump();

      expect(backend.operations, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an explicitly enabled host still cannot request permission', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          havenWindowPlatformBackendProvider.overrideWithValue(backend),
        ],
        child: const HavenWindowPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(backend.operations, ['read']);
  });

  testWidgets('host disposal closes its private controller session', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    final controller = HavenWindowPlatformController(backend: backend);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          havenWindowPlatformControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const HavenWindowPlatformHost(enabled: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(controller.isStarted, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(controller.isStarted, isFalse);
    expect(await controller.refreshAvailability(), isFalse);
    expect(backend.operations, ['read']);
  });
}

final class _RecordingHostBackend implements HavenWindowPlatformBackend {
  final List<String> operations = [];

  @override
  Future<Map<String, Object?>> readAvailability() async {
    operations.add('read');
    return {'schemaVersion': 1, 'status': 'disconnected'};
  }

  @override
  Future<Map<String, Object?>> requestReadOnlyAccess() async {
    operations.add('request');
    return {'schemaVersion': 1, 'status': 'denied'};
  }
}
