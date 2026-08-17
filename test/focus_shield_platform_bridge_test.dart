import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_shield_state.dart';
import 'package:focushaven/services/focus_shield_platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('method channel uses only the bounded Focus Shield contract', () async {
    const channel = MethodChannel('com.focushaven/test_focus_shield');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return _capability();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final backend = MethodChannelFocusShieldBackend(channel: channel);

    await backend.readCapability();
    await backend.performAction(FocusShieldAction.chooseDistractions);
    await backend.setProtectionRequested(true);

    expect(calls.map((call) => call.method), [
      MethodChannelFocusShieldBackend.readCapabilityMethod,
      MethodChannelFocusShieldBackend.performActionMethod,
      MethodChannelFocusShieldBackend.setProtectionRequestedMethod,
    ]);
    expect(calls[0].arguments, isNull);
    expect(calls[1].arguments, 'chooseDistractions');
    expect(calls[2].arguments, isTrue);
    expect(calls.toString(), isNot(contains('applicationToken')));
    expect(calls.toString(), isNot(contains('webDomainToken')));
  });

  test('controller stays dormant until an iOS host starts it', () async {
    final backend = _RecordingFocusShieldBackend();
    final controller = FocusShieldPlatformController(backend: backend);
    addTearDown(controller.dispose);

    expect(controller.isStarted, isFalse);
    expect(controller.capability.nativeSupportAvailable, isFalse);
    expect(await controller.performAction(FocusShieldAction.enable), isFalse);
    expect(await controller.syncProtection(true), isFalse);
    expect(backend.handler, isNull);
    expect(backend.operations, isEmpty);
  });

  test('startup accepts exactly one seven-field capability map', () async {
    final backend = _RecordingFocusShieldBackend(
      capability: _capability(
        isEnabled: true,
        authorization: 'approved',
        hasSelection: true,
      ),
    );
    final controller = FocusShieldPlatformController(backend: backend);
    addTearDown(controller.dispose);

    expect(await controller.start(), isTrue);

    expect(controller.isStarted, isTrue);
    expect(backend.handler, isNotNull);
    expect(controller.capability.isEnabled, isTrue);
    expect(
      controller.capability.authorization,
      FocusShieldAuthorization.approved,
    );
    expect(controller.capability.hasSelection, isTrue);
  });

  test('unknown fields and impossible protection claims fail closed', () async {
    final privateText = _capability()..['focusTask'] = 'Private launch plan';
    final rejectedBackend = _RecordingFocusShieldBackend(
      capability: privateText,
    );
    final rejected = FocusShieldPlatformController(backend: rejectedBackend);
    addTearDown(rejected.dispose);

    expect(await rejected.start(), isFalse);
    expect(rejected.isStarted, isFalse);
    expect(rejectedBackend.handler, isNull);
    expect(rejected.capability.nativeSupportAvailable, isFalse);

    final backend = _RecordingFocusShieldBackend(
      capability: _capability(
        isEnabled: true,
        authorization: 'approved',
        hasSelection: true,
      ),
    );
    final controller = FocusShieldPlatformController(backend: backend);
    addTearDown(controller.dispose);
    expect(await controller.start(), isTrue);

    backend.handler!(
      _capability(
        isEnabled: true,
        authorization: 'approved',
        hasSelection: false,
        nativeStatus: 'protecting',
      ),
    );

    expect(controller.capability.nativeStatus, FocusShieldNativeStatus.failed);
    expect(controller.capability.hasSelection, isTrue);
  });

  test(
    'overlapping actions and protection requests remain serialized',
    () async {
      final backend = _RecordingFocusShieldBackend(
        capability: _capability(nativeSupportAvailable: true),
      );
      final controller = FocusShieldPlatformController(backend: backend);
      addTearDown(controller.dispose);
      expect(await controller.start(), isTrue);
      final gate = Completer<void>();
      backend.operationGate = gate.future;

      final enable = controller.performAction(FocusShieldAction.enable);
      final protect = controller.syncProtection(true);
      await Future<void>.delayed(Duration.zero);

      expect(backend.maximumConcurrentOperations, 1);
      expect(backend.operations, ['action:enable']);

      gate.complete();
      expect(await enable, isTrue);
      expect(await protect, isTrue);
      expect(backend.maximumConcurrentOperations, 1);
      expect(backend.operations, ['action:enable', 'protection:true']);
    },
  );

  test('native failures fail open without erasing known support', () async {
    final backend = _RecordingFocusShieldBackend(
      capability: _capability(nativeSupportAvailable: true),
    );
    final controller = FocusShieldPlatformController(backend: backend);
    addTearDown(controller.dispose);
    expect(await controller.start(), isTrue);
    backend.operationError = StateError('Family Controls unavailable');

    expect(await controller.performAction(FocusShieldAction.enable), isFalse);

    expect(controller.capability.isEnabled, isFalse);
    expect(controller.capability.nativeSupportAvailable, isTrue);
    expect(
      controller.capability.nativeStatus,
      FocusShieldNativeStatus.inactive,
    );
  });

  test('dispose removes native delivery and prevents restart', () async {
    final backend = _RecordingFocusShieldBackend();
    final controller = FocusShieldPlatformController(backend: backend);
    expect(await controller.start(), isTrue);

    controller.dispose();

    expect(controller.isStarted, isFalse);
    expect(backend.handler, isNull);
    expect(await controller.start(), isFalse);
    expect(await controller.syncProtection(true), isFalse);
  });
}

Map<String, Object?> _capability({
  bool isEnabled = false,
  bool nativeSupportAvailable = true,
  String authorization = 'notRequested',
  bool hasSelection = false,
  bool temporarilyPaused = false,
  String nativeStatus = 'inactive',
}) => {
  'schemaVersion': 1,
  'isEnabled': isEnabled,
  'nativeSupportAvailable': nativeSupportAvailable,
  'authorization': authorization,
  'hasSelection': hasSelection,
  'temporarilyPaused': temporarilyPaused,
  'nativeStatus': nativeStatus,
};

final class _RecordingFocusShieldBackend implements FocusShieldPlatformBackend {
  _RecordingFocusShieldBackend({Map<String, Object?>? capability})
    : capability = capability ?? _capability();

  Map<String, Object?> capability;
  FocusShieldCapabilityHandler? handler;
  Future<void>? operationGate;
  Object? operationError;
  final List<String> operations = [];
  int _activeOperations = 0;
  int maximumConcurrentOperations = 0;

  @override
  void setCapabilityHandler(FocusShieldCapabilityHandler? handler) {
    this.handler = handler;
  }

  @override
  Future<Map<String, Object?>> readCapability() async =>
      Map<String, Object?>.from(capability);

  @override
  Future<Map<String, Object?>> performAction(FocusShieldAction action) =>
      _run('action:${action.name}');

  @override
  Future<Map<String, Object?>> setProtectionRequested(bool requested) =>
      _run('protection:$requested');

  Future<Map<String, Object?>> _run(String operation) async {
    operations.add(operation);
    _activeOperations += 1;
    if (_activeOperations > maximumConcurrentOperations) {
      maximumConcurrentOperations = _activeOperations;
    }
    try {
      final gate = operationGate;
      if (gate != null) await gate;
      final error = operationError;
      if (error != null) throw error;
      return Map<String, Object?>.from(capability);
    } finally {
      _activeOperations -= 1;
    }
  }
}
