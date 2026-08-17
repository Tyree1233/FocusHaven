import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/focus_shield_state.dart';

typedef FocusShieldCapabilityHandler =
    void Function(Map<String, Object?> capability);

abstract interface class FocusShieldPlatformBackend {
  void setCapabilityHandler(FocusShieldCapabilityHandler? handler);

  Future<Map<String, Object?>> readCapability();

  Future<Map<String, Object?>> performAction(FocusShieldAction action);

  Future<Map<String, Object?>> setProtectionRequested(bool requested);
}

/// Strict method-channel transport for the native Focus Shield adapter.
///
/// Native app and website tokens never cross this channel. The complete
/// contract is one versioned map containing only readiness and enforcement
/// signals.
class MethodChannelFocusShieldBackend implements FocusShieldPlatformBackend {
  MethodChannelFocusShieldBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.focushaven/focus_shield';
  static const readCapabilityMethod = 'readCapability';
  static const performActionMethod = 'performAction';
  static const setProtectionRequestedMethod = 'setProtectionRequested';
  static const capabilityChangedMethod = 'capabilityChanged';

  final MethodChannel _channel;
  FocusShieldCapabilityHandler? _handler;

  @override
  void setCapabilityHandler(FocusShieldCapabilityHandler? handler) {
    _handler = handler;
    _channel.setMethodCallHandler(handler == null ? null : _handleMethodCall);
  }

  @override
  Future<Map<String, Object?>> readCapability() async =>
      _readMap(await _channel.invokeMethod<Object?>(readCapabilityMethod));

  @override
  Future<Map<String, Object?>> performAction(FocusShieldAction action) async =>
      _readMap(
        await _channel.invokeMethod<Object?>(performActionMethod, action.name),
      );

  @override
  Future<Map<String, Object?>> setProtectionRequested(bool requested) async =>
      _readMap(
        await _channel.invokeMethod<Object?>(
          setProtectionRequestedMethod,
          requested,
        ),
      );

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != capabilityChangedMethod) return false;
    final handler = _handler;
    if (handler == null) return false;
    try {
      handler(_readMap(call.arguments));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, Object?> _readMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Malformed Focus Shield capability.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException('Malformed Focus Shield capability key.');
      }
      result[key] = entry.value;
    }
    return result;
  }
}

/// Owns one fail-open native Focus Shield session for the app container.
///
/// Reads and mutations are serialized so an earlier permission or picker
/// result cannot overtake a later protection request. Malformed platform data
/// is contained and can never create a positive protection claim.
class FocusShieldPlatformController extends ChangeNotifier {
  FocusShieldPlatformController({required this._backend});

  static const unsupportedCapability = (
    isEnabled: false,
    nativeSupportAvailable: false,
    authorization: FocusShieldAuthorization.notRequested,
    hasSelection: false,
    temporarilyPaused: false,
    nativeStatus: FocusShieldNativeStatus.unavailable,
  );

  final FocusShieldPlatformBackend _backend;
  FocusShieldCapability _capability = unsupportedCapability;
  Future<void> _operationTail = Future<void>.value();
  bool? _lastProtectionRequested;
  bool _isStarted = false;
  bool _isDisposed = false;

  FocusShieldCapability get capability => _capability;
  bool get isStarted => _isStarted;

  Future<bool> start() async {
    if (_isDisposed || _isStarted) return false;
    try {
      _backend.setCapabilityHandler(_receiveCapability);
      final capability = _parseCapability(await _backend.readCapability());
      if (_isDisposed) return false;
      _isStarted = true;
      _updateCapability(capability, forceNotification: true);
      return true;
    } catch (_) {
      _clearHandler();
      _isStarted = false;
      _updateCapability(unsupportedCapability);
      return false;
    }
  }

  Future<bool> performAction(FocusShieldAction action) => _enqueue(() async {
    return _parseCapability(await _backend.performAction(action));
  });

  Future<bool> syncProtection(bool requested) {
    if (_lastProtectionRequested == requested) {
      return Future<bool>.value(_isStarted && !_isDisposed);
    }
    return _enqueue(() async {
      final capability = _parseCapability(
        await _backend.setProtectionRequested(requested),
      );
      _lastProtectionRequested = requested;
      return capability;
    });
  }

  Future<bool> _enqueue(Future<FocusShieldCapability> Function() operation) {
    if (_isDisposed || !_isStarted) return Future<bool>.value(false);
    final result = _operationTail.then((_) async {
      if (_isDisposed || !_isStarted) return false;
      try {
        _updateCapability(await operation());
        return true;
      } catch (_) {
        _lastProtectionRequested = null;
        _updateCapability(_failedOpenCapability(_capability));
        return false;
      }
    });
    _operationTail = result.then<void>((_) {});
    return result;
  }

  void _receiveCapability(Map<String, Object?> value) {
    if (_isDisposed || !_isStarted) return;
    try {
      _lastProtectionRequested = null;
      _updateCapability(_parseCapability(value));
    } catch (_) {
      _updateCapability(_failedOpenCapability(_capability));
    }
  }

  void _updateCapability(
    FocusShieldCapability capability, {
    bool forceNotification = false,
  }) {
    if (!forceNotification && capability == _capability) return;
    _capability = capability;
    notifyListeners();
  }

  static FocusShieldCapability _parseCapability(Map<String, Object?> json) {
    const keys = {
      'schemaVersion',
      'isEnabled',
      'nativeSupportAvailable',
      'authorization',
      'hasSelection',
      'temporarilyPaused',
      'nativeStatus',
    };
    if (json.length != keys.length || !json.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected Focus Shield capability fields.');
    }
    if (json['schemaVersion'] != 1 ||
        json['isEnabled'] is! bool ||
        json['nativeSupportAvailable'] is! bool ||
        json['hasSelection'] is! bool ||
        json['temporarilyPaused'] is! bool) {
      throw const FormatException('Malformed Focus Shield capability values.');
    }
    final authorization = switch (json['authorization']) {
      'notRequested' => FocusShieldAuthorization.notRequested,
      'denied' => FocusShieldAuthorization.denied,
      'approved' => FocusShieldAuthorization.approved,
      _ => throw const FormatException('Malformed Focus Shield authorization.'),
    };
    final nativeStatus = switch (json['nativeStatus']) {
      'unavailable' => FocusShieldNativeStatus.unavailable,
      'inactive' => FocusShieldNativeStatus.inactive,
      'protecting' => FocusShieldNativeStatus.protecting,
      'failed' => FocusShieldNativeStatus.failed,
      _ => throw const FormatException('Malformed Focus Shield native status.'),
    };
    final capability = (
      isEnabled: json['isEnabled']! as bool,
      nativeSupportAvailable: json['nativeSupportAvailable']! as bool,
      authorization: authorization,
      hasSelection: json['hasSelection']! as bool,
      temporarilyPaused: json['temporarilyPaused']! as bool,
      nativeStatus: nativeStatus,
    );
    if (!capability.nativeSupportAvailable &&
        capability.nativeStatus != FocusShieldNativeStatus.unavailable) {
      throw const FormatException('Unsupported Focus Shield status mismatch.');
    }
    if (!capability.isEnabled &&
        (capability.temporarilyPaused ||
            capability.nativeStatus == FocusShieldNativeStatus.protecting)) {
      throw const FormatException('Disabled Focus Shield status mismatch.');
    }
    if (capability.nativeStatus == FocusShieldNativeStatus.protecting &&
        (capability.authorization != FocusShieldAuthorization.approved ||
            !capability.hasSelection ||
            capability.temporarilyPaused)) {
      throw const FormatException('Impossible Focus Shield protection claim.');
    }
    return capability;
  }

  static FocusShieldCapability _failedOpenCapability(
    FocusShieldCapability current,
  ) {
    if (!current.nativeSupportAvailable) {
      return unsupportedCapability;
    }
    if (!current.isEnabled) {
      return (
        isEnabled: false,
        nativeSupportAvailable: true,
        authorization: current.authorization,
        hasSelection: current.hasSelection,
        temporarilyPaused: false,
        nativeStatus: FocusShieldNativeStatus.inactive,
      );
    }
    return (
      isEnabled: true,
      nativeSupportAvailable: true,
      authorization: current.authorization,
      hasSelection: current.hasSelection,
      temporarilyPaused: current.temporarilyPaused,
      nativeStatus: FocusShieldNativeStatus.failed,
    );
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isStarted = false;
    _clearHandler();
    super.dispose();
  }

  void _clearHandler() {
    try {
      _backend.setCapabilityHandler(null);
    } catch (_) {
      // A failing native teardown cannot keep the controller active.
    }
  }
}
