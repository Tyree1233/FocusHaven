import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/haven_window_suggestion.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_window_platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'method channel sends only the schema version on both operations',
    () async {
      const channel = MethodChannel('com.focushaven/test_haven_window');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return _availability();
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final backend = MethodChannelHavenWindowBackend(channel: channel);

      await backend.readAvailability();
      await backend.requestReadOnlyAccess();

      expect(calls.map((call) => call.method), [
        MethodChannelHavenWindowBackend.readAvailabilityMethod,
        MethodChannelHavenWindowBackend.requestReadOnlyAccessMethod,
      ]);
      for (final call in calls) {
        expect(call.arguments, {'schemaVersion': 1});
        expect(call.arguments.toString(), isNot(contains('title')));
        expect(call.arguments.toString(), isNot(contains('calendar')));
        expect(call.arguments.toString(), isNot(contains('attendee')));
      }
    },
  );

  test('controller stays dormant until a host starts it', () async {
    final backend = _RecordingHavenWindowBackend();
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);

    expect(controller.isStarted, isFalse);
    expect(
      controller.availability.status,
      PrivateCalendarAvailabilityStatus.unsupported,
    );
    expect(await controller.refreshAvailability(), isFalse);
    expect(await controller.requestReadOnlyAccess(), isFalse);
    expect(backend.operations, isEmpty);
  });

  test(
    'startup checks status without requesting calendar permission',
    () async {
      final backend = _RecordingHavenWindowBackend();
      final controller = HavenWindowPlatformController(backend: backend);
      addTearDown(controller.dispose);

      expect(await controller.start(), isTrue);

      expect(controller.isStarted, isTrue);
      expect(backend.operations, ['read']);
      expect(
        controller.availability.status,
        PrivateCalendarAvailabilityStatus.disconnected,
      );
    },
  );

  test('overlapping startup calls perform only one status read', () async {
    final backend = _RecordingHavenWindowBackend();
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);
    final gate = Completer<void>();
    backend.operationGate = gate.future;

    final firstStart = controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(await controller.start(), isFalse);
    expect(backend.operations, ['read']);

    gate.complete();
    expect(await firstStart, isTrue);
  });

  test(
    'explicit access request accepts only redacted UTC boundaries',
    () async {
      final backend = _RecordingHavenWindowBackend(
        requestResponse: _availability(
          status: 'ready',
          busyBlocks: [
            {
              'startsAtUtc': '2026-08-18T14:00:00.000Z',
              'endsAtUtc': '2026-08-18T14:30:00.000Z',
            },
          ],
        ),
      );
      final controller = HavenWindowPlatformController(backend: backend);
      addTearDown(controller.dispose);
      expect(await controller.start(), isTrue);

      expect(await controller.requestReadOnlyAccess(), isTrue);

      expect(backend.operations, ['read', 'request']);
      expect(
        controller.availability.status,
        PrivateCalendarAvailabilityStatus.ready,
      );
      expect(controller.availability.busyBlocks, hasLength(1));
      expect(controller.availability.rangeStart!.isUtc, isFalse);
      expect(controller.availability.busyBlocks.single.startsAt.isUtc, isFalse);
    },
  );

  test(
    'unsupported and denied states cannot trigger a permission request',
    () async {
      for (final status in ['unsupported', 'denied']) {
        final backend = _RecordingHavenWindowBackend(
          readResponse: _availability(status: status),
        );
        final controller = HavenWindowPlatformController(backend: backend);
        expect(await controller.start(), isTrue);

        expect(await controller.requestReadOnlyAccess(), isFalse);
        expect(backend.operations, ['read']);

        controller.dispose();
      }
    },
  );

  test('unknown fields and private calendar text fail closed', () async {
    final response = _availability(
      status: 'ready',
      busyBlocks: [
        {
          'startsAtUtc': '2026-08-18T14:00:00.000Z',
          'endsAtUtc': '2026-08-18T14:30:00.000Z',
          'title': 'Private therapy appointment',
        },
      ],
    );
    final backend = _RecordingHavenWindowBackend(readResponse: response);
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);

    expect(await controller.start(), isFalse);
    expect(controller.isStarted, isFalse);
    expect(controller.availability.busyBlocks, isEmpty);
    expect(
      controller.availability.status,
      PrivateCalendarAvailabilityStatus.unsupported,
    );
  });

  test('private top-level calendar fields fail closed', () async {
    final response = _availability(status: 'ready')
      ..['calendarName'] = 'Personal';
    final backend = _RecordingHavenWindowBackend(readResponse: response);
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);

    expect(await controller.start(), isFalse);
    expect(controller.availability.busyBlocks, isEmpty);
  });

  test('malformed timestamps ranges and blocks fail closed', () async {
    final responses = [
      _availability(status: 'ready')..['rangeStartUtc'] = 'not-a-time',
      _availability(status: 'ready')
        ..['rangeEndUtc'] = '2026-08-20T14:00:00.000Z',
      _availability(
        status: 'ready',
        busyBlocks: [
          {
            'startsAtUtc': '2026-08-18T15:00:00.000Z',
            'endsAtUtc': '2026-08-18T14:00:00.000Z',
          },
        ],
      ),
      _availability(
        status: 'ready',
        busyBlocks: [
          {
            'startsAtUtc': '2026-08-18T12:30:00.000Z',
            'endsAtUtc': '2026-08-18T13:30:00.000Z',
          },
        ],
      ),
    ];

    for (final response in responses) {
      final backend = _RecordingHavenWindowBackend(readResponse: response);
      final controller = HavenWindowPlatformController(backend: backend);

      expect(await controller.start(), isFalse);
      expect(controller.availability.busyBlocks, isEmpty);

      controller.dispose();
    }
  });

  test('refresh and consent operations remain serialized', () async {
    final backend = _RecordingHavenWindowBackend();
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);
    expect(await controller.start(), isTrue);
    backend.operations.clear();
    final gate = Completer<void>();
    backend.operationGate = gate.future;

    final refresh = controller.refreshAvailability();
    final request = controller.requestReadOnlyAccess();
    await Future<void>.delayed(Duration.zero);

    expect(backend.maximumConcurrentOperations, 1);
    expect(backend.operations, ['read']);

    gate.complete();
    expect(await refresh, isTrue);
    expect(await request, isTrue);
    expect(backend.maximumConcurrentOperations, 1);
    expect(backend.operations, ['read', 'request']);
  });

  test('transport failures clear stale boundaries', () async {
    final backend = _RecordingHavenWindowBackend(
      readResponse: _availability(status: 'ready'),
    );
    final controller = HavenWindowPlatformController(backend: backend);
    addTearDown(controller.dispose);
    expect(await controller.start(), isTrue);
    expect(
      controller.availability.status,
      PrivateCalendarAvailabilityStatus.ready,
    );
    backend.operationError = StateError('Calendar transport unavailable');

    expect(await controller.refreshAvailability(), isFalse);

    expect(controller.availability.busyBlocks, isEmpty);
    expect(
      controller.availability.status,
      PrivateCalendarAvailabilityStatus.unsupported,
    );
  });

  test('dispose clears availability and prevents later operations', () async {
    final backend = _RecordingHavenWindowBackend();
    final controller = HavenWindowPlatformController(backend: backend);
    expect(await controller.start(), isTrue);

    controller.dispose();

    expect(controller.isStarted, isFalse);
    expect(controller.availability.busyBlocks, isEmpty);
    expect(await controller.start(), isFalse);
    expect(await controller.refreshAvailability(), isFalse);
  });

  test('Riverpod exposes only the controller availability snapshot', () async {
    final backend = _RecordingHavenWindowBackend(
      readResponse: _availability(status: 'denied'),
    );
    final container = ProviderContainer(
      overrides: [
        havenWindowPlatformBackendProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(privateCalendarAvailabilityProvider).status,
      PrivateCalendarAvailabilityStatus.unsupported,
    );

    expect(
      await container.read(havenWindowPlatformControllerProvider).start(),
      isTrue,
    );
    expect(
      container.read(privateCalendarAvailabilityProvider).status,
      PrivateCalendarAvailabilityStatus.denied,
    );
  });
}

Map<String, Object?> _availability({
  String status = 'disconnected',
  List<Map<String, Object?>> busyBlocks = const [],
}) {
  if (status != 'ready') {
    return {'schemaVersion': 1, 'status': status};
  }
  return {
    'schemaVersion': 1,
    'status': status,
    'rangeStartUtc': '2026-08-18T13:00:00.000Z',
    'rangeEndUtc': '2026-08-18T17:00:00.000Z',
    'busyBlocks': busyBlocks,
  };
}

class _RecordingHavenWindowBackend implements HavenWindowPlatformBackend {
  _RecordingHavenWindowBackend({
    Map<String, Object?>? readResponse,
    Map<String, Object?>? requestResponse,
  }) : readResponse = readResponse ?? _availability(),
       requestResponse = requestResponse ?? _availability();

  Map<String, Object?> readResponse;
  Map<String, Object?> requestResponse;
  final List<String> operations = [];
  Future<void>? operationGate;
  Object? operationError;
  int concurrentOperations = 0;
  int maximumConcurrentOperations = 0;

  @override
  Future<Map<String, Object?>> readAvailability() =>
      _perform('read', readResponse);

  @override
  Future<Map<String, Object?>> requestReadOnlyAccess() =>
      _perform('request', requestResponse);

  Future<Map<String, Object?>> _perform(
    String operation,
    Map<String, Object?> response,
  ) async {
    operations.add(operation);
    concurrentOperations += 1;
    if (concurrentOperations > maximumConcurrentOperations) {
      maximumConcurrentOperations = concurrentOperations;
    }
    try {
      final gate = operationGate;
      if (gate != null) await gate;
      final error = operationError;
      if (error != null) throw error;
      return response;
    } finally {
      concurrentOperations -= 1;
    }
  }
}
