import 'package:flutter/services.dart';

import '../models/haven_system_intent.dart';
import 'haven_system_intent_inbox.dart';

typedef HavenSystemAssistantAppleRequestHandler =
    Future<bool> Function(Map<String, Object?> request);

abstract interface class HavenSystemAssistantApplePlatformBackend {
  void setRequestHandler(HavenSystemAssistantAppleRequestHandler? handler);

  Future<bool> requestPendingDelivery();
}

/// Strict transport for the private Apple system-assistant ingress seam.
///
/// The native side may deliver only the schema version, one opaque invocation
/// ID, and one allowlisted route. The transport has no field for a transcript,
/// utterance, task, account, or other user-authored text.
final class MethodChannelHavenSystemAssistantAppleBackend
    implements HavenSystemAssistantApplePlatformBackend {
  MethodChannelHavenSystemAssistantAppleBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.focushaven/system_assistant_apple';
  static const requestPendingDeliveryMethod = 'requestPendingDelivery';
  static const deliverRequestMethod = 'deliverRequest';
  static const _deliveryRequest = <String, Object?>{'schemaVersion': 1};

  final MethodChannel _channel;
  HavenSystemAssistantAppleRequestHandler? _handler;

  @override
  void setRequestHandler(HavenSystemAssistantAppleRequestHandler? handler) {
    _handler = handler;
    _channel.setMethodCallHandler(handler == null ? null : _handleMethodCall);
  }

  @override
  Future<bool> requestPendingDelivery() async {
    final result = await _channel.invokeMethod<Object?>(
      requestPendingDeliveryMethod,
      _deliveryRequest,
    );
    if (result is! bool) {
      throw const FormatException(
        'Malformed Apple system-assistant delivery result.',
      );
    }
    return result;
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != deliverRequestMethod) return false;
    final handler = _handler;
    if (handler == null) return false;
    try {
      return await handler(_readMap(call.arguments));
    } catch (_) {
      return false;
    }
  }

  static Map<String, Object?> _readMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Malformed Apple system-assistant request.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException(
          'Malformed Apple system-assistant request key.',
        );
      }
      result[key] = entry.value;
    }
    return result;
  }
}

/// Owns one memory-only Apple-to-Flutter request-delivery session.
///
/// The controller validates the exact three-field wire payload before handing
/// it to [HavenSystemIntentInbox]. Returning `true` is only an acknowledgement
/// that the app-level inbox accepted the request; it never prepares, confirms,
/// or executes an action. Native code retains an unacknowledged request for a
/// later foreground delivery attempt within the same process lifetime.
final class HavenSystemAssistantApplePlatformController {
  HavenSystemAssistantApplePlatformController({
    required HavenSystemAssistantApplePlatformBackend backend,
    required HavenSystemIntentInbox inbox,
  }) : this._(backend, inbox);

  HavenSystemAssistantApplePlatformController._(this._backend, this._inbox);

  static const schemaVersion = 1;
  static const maxInvocationIdLength = 128;
  static final RegExp _invocationIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]*$',
  );

  final HavenSystemAssistantApplePlatformBackend _backend;
  final HavenSystemIntentInbox _inbox;
  bool _isStarted = false;
  bool _isStarting = false;
  bool _isDisposed = false;
  bool _deliveryRequestInFlight = false;

  bool get isStarted => _isStarted;

  Future<bool> start() async {
    if (_isDisposed || _isStarted || _isStarting) return false;
    _isStarting = true;
    try {
      _backend.setRequestHandler(_receiveRequest);
      _isStarted = true;
      await _requestDelivery();
      return true;
    } catch (_) {
      _backend.setRequestHandler(null);
      _isStarted = false;
      return false;
    } finally {
      _isStarting = false;
    }
  }

  Future<bool> refresh() async {
    if (_isDisposed || !_isStarted) return false;
    try {
      return await _requestDelivery();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestDelivery() async {
    if (_deliveryRequestInFlight) return false;
    _deliveryRequestInFlight = true;
    try {
      return await _backend.requestPendingDelivery();
    } finally {
      _deliveryRequestInFlight = false;
    }
  }

  Future<bool> _receiveRequest(Map<String, Object?> value) async {
    if (_isDisposed || !_isStarted) return false;
    try {
      return _inbox.submit(_parseRequest(value));
    } catch (_) {
      return false;
    }
  }

  static HavenSystemIntentRequest _parseRequest(Map<String, Object?> value) {
    const keys = {'schemaVersion', 'invocationId', 'kind'};
    if (value.length != keys.length ||
        !value.keys.toSet().containsAll(keys) ||
        value['schemaVersion'] != schemaVersion) {
      throw const FormatException(
        'Unexpected Apple system-assistant request fields.',
      );
    }
    final invocationId = value['invocationId'];
    if (invocationId is! String ||
        invocationId.isEmpty ||
        invocationId.length > maxInvocationIdLength ||
        !_invocationIdPattern.hasMatch(invocationId)) {
      throw const FormatException(
        'Malformed Apple system-assistant invocation ID.',
      );
    }
    final kind = switch (value['kind']) {
      'readTimerStatus' => HavenSystemIntentKind.readTimerStatus,
      'startFocusTimer' => HavenSystemIntentKind.startFocusTimer,
      'pauseTimer' => HavenSystemIntentKind.pauseTimer,
      'resumeTimer' => HavenSystemIntentKind.resumeTimer,
      'openFocusQueue' => HavenSystemIntentKind.openFocusQueue,
      _ => throw const FormatException(
        'Unsupported Apple system-assistant route.',
      ),
    };
    return HavenSystemIntentRequest(
      schemaVersion: schemaVersion,
      invocationId: invocationId,
      kind: kind,
    );
  }

  void stop() {
    if (_isDisposed || !_isStarted) return;
    _isStarted = false;
    _backend.setRequestHandler(null);
  }

  void dispose() {
    if (_isDisposed) return;
    stop();
    _isDisposed = true;
  }
}
