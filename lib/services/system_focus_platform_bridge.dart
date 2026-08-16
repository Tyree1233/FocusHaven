import 'package:flutter/services.dart';

import '../models/system_focus_command.dart';
import '../models/system_focus_snapshot.dart';
import 'system_focus_command_router.dart';

typedef SystemFocusPlatformCommandHandler =
    Future<bool> Function(Map<String, Object?> command);

abstract interface class SystemFocusPlatformBackend {
  void setCommandHandler(SystemFocusPlatformCommandHandler? handler);

  Future<void> publishSnapshot(Map<String, Object?> snapshot);
}

/// The narrow Flutter platform channel reserved for system focus surfaces.
///
/// Native adapters are intentionally responsible only for storing/rendering
/// the approved snapshot and forwarding the approved command envelope.
class MethodChannelSystemFocusBackend implements SystemFocusPlatformBackend {
  MethodChannelSystemFocusBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.focushaven/system_focus';
  static const publishMethod = 'publishSnapshot';
  static const executeMethod = 'executeCommand';

  final MethodChannel _channel;
  SystemFocusPlatformCommandHandler? _handler;

  @override
  void setCommandHandler(SystemFocusPlatformCommandHandler? handler) {
    _handler = handler;
    _channel.setMethodCallHandler(handler == null ? null : _handleMethodCall);
  }

  @override
  Future<void> publishSnapshot(Map<String, Object?> snapshot) =>
      _channel.invokeMethod<void>(publishMethod, snapshot);

  Future<Object?> _handleMethodCall(MethodCall call) async {
    final handler = _handler;
    if (call.method != executeMethod || handler == null) return false;
    final arguments = call.arguments;
    if (arguments is! Map) return false;

    try {
      final command = <String, Object?>{};
      for (final entry in arguments.entries) {
        final key = entry.key;
        if (key is! String) return false;
        command[key] = entry.value;
      }
      return await handler(command);
    } catch (_) {
      return false;
    }
  }
}

/// Keeps platform transport outside the timer and authorization models.
///
/// The bridge is dormant until [start] is called by a supported native host.
/// Initial publication must succeed before commands remain enabled. Snapshot
/// writes are serialized so older asynchronous writes cannot overtake newer
/// timer state.
class SystemFocusPlatformBridge {
  factory SystemFocusPlatformBridge({
    required SystemFocusPlatformBackend backend,
    required SystemFocusCommandRouter router,
    required SystemFocusSnapshot Function() readSnapshot,
    required SystemFocusCommandTarget target,
  }) => SystemFocusPlatformBridge._(backend, router, readSnapshot, target);

  SystemFocusPlatformBridge._(
    this._backend,
    this._router,
    this._readSnapshot,
    this._target,
  );

  final SystemFocusPlatformBackend _backend;
  final SystemFocusCommandRouter _router;
  final SystemFocusSnapshot Function() _readSnapshot;
  final SystemFocusCommandTarget _target;

  Future<void> _publishTail = Future<void>.value();
  bool _isStarted = false;
  bool _isDisposed = false;

  bool get isStarted => _isStarted;

  Future<bool> start() async {
    if (_isDisposed || _isStarted) return false;
    try {
      _backend.setCommandHandler(_handleCommand);
      _isStarted = true;
    } catch (_) {
      _isStarted = false;
      return false;
    }

    final published = await publishCurrent();
    if (published) return true;
    _isStarted = false;
    _clearCommandHandler();
    return false;
  }

  Future<bool> publishCurrent() {
    if (_isDisposed || !_isStarted) return Future<bool>.value(false);
    try {
      return publish(_readSnapshot());
    } catch (_) {
      return Future<bool>.value(false);
    }
  }

  Future<bool> publish(SystemFocusSnapshot snapshot) {
    if (_isDisposed || !_isStarted) return Future<bool>.value(false);
    final operation = _publishTail.then((_) async {
      if (_isDisposed || !_isStarted) return false;
      try {
        await _backend.publishSnapshot(snapshot.toJson());
        return true;
      } catch (_) {
        return false;
      }
    });
    _publishTail = operation.then<void>((_) {});
    return operation;
  }

  Future<bool> _handleCommand(Map<String, Object?> json) async {
    if (_isDisposed || !_isStarted) return false;
    try {
      final command = SystemFocusCommand.fromJson(json);
      final currentSnapshot = _readSnapshot();
      final accepted = _router.execute(
        command: command,
        currentSnapshot: currentSnapshot,
        target: _target,
      );
      if (!accepted) return false;

      // The timer mutation invalidates the snapshot provider synchronously.
      // Publication is best-effort; authorization success remains truthful
      // even if the native surface becomes temporarily unavailable afterward.
      await publishCurrent();
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isStarted = false;
    _clearCommandHandler();
  }

  void _clearCommandHandler() {
    try {
      _backend.setCommandHandler(null);
    } catch (_) {
      // A failing native teardown must not keep the Dart bridge active.
    }
  }
}
