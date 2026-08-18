import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/haven_window_suggestion.dart';

abstract interface class HavenWindowPlatformBackend {
  Future<Map<String, Object?>> readAvailability();

  Future<Map<String, Object?>> requestReadOnlyAccess();
}

/// Strict method-channel transport for private calendar availability.
///
/// Flutter sends only the schema version. Native code can return authorization
/// status and UTC busy boundaries, but the contract has no fields for calendar
/// names, event text, attendees, locations, notes, or account identities.
class MethodChannelHavenWindowBackend implements HavenWindowPlatformBackend {
  MethodChannelHavenWindowBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.focushaven/haven_window';
  static const readAvailabilityMethod = 'readAvailability';
  static const requestReadOnlyAccessMethod = 'requestReadOnlyAccess';
  static const _request = <String, Object?>{'schemaVersion': 1};

  final MethodChannel _channel;

  @override
  Future<Map<String, Object?>> readAvailability() async => _readMap(
    await _channel.invokeMethod<Object?>(readAvailabilityMethod, _request),
  );

  @override
  Future<Map<String, Object?>> requestReadOnlyAccess() async => _readMap(
    await _channel.invokeMethod<Object?>(requestReadOnlyAccessMethod, _request),
  );

  static Map<String, Object?> _readMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Malformed Haven Window availability.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException('Malformed Haven Window availability key.');
      }
      result[key] = entry.value;
    }
    return result;
  }
}

/// Owns one consent-first calendar availability session.
///
/// [start] checks existing authorization without prompting. Only the explicit
/// [requestReadOnlyAccess] call can ask native code for permission. Operations
/// are serialized and every failure clears busy boundaries.
class HavenWindowPlatformController extends ChangeNotifier {
  HavenWindowPlatformController({required this._backend});

  static const unsupportedAvailability = PrivateCalendarAvailability(
    status: PrivateCalendarAvailabilityStatus.unsupported,
  );

  final HavenWindowPlatformBackend _backend;
  PrivateCalendarAvailability _availability = unsupportedAvailability;
  Future<void> _operationTail = Future<void>.value();
  bool _isStarted = false;
  bool _isStarting = false;
  bool _isDisposed = false;

  PrivateCalendarAvailability get availability => _availability;
  bool get isStarted => _isStarted;

  Future<bool> start() async {
    if (_isDisposed || _isStarted || _isStarting) return false;
    _isStarting = true;
    try {
      final availability = _parseAvailability(
        await _backend.readAvailability(),
      );
      if (_isDisposed) return false;
      _isStarted = true;
      _updateAvailability(availability, forceNotification: true);
      return true;
    } catch (_) {
      _isStarted = false;
      _updateAvailability(unsupportedAvailability);
      return false;
    } finally {
      _isStarting = false;
    }
  }

  Future<bool> refreshAvailability() => _enqueue(
    () async => _parseAvailability(await _backend.readAvailability()),
  );

  /// The only controller operation allowed to trigger a native permission UI.
  Future<bool> requestReadOnlyAccess() {
    if (_availability.status !=
        PrivateCalendarAvailabilityStatus.disconnected) {
      return Future<bool>.value(false);
    }
    return _enqueue(
      () async => _parseAvailability(await _backend.requestReadOnlyAccess()),
      allowed: () =>
          _availability.status ==
          PrivateCalendarAvailabilityStatus.disconnected,
    );
  }

  Future<bool> _enqueue(
    Future<PrivateCalendarAvailability> Function() operation, {
    bool Function()? allowed,
  }) {
    if (_isDisposed || !_isStarted) return Future<bool>.value(false);
    final result = _operationTail.then((_) async {
      if (_isDisposed || !_isStarted) return false;
      if (allowed != null && !allowed()) return false;
      try {
        _updateAvailability(await operation());
        return true;
      } catch (_) {
        _updateAvailability(unsupportedAvailability);
        return false;
      }
    });
    _operationTail = result.then<void>((_) {});
    return result;
  }

  void _updateAvailability(
    PrivateCalendarAvailability availability, {
    bool forceNotification = false,
  }) {
    if (!forceNotification && identical(availability, _availability)) return;
    _availability = availability;
    notifyListeners();
  }

  static PrivateCalendarAvailability _parseAvailability(
    Map<String, Object?> json,
  ) {
    if (json['schemaVersion'] != 1 || json['status'] is! String) {
      throw const FormatException('Malformed Haven Window status.');
    }
    final status = switch (json['status']) {
      'unsupported' => PrivateCalendarAvailabilityStatus.unsupported,
      'disconnected' => PrivateCalendarAvailabilityStatus.disconnected,
      'denied' => PrivateCalendarAvailabilityStatus.denied,
      'ready' => PrivateCalendarAvailabilityStatus.ready,
      _ => throw const FormatException('Unknown Haven Window status.'),
    };

    if (status != PrivateCalendarAvailabilityStatus.ready) {
      const keys = {'schemaVersion', 'status'};
      if (json.length != keys.length || !json.keys.toSet().containsAll(keys)) {
        throw const FormatException(
          'Unexpected unavailable Haven Window fields.',
        );
      }
      return PrivateCalendarAvailability(status: status);
    }

    const keys = {
      'schemaVersion',
      'status',
      'rangeStartUtc',
      'rangeEndUtc',
      'busyBlocks',
    };
    if (json.length != keys.length || !json.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected Haven Window fields.');
    }
    final rangeStart = _parseUtc(json['rangeStartUtc']);
    final rangeEnd = _parseUtc(json['rangeEndUtc']);
    if (!rangeStart.isBefore(rangeEnd) ||
        rangeEnd.difference(rangeStart) > const Duration(hours: 36)) {
      throw const FormatException('Impossible Haven Window range.');
    }
    final blocksJson = json['busyBlocks'];
    if (blocksJson is! List || blocksJson.length > 64) {
      throw const FormatException('Malformed Haven Window busy blocks.');
    }
    final busyBlocks = <CalendarBusyBlock>[];
    for (final value in blocksJson) {
      if (value is! Map) {
        throw const FormatException('Malformed Haven Window busy block.');
      }
      final block = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw const FormatException('Malformed busy block key.');
        }
        block[key] = entry.value;
      }
      const blockKeys = {'startsAtUtc', 'endsAtUtc'};
      if (block.length != blockKeys.length ||
          !block.keys.toSet().containsAll(blockKeys)) {
        throw const FormatException('Unexpected busy block fields.');
      }
      final startsAt = _parseUtc(block['startsAtUtc']);
      final endsAt = _parseUtc(block['endsAtUtc']);
      if (!startsAt.isBefore(endsAt) ||
          startsAt.isBefore(rangeStart) ||
          endsAt.isAfter(rangeEnd)) {
        throw const FormatException('Impossible busy block interval.');
      }
      busyBlocks.add(
        CalendarBusyBlock(
          startsAt: startsAt.toLocal(),
          endsAt: endsAt.toLocal(),
        ),
      );
    }
    return PrivateCalendarAvailability(
      status: status,
      rangeStart: rangeStart.toLocal(),
      rangeEnd: rangeEnd.toLocal(),
      busyBlocks: List<CalendarBusyBlock>.unmodifiable(busyBlocks),
    );
  }

  static DateTime _parseUtc(Object? value) {
    if (value is! String || !value.endsWith('Z')) {
      throw const FormatException('Malformed UTC calendar timestamp.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw const FormatException('Malformed UTC calendar timestamp.');
    }
    return parsed;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isStarted = false;
    _availability = unsupportedAvailability;
    super.dispose();
  }
}
