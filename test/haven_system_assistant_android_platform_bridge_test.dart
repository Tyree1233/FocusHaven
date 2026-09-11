import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/services/haven_system_assistant_android_platform_bridge.dart';
import 'package:focushaven/services/haven_system_intent_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'method channel requests delivery with only the schema version',
    () async {
      const channel = MethodChannel(
        'com.focushaven/test_system_assistant_android',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final backend = MethodChannelHavenSystemAssistantAndroidBackend(
        channel: channel,
      );

      expect(await backend.requestPendingDelivery(), isTrue);
      expect(calls, hasLength(1));
      expect(
        calls.single.method,
        MethodChannelHavenSystemAssistantAndroidBackend
            .requestPendingDeliveryMethod,
      );
      expect(calls.single.arguments, {'schemaVersion': 1});
      expect(calls.single.arguments.toString(), isNot(contains('transcript')));
      expect(calls.single.arguments.toString(), isNot(contains('utterance')));
      expect(calls.single.arguments.toString(), isNot(contains('task')));
    },
  );

  test('all five exact native routes enter only the memory inbox', () async {
    const routes = <String, HavenSystemIntentKind>{
      'readTimerStatus': HavenSystemIntentKind.readTimerStatus,
      'startFocusTimer': HavenSystemIntentKind.startFocusTimer,
      'pauseTimer': HavenSystemIntentKind.pauseTimer,
      'resumeTimer': HavenSystemIntentKind.resumeTimer,
      'openFocusQueue': HavenSystemIntentKind.openFocusQueue,
    };

    for (final entry in routes.entries) {
      final backend = _RecordingAndroidBackend();
      final inbox = HavenSystemIntentInbox();
      final controller = HavenSystemAssistantAndroidPlatformController(
        backend: backend,
        inbox: inbox,
      );
      addTearDown(controller.dispose);
      addTearDown(inbox.dispose);

      expect(await controller.start(), isTrue);
      expect(
        await backend.deliver({
          'schemaVersion': 1,
          'invocationId': 'android-${entry.key}',
          'kind': entry.key,
        }),
        isTrue,
      );

      final request = inbox.takePendingRequest();
      expect(request, isNotNull);
      expect(request!.schemaVersion, 1);
      expect(request.invocationId, 'android-${entry.key}');
      expect(request.kind, entry.value);
    }
  });

  test(
    'extra, malformed, private, and unsupported payloads fail closed',
    () async {
      final invalid = <Map<String, Object?>>[
        {
          'schemaVersion': 1,
          'invocationId': 'extra-field',
          'kind': 'pauseTimer',
          'transcript': 'Pause my private timer',
        },
        {
          'schemaVersion': 2,
          'invocationId': 'wrong-schema',
          'kind': 'pauseTimer',
        },
        {
          'schemaVersion': 1,
          'invocationId': ' contains-space',
          'kind': 'pauseTimer',
        },
        {
          'schemaVersion': 1,
          'invocationId': 'unknown-route',
          'kind': 'stopTimer',
        },
        {
          'schemaVersion': 1,
          'invocationId': 'free-form-parameter',
          'kind': 'startFocusTimer',
          'duration': 90,
        },
      ];

      for (final payload in invalid) {
        final backend = _RecordingAndroidBackend();
        final inbox = HavenSystemIntentInbox();
        final controller = HavenSystemAssistantAndroidPlatformController(
          backend: backend,
          inbox: inbox,
        );
        expect(await controller.start(), isTrue);
        expect(await backend.deliver(payload), isFalse);
        expect(inbox.takePendingRequest(), isNull);
        controller.dispose();
        inbox.dispose();
      }
    },
  );

  test('an occupied app inbox refuses native acknowledgement', () async {
    final backend = _RecordingAndroidBackend();
    final inbox = HavenSystemIntentInbox();
    final controller = HavenSystemAssistantAndroidPlatformController(
      backend: backend,
      inbox: inbox,
    );
    addTearDown(controller.dispose);
    addTearDown(inbox.dispose);
    expect(await controller.start(), isTrue);
    expect(
      inbox.submit(
        const HavenSystemIntentRequest(
          schemaVersion: 1,
          invocationId: 'already-pending',
          kind: HavenSystemIntentKind.readTimerStatus,
        ),
      ),
      isTrue,
    );

    expect(
      await backend.deliver({
        'schemaVersion': 1,
        'invocationId': 'native-pending',
        'kind': 'pauseTimer',
      }),
      isFalse,
    );
    expect(inbox.takePendingRequest()!.invocationId, 'already-pending');
  });

  test('delivery polling is serialized and disposal closes the seam', () async {
    final backend = _RecordingAndroidBackend();
    final inbox = HavenSystemIntentInbox();
    final controller = HavenSystemAssistantAndroidPlatformController(
      backend: backend,
      inbox: inbox,
    );
    addTearDown(inbox.dispose);
    final gate = Completer<void>();
    backend.deliveryGate = gate.future;

    final start = controller.start();
    final overlappingRefresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(backend.deliveryRequests, 1);
    expect(await overlappingRefresh, isFalse);
    gate.complete();
    expect(await start, isTrue);

    controller.dispose();
    expect(backend.handler, isNull);
    expect(await controller.refresh(), isFalse);
    expect(await controller.start(), isFalse);
  });
}

final class _RecordingAndroidBackend
    implements HavenSystemAssistantAndroidPlatformBackend {
  HavenSystemAssistantAndroidRequestHandler? handler;
  Future<void>? deliveryGate;
  int deliveryRequests = 0;

  @override
  void setRequestHandler(HavenSystemAssistantAndroidRequestHandler? handler) {
    this.handler = handler;
  }

  @override
  Future<bool> requestPendingDelivery() async {
    deliveryRequests += 1;
    final gate = deliveryGate;
    if (gate != null) await gate;
    return false;
  }

  Future<bool> deliver(Map<String, Object?> value) async {
    final activeHandler = handler;
    if (activeHandler == null) return false;
    return activeHandler(value);
  }
}
