import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_system_assistant_android_platform_bridge.dart';
import 'package:focushaven/widgets/haven_system_assistant_android_platform_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android starts one private delivery session', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final backend = _RecordingHostBackend();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            havenSystemAssistantAndroidPlatformBackendProvider
                .overrideWithValue(backend),
          ],
          child: const HavenSystemAssistantAndroidPlatformHost(
            child: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(backend.deliveryRequests, 1);
      expect(backend.handler, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple and unreviewed platforms leave the seam dormant', (
    tester,
  ) async {
    try {
      for (final platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final backend = _RecordingHostBackend();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              havenSystemAssistantAndroidPlatformBackendProvider
                  .overrideWithValue(backend),
            ],
            child: HavenSystemAssistantAndroidPlatformHost(
              key: ValueKey<TargetPlatform>(platform),
              child: const SizedBox(),
            ),
          ),
        );
        await tester.pump();

        expect(backend.deliveryRequests, 0, reason: platform.name);
        expect(backend.handler, isNull, reason: platform.name);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a resumed Android app asks native memory for delivery again', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final backend = _RecordingHostBackend();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            havenSystemAssistantAndroidPlatformBackendProvider
                .overrideWithValue(backend),
          ],
          child: const HavenSystemAssistantAndroidPlatformHost(
            child: SizedBox(),
          ),
        ),
      );
      await tester.pump();
      expect(backend.deliveryRequests, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(backend.deliveryRequests, 2);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('accepted native payload reaches the existing app inbox', (
    tester,
  ) async {
    final backend = _RecordingHostBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          havenSystemAssistantAndroidPlatformBackendProvider.overrideWithValue(
            backend,
          ),
        ],
        child: const HavenSystemAssistantAndroidPlatformHost(
          enabled: true,
          child: SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(
      await backend.handler!({
        'schemaVersion': 1,
        'invocationId': 'android-review-1',
        'kind': 'openFocusQueue',
      }),
      isTrue,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HavenSystemAssistantAndroidPlatformHost)),
      listen: false,
    );
    final request = container
        .read(havenSystemIntentInboxProvider)
        .takePendingRequest();
    expect(request!.kind, HavenSystemIntentKind.openFocusQueue);
    expect(request.invocationId, 'android-review-1');
  });

  testWidgets('disposing the host removes native delivery', (tester) async {
    final backend = _RecordingHostBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          havenSystemAssistantAndroidPlatformBackendProvider.overrideWithValue(
            backend,
          ),
        ],
        child: const HavenSystemAssistantAndroidPlatformHost(
          enabled: true,
          child: SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(backend.handler, isNotNull);

    await tester.pumpWidget(const SizedBox());
    expect(backend.handler, isNull);
  });
}

final class _RecordingHostBackend
    implements HavenSystemAssistantAndroidPlatformBackend {
  HavenSystemAssistantAndroidRequestHandler? handler;
  int deliveryRequests = 0;

  @override
  void setRequestHandler(HavenSystemAssistantAndroidRequestHandler? handler) {
    this.handler = handler;
  }

  @override
  Future<bool> requestPendingDelivery() async {
    deliveryRequests += 1;
    return false;
  }
}
