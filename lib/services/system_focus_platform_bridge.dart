import 'dart:async';

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

/// Optional native inbox used when a trusted system surface launches the app.
abstract interface class SystemFocusPendingCommandBackend {
  Future<Map<String, Object?>?> takePendingCommand();
}

/// The narrow Flutter platform channel reserved for system focus surfaces.
///
/// Native adapters are intentionally responsible only for storing/rendering
/// the approved snapshot and forwarding the approved command envelope.
class MethodChannelSystemFocusBackend
    implements SystemFocusPlatformBackend, SystemFocusPendingCommandBackend {
  MethodChannelSystemFocusBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.focushaven/system_focus';
  static const publishMethod = 'publishSnapshot';
  static const executeMethod = 'executeCommand';
  static const takePendingCommandMethod = 'takePendingCommand';

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

  @override
  Future<Map<String, Object?>?> takePendingCommand() async {
    final value = await _channel.invokeMethod<Object?>(
      takePendingCommandMethod,
    );
    if (value == null) return null;
    if (value is! Map) throw const FormatException('Malformed native command.');
    final command = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException('Malformed native command key.');
      }
      command[key] = entry.value;
    }
    return command;
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != executeMethod) return false;
    final handler = _handler;
    // A null acknowledgement tells native code to retain a warm-launch
    // command until timer restoration installs the authorization router.
    if (handler == null) return null;
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
  SystemFocusSnapshot? _publishedSnapshot;

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
    if (published) {
      await consumePendingCommand();
      return true;
    }
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
      final published = _publishedSnapshot;
      if (published != null &&
          snapshot.isEquivalentForSystemSurface(published)) {
        return true;
      }
      try {
        await _backend.publishSnapshot(snapshot.toJson());
        _publishedSnapshot = snapshot;
        return true;
      } catch (_) {
        return false;
      }
    });
    _publishTail = operation.then<void>((_) {});
    return operation;
  }

  /// Claims and handles at most one command queued by a cold native launch.
  Future<bool> consumePendingCommand() async {
    if (_isDisposed || !_isStarted) return false;
    final backend = _backend;
    if (backend is! SystemFocusPendingCommandBackend) return false;
    try {
      final pendingBackend = backend as SystemFocusPendingCommandBackend;
      final command = await pendingBackend.takePendingCommand();
      if (command == null) return false;
      return _handleCommand(command, restoreTrustedNativeCommand: true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleCommand(
    Map<String, Object?> json, {
    bool restoreTrustedNativeCommand = false,
  }) async {
    if (_isDisposed || !_isStarted) return false;
    try {
      final command = SystemFocusCommand.fromJson(json);
      final currentSnapshot = _readSnapshot();
      final publishedSnapshot = _publishedSnapshot;
      if (publishedSnapshot == null ||
          !currentSnapshot.isEquivalentForSystemSurface(publishedSnapshot)) {
        await publish(currentSnapshot);
        return false;
      }
      final authorizedCommand = restoreTrustedNativeCommand
          // Android authenticated the tap against the exact rendered snapshot
          // before launch. Rebind only its timestamp after timer restoration;
          // the router still requires the action in the current published state.
          ? SystemFocusCommand(
              requestId: command.requestId,
              action: command.action,
              snapshotGeneratedAt: publishedSnapshot.generatedAt,
            )
          : command;
      final accepted = _router.execute(
        command: authorizedCommand,
        currentSnapshot: publishedSnapshot,
        target: _target,
      );
      if (!accepted) return false;

      // The timer mutation invalidates the snapshot provider synchronously.
      // Publication is best-effort; authorization success remains truthful
      // even if the native surface becomes temporarily unavailable afterward.
      unawaited(publishCurrent());
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
