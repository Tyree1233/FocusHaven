import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/haven_window_hold.dart';
import '../models/haven_window_suggestion.dart';
import 'privacy_safe_diagnostics.dart';

abstract interface class HavenWindowReminderClient {
  Future<bool> requestPermissions();
  Future<bool> scheduleHavenWindowReminder(DateTime startsAt);
  Future<void> cancelHavenWindowReminder();
}

/// Creates the one-shot clock used to cross a held window boundary.
typedef HavenWindowBoundaryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Persists both private UTC boundaries as one verified hold commit.
typedef HavenWindowHoldSave =
    Future<bool> Function(SharedPreferences preferences, HavenWindowHold hold);

/// Removes both private UTC boundaries as one verified cleanup.
typedef HavenWindowHoldClear =
    Future<bool> Function(SharedPreferences preferences);

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
    HavenWindowHoldSave? saveHold,
    HavenWindowHoldClear? clearHold,
  }) {
    return HavenWindowHoldService._(
      notificationService,
      now ?? DateTime.now,
      boundaryTimerFactory ?? (duration, callback) => Timer(duration, callback),
      saveHold ?? _saveToPreferences,
      clearHold ?? _clearFromPreferences,
    );
  }

  HavenWindowHoldService._(
    this._notificationService,
    this._now,
    this._boundaryTimerFactory,
    this._saveHold,
    this._clearHold,
  ) {
    WidgetsBinding.instance.addObserver(this);
    initialized = _load();
  }

  final HavenWindowReminderClient _notificationService;
  final DateTime Function() _now;
  final HavenWindowBoundaryTimerFactory _boundaryTimerFactory;
  final HavenWindowHoldSave _saveHold;
  final HavenWindowHoldClear _clearHold;
  HavenWindowHold _hold = const HavenWindowHold.empty();
  Timer? _boundaryTimer;
  bool _isDisposed = false;
  bool _isUpdating = false;
  bool _hasPendingCleanup = false;
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
      if (_hasPendingCleanup) {
        _retryPendingCleanup();
      } else {
        _notifyListenersSafely();
        _handleBoundary();
      }
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
      if (!permitted || _isDisposed || !_isValidSuggestion(suggestion)) {
        return false;
      }

      scheduled = await _notificationService.scheduleHavenWindowReminder(
        startsAt,
      );
      if (!scheduled || _isDisposed || !_isValidSuggestion(suggestion)) {
        if (scheduled) await _notificationService.cancelHavenWindowReminder();
        return false;
      }

      final nextHold = HavenWindowHold.held(
        startsAtUtc: startsAt.toUtc(),
        endsAtUtc: endsAt.toUtc(),
      );
      final preferences = await SharedPreferences.getInstance();
      final saved = await _saveHold(preferences, nextHold);
      if (!saved) {
        throw StateError('Haven Window hold boundaries were not saved.');
      }
      _hasPendingCleanup = false;
      if (_isDisposed || !_isValidSuggestion(suggestion)) {
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
          _hasPendingCleanup = true;
          PrivacySafeDiagnostics.report(
            FocusHavenDiagnosticEvent.havenWindowReminderCleanup,
            error: cleanupError,
          );
        }
      }
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowHold,
        error: error,
      );
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

      _hasPendingCleanup = false;
      _boundaryTimer?.cancel();
      _boundaryTimer = null;
      _hold = const HavenWindowHold.empty();
      return true;
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowRelease,
        error: error,
      );
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
          await _discardSavedState(preferences);
        }
      } else if (savedStart != null || savedEnd != null) {
        await _discardSavedState(preferences);
      }
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowLoad,
        error: error,
      );
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
      _hasPendingCleanup = false;
    } catch (error) {
      _hasPendingCleanup = true;
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowExpirationCleanup,
        error: error,
      );
    }
    _isUpdating = false;
    if (!_isDisposed) {
      _hold = const HavenWindowHold.empty();
      _notifyListenersSafely();
    }
  }

  Future<void> _discardSavedState(SharedPreferences preferences) async {
    try {
      await _clear(preferences);
      _hasPendingCleanup = false;
    } catch (error) {
      _hasPendingCleanup = true;
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowInvalidCleanup,
        error: error,
      );
    }
  }

  void _retryPendingCleanup() {
    if (_isDisposed || _isUpdating || !_hasPendingCleanup) return;

    _isUpdating = true;
    _notifyListenersSafely();
    unawaited(_completePendingCleanup());
  }

  Future<void> _completePendingCleanup() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await _clear(preferences);
      _hasPendingCleanup = false;
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.havenWindowPendingCleanup,
        error: error,
      );
    } finally {
      _isUpdating = false;
      _notifyListenersSafely();
    }
  }

  static Future<bool> _saveToPreferences(
    SharedPreferences preferences,
    HavenWindowHold hold,
  ) async {
    final results = await Future.wait([
      preferences.setInt(
        _startsAtUtcKey,
        hold.startsAtUtc!.microsecondsSinceEpoch,
      ),
      preferences.setInt(_endsAtUtcKey, hold.endsAtUtc!.microsecondsSinceEpoch),
    ]);
    return results.every((saved) => saved);
  }

  Future<void> _clear(SharedPreferences preferences) async {
    final cleared = await _clearHold(preferences);
    if (!cleared) {
      throw StateError('Haven Window hold boundaries were not cleared.');
    }
  }

  static Future<bool> _clearFromPreferences(
    SharedPreferences preferences,
  ) async {
    final results = await Future.wait([
      preferences.remove(_startsAtUtcKey),
      preferences.remove(_endsAtUtcKey),
    ]);
    return results.every((cleared) => cleared);
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
