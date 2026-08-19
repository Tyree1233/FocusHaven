import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/haven_window_hold.dart';
import '../models/haven_window_suggestion.dart';

abstract interface class HavenWindowReminderClient {
  Future<bool> requestPermissions();
  Future<bool> scheduleHavenWindowReminder(DateTime startsAt);
  Future<void> cancelHavenWindowReminder();
}

/// Creates the one-shot clock used to cross a held window boundary.
typedef HavenWindowBoundaryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Owns one explicitly requested, private reminder for a Haven Window.
///
/// Loading saved state never requests permission or schedules anything. A
/// notification can be created only through [hold], and [release] removes it
/// without writing to the person's calendar. Returning to the foreground
/// reconciles only the already-saved UTC boundaries so a suspended app cannot
/// leave an arrived or expired hold looking stale.
class HavenWindowHoldService extends ChangeNotifier
    with WidgetsBindingObserver {
  static const _startsAtUtcKey = 'havenWindowHoldStartsAtUtcMicros';
  static const _endsAtUtcKey = 'havenWindowHoldEndsAtUtcMicros';
  static const _minimumDuration = Duration(minutes: 5);
  static const _maximumDuration = Duration(hours: 2);
  static const _maximumLeadTime = Duration(hours: 36);

  factory HavenWindowHoldService({
    required HavenWindowReminderClient notificationService,
    DateTime Function()? now,
    HavenWindowBoundaryTimerFactory? boundaryTimerFactory,
  }) {
    return HavenWindowHoldService._(
      notificationService,
      now ?? DateTime.now,
      boundaryTimerFactory ?? (duration, callback) => Timer(duration, callback),
    );
  }

  HavenWindowHoldService._(
    this._notificationService,
    this._now,
    this._boundaryTimerFactory,
  ) {
    WidgetsBinding.instance.addObserver(this);
    initialized = _load();
  }

  final HavenWindowReminderClient _notificationService;
  final DateTime Function() _now;
  final HavenWindowBoundaryTimerFactory _boundaryTimerFactory;
  HavenWindowHold _hold = const HavenWindowHold.empty();
  Timer? _boundaryTimer;
  bool _isDisposed = false;
  bool _isUpdating = false;
  int _lifecycleRevision = 0;

  late final Future<void> initialized;

  HavenWindowHold get holdState => _hold;
  bool get isUpdating => _isUpdating;
  int get lifecycleRevision => _lifecycleRevision;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lifecycleRevision++;
      _boundaryTimer?.cancel();
      _boundaryTimer = null;
      _notifyListenersSafely();
      _handleBoundary();
    }
  }

  Future<bool> hold(HavenWindowSuggestion suggestion) async {
    await initialized;
    if (_isDisposed || _isUpdating || !_isValidSuggestion(suggestion)) {
      return false;
    }

    _isUpdating = true;
    _notifyListenersSafely();
    var scheduled = false;
    try {
      final startsAt = suggestion.startsAt!;
      final endsAt = suggestion.endsAt!;
      final permitted = await _notificationService.requestPermissions();
      if (!permitted || _isDisposed) return false;

      scheduled = await _notificationService.scheduleHavenWindowReminder(
        startsAt,
      );
      if (!scheduled || _isDisposed) {
        if (scheduled) await _notificationService.cancelHavenWindowReminder();
        return false;
      }

      final nextHold = HavenWindowHold.held(
        startsAtUtc: startsAt.toUtc(),
        endsAtUtc: endsAt.toUtc(),
      );
      final preferences = await SharedPreferences.getInstance();
      await _save(preferences, nextHold);
      if (_isDisposed) {
        await _notificationService.cancelHavenWindowReminder();
        await _clear(preferences);
        return false;
      }

      _hold = nextHold;
      _armBoundaryTimer();
      return true;
    } catch (error) {
      if (scheduled) {
        try {
          await _notificationService.cancelHavenWindowReminder();
          final preferences = await SharedPreferences.getInstance();
          await _clear(preferences);
          if (!_isDisposed) _hold = const HavenWindowHold.empty();
        } catch (cleanupError) {
          debugPrint('Haven Window reminder cleanup failed: $cleanupError');
        }
      }
      debugPrint('Haven Window could not be held: $error');
      return false;
    } finally {
      _isUpdating = false;
      _notifyListenersSafely();
    }
  }

  Future<bool> release() async {
    await initialized;
    if (_isDisposed || _isUpdating) return false;

    _isUpdating = true;
    _notifyListenersSafely();
    try {
      await _notificationService.cancelHavenWindowReminder();
      final preferences = await SharedPreferences.getInstance();
      await _clear(preferences);
      if (_isDisposed) return false;

      _boundaryTimer?.cancel();
      _boundaryTimer = null;
      _hold = const HavenWindowHold.empty();
      return true;
    } catch (error) {
      debugPrint('Haven Window hold could not be released: $error');
      return false;
    } finally {
      _isUpdating = false;
      _notifyListenersSafely();
    }
  }

  bool _isValidSuggestion(HavenWindowSuggestion suggestion) {
    final startsAt = suggestion.startsAt;
    final endsAt = suggestion.endsAt;
    if (!suggestion.hasOpening ||
        startsAt == null ||
        endsAt == null ||
        startsAt.isUtc ||
        endsAt.isUtc ||
        !startsAt.isBefore(endsAt)) {
      return false;
    }

    final now = _now().toLocal();
    final duration = endsAt.difference(startsAt);
    final leadTime = startsAt.difference(now);
    return startsAt.isAfter(now) &&
        duration >= _minimumDuration &&
        duration <= _maximumDuration &&
        leadTime <= _maximumLeadTime;
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;

      final savedStart = preferences.get(_startsAtUtcKey);
      final savedEnd = preferences.get(_endsAtUtcKey);
      if (savedStart is int && savedEnd is int) {
        final startsAtUtc = DateTime.fromMicrosecondsSinceEpoch(
          savedStart,
          isUtc: true,
        );
        final endsAtUtc = DateTime.fromMicrosecondsSinceEpoch(
          savedEnd,
          isUtc: true,
        );
        final duration = endsAtUtc.difference(startsAtUtc);
        final nowUtc = _now().toUtc();
        final isStillActive = endsAtUtc.isAfter(nowUtc);
        final isFuture = startsAtUtc.isAfter(nowUtc);
        final leadTime = startsAtUtc.difference(nowUtc);
        if (isStillActive &&
            duration >= _minimumDuration &&
            duration <= _maximumDuration &&
            (!isFuture || leadTime <= _maximumLeadTime)) {
          _hold = isFuture
              ? HavenWindowHold.held(
                  startsAtUtc: startsAtUtc,
                  endsAtUtc: endsAtUtc,
                )
              : HavenWindowHold.arrived(
                  startsAtUtc: startsAtUtc,
                  endsAtUtc: endsAtUtc,
                );
          _armBoundaryTimer();
        } else {
          await _clear(preferences);
        }
      } else if (savedStart != null || savedEnd != null) {
        await _clear(preferences);
      }
    } catch (error) {
      debugPrint('Haven Window hold could not be loaded: $error');
    }
    _notifyListenersSafely();
  }

  void _armBoundaryTimer() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    if (_isDisposed || !_hold.isHeld) return;

    final nowUtc = _now().toUtc();
    final nextBoundary = _hold.hasArrived
        ? _hold.endsAtUtc!
        : _hold.startsAtUtc!;
    final delay = nextBoundary.difference(nowUtc);
    if (delay <= Duration.zero) {
      scheduleMicrotask(_handleBoundary);
      return;
    }
    _boundaryTimer = _boundaryTimerFactory(delay, _handleBoundary);
  }

  void _handleBoundary() {
    _boundaryTimer = null;
    if (_isDisposed || !_hold.isHeld) return;
    if (_isUpdating) {
      _boundaryTimer = _boundaryTimerFactory(
        const Duration(seconds: 1),
        _handleBoundary,
      );
      return;
    }

    final nowUtc = _now().toUtc();
    final startsAtUtc = _hold.startsAtUtc!;
    final endsAtUtc = _hold.endsAtUtc!;
    if (nowUtc.isBefore(startsAtUtc)) {
      _armBoundaryTimer();
      return;
    }
    if (nowUtc.isBefore(endsAtUtc)) {
      if (!_hold.hasArrived) {
        _hold = HavenWindowHold.arrived(
          startsAtUtc: startsAtUtc,
          endsAtUtc: endsAtUtc,
        );
        _notifyListenersSafely();
      }
      _armBoundaryTimer();
      return;
    }
    _isUpdating = true;
    _notifyListenersSafely();
    unawaited(_expire());
  }

  Future<void> _expire() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await _clear(preferences);
    } catch (error) {
      debugPrint('Haven Window expiration cleanup failed: $error');
    }
    _isUpdating = false;
    if (!_isDisposed) {
      _hold = const HavenWindowHold.empty();
      _notifyListenersSafely();
    }
  }

  static Future<void> _save(
    SharedPreferences preferences,
    HavenWindowHold hold,
  ) async {
    await Future.wait([
      preferences.setInt(
        _startsAtUtcKey,
        hold.startsAtUtc!.microsecondsSinceEpoch,
      ),
      preferences.setInt(_endsAtUtcKey, hold.endsAtUtc!.microsecondsSinceEpoch),
    ]);
  }

  static Future<void> _clear(SharedPreferences preferences) async {
    await Future.wait([
      preferences.remove(_startsAtUtcKey),
      preferences.remove(_endsAtUtcKey),
    ]);
  }

  void _notifyListenersSafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
