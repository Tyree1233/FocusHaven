import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_window_hold.dart';
import 'package:focushaven/models/haven_window_suggestion.dart';
import 'package:focushaven/services/haven_window_hold_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 8, 18, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HavenWindowSuggestion opening({
    DateTime? startsAt,
    DateTime? endsAt,
    HavenWindowKind kind = HavenWindowKind.opening,
  }) {
    final start = startsAt ?? now.add(const Duration(hours: 1));
    return HavenWindowSuggestion(
      kind: kind,
      headline: 'A possible Haven Window is open',
      detail: 'Optional local opening.',
      evidence: 'Busy boundaries only.',
      startsAt: start,
      endsAt: endsAt ?? start.add(const Duration(minutes: 25)),
    );
  }

  Future<HavenWindowHoldService> createService(
    _FakeHavenWindowNotifications notifications, {
    DateTime Function()? nowSource,
    HavenWindowBoundaryTimerFactory? boundaryTimerFactory,
  }) async {
    final service = HavenWindowHoldService(
      notificationService: notifications,
      now: nowSource ?? () => now,
      boundaryTimerFactory: boundaryTimerFactory,
    );
    await service.initialized;
    return service;
  }

  test('restoration stays empty without requesting or scheduling', () async {
    final notifications = _FakeHavenWindowNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);

    expect(service.holdState, isA<HavenWindowHold>());
    expect(service.holdState.isHeld, isFalse);
    expect(notifications.permissionCalls, 0);
    expect(notifications.scheduleCalls, 0);
    expect(notifications.cancelCalls, 0);
  });

  test(
    'one explicit hold requests permission and stores UTC boundaries',
    () async {
      final notifications = _FakeHavenWindowNotifications();
      final service = await createService(notifications);
      addTearDown(service.dispose);
      final suggestion = opening();

      expect(await service.hold(suggestion), isTrue);

      expect(notifications.permissionCalls, 1);
      expect(notifications.scheduledStarts, [suggestion.startsAt]);
      expect(service.holdState.isHeld, isTrue);
      expect(service.holdState.startsAtUtc, suggestion.startsAt!.toUtc());
      expect(service.holdState.endsAtUtc, suggestion.endsAt!.toUtc());

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt('havenWindowHoldStartsAtUtcMicros'),
        suggestion.startsAt!.toUtc().microsecondsSinceEpoch,
      );
      expect(
        preferences.getInt('havenWindowHoldEndsAtUtcMicros'),
        suggestion.endsAt!.toUtc().microsecondsSinceEpoch,
      );
    },
  );

  test('declined notification permission leaves no hold', () async {
    final notifications = _FakeHavenWindowNotifications(
      permissionGranted: false,
    );
    final service = await createService(notifications);
    addTearDown(service.dispose);

    expect(await service.hold(opening()), isFalse);
    expect(notifications.permissionCalls, 1);
    expect(notifications.scheduleCalls, 0);
    expect(service.holdState.isHeld, isFalse);
  });

  test('an opening that passes during consent is never scheduled', () async {
    var currentTime = now;
    final permission = Completer<bool>();
    final notifications = _FakeHavenWindowNotifications(
      permissionResult: permission.future,
    );
    final service = await createService(
      notifications,
      nowSource: () => currentTime,
    );
    addTearDown(service.dispose);
    final suggestion = opening(
      startsAt: now.add(const Duration(minutes: 1)),
      endsAt: now.add(const Duration(minutes: 26)),
    );

    final holdResult = service.hold(suggestion);
    await Future<void>.delayed(Duration.zero);
    expect(notifications.permissionCalls, 1);

    currentTime = suggestion.startsAt!;
    permission.complete(true);

    expect(await holdResult, isFalse);
    expect(notifications.scheduleCalls, 0);
    expect(notifications.cancelCalls, 0);
    expect(service.holdState.isHeld, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
    expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
  });

  test('an opening that passes during scheduling is cancelled', () async {
    var currentTime = now;
    final schedule = Completer<bool>();
    final notifications = _FakeHavenWindowNotifications(
      scheduleResult: schedule.future,
    );
    final service = await createService(
      notifications,
      nowSource: () => currentTime,
    );
    addTearDown(service.dispose);
    final suggestion = opening(
      startsAt: now.add(const Duration(minutes: 1)),
      endsAt: now.add(const Duration(minutes: 26)),
    );

    final holdResult = service.hold(suggestion);
    await Future<void>.delayed(Duration.zero);
    expect(notifications.permissionCalls, 1);
    expect(notifications.scheduleCalls, 1);

    currentTime = suggestion.startsAt!;
    schedule.complete(true);

    expect(await holdResult, isFalse);
    expect(notifications.cancelCalls, 1);
    expect(service.holdState.isHeld, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
    expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
  });

  test('invalid or distant openings never request permission', () async {
    final notifications = _FakeHavenWindowNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);

    final invalidSuggestions = [
      opening(kind: HavenWindowKind.learning),
      opening(startsAt: now.subtract(const Duration(minutes: 1))),
      opening(startsAt: now.add(const Duration(hours: 37))),
      opening(
        startsAt: now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 3, minutes: 1)),
      ),
      opening(
        startsAt: now.add(const Duration(hours: 1)).toUtc(),
        endsAt: now.add(const Duration(hours: 2)).toUtc(),
      ),
    ];

    for (final suggestion in invalidSuggestions) {
      expect(await service.hold(suggestion), isFalse);
    }

    expect(notifications.permissionCalls, 0);
    expect(notifications.scheduleCalls, 0);
  });

  test('a failed schedule cannot create persisted hold state', () async {
    final notifications = _FakeHavenWindowNotifications(
      scheduleSucceeds: false,
    );
    final service = await createService(notifications);
    addTearDown(service.dispose);

    expect(await service.hold(opening()), isFalse);
    expect(service.holdState.isHeld, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
    expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
  });

  test('a valid saved hold loads without rescheduling', () async {
    final startsAtUtc = now.add(const Duration(hours: 2)).toUtc();
    final endsAtUtc = startsAtUtc.add(const Duration(minutes: 25));
    SharedPreferences.setMockInitialValues({
      'havenWindowHoldStartsAtUtcMicros': startsAtUtc.microsecondsSinceEpoch,
      'havenWindowHoldEndsAtUtcMicros': endsAtUtc.microsecondsSinceEpoch,
    });
    final notifications = _FakeHavenWindowNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);

    expect(service.holdState.isHeld, isTrue);
    expect(service.holdState.startsAtUtc, startsAtUtc);
    expect(service.holdState.endsAtUtc, endsAtUtc);
    expect(notifications.permissionCalls, 0);
    expect(notifications.scheduleCalls, 0);
  });

  test(
    'an in-progress saved hold restores as arrived without rescheduling',
    () async {
      final startsAtUtc = now.subtract(const Duration(minutes: 5)).toUtc();
      final endsAtUtc = now.add(const Duration(minutes: 20)).toUtc();
      SharedPreferences.setMockInitialValues({
        'havenWindowHoldStartsAtUtcMicros': startsAtUtc.microsecondsSinceEpoch,
        'havenWindowHoldEndsAtUtcMicros': endsAtUtc.microsecondsSinceEpoch,
      });
      final notifications = _FakeHavenWindowNotifications();
      final service = await createService(notifications);
      addTearDown(service.dispose);

      expect(service.holdState.isHeld, isTrue);
      expect(service.holdState.hasArrived, isTrue);
      expect(service.holdState.startsAtUtc, startsAtUtc);
      expect(service.holdState.endsAtUtc, endsAtUtc);
      expect(notifications.permissionCalls, 0);
      expect(notifications.scheduleCalls, 0);
    },
  );

  test('a held window arrives and expires at its local boundaries', () async {
    var currentTime = now;
    final timers = _ManualBoundaryTimers();
    final notifications = _FakeHavenWindowNotifications();
    final service = await createService(
      notifications,
      nowSource: () => currentTime,
      boundaryTimerFactory: timers.create,
    );
    addTearDown(service.dispose);
    final suggestion = opening();

    expect(await service.hold(suggestion), isTrue);
    expect(service.holdState.hasArrived, isFalse);
    expect(timers.active.single.duration, const Duration(hours: 1));

    currentTime = suggestion.startsAt!;
    timers.fireNext();
    expect(service.holdState.isHeld, isTrue);
    expect(service.holdState.hasArrived, isTrue);
    expect(timers.active.single.duration, const Duration(minutes: 25));

    currentTime = suggestion.endsAt!;
    timers.fireNext();
    await pumpEventQueue();
    expect(service.holdState.isHeld, isFalse);
    expect(timers.active, isEmpty);
    expect(notifications.cancelCalls, 0);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
    expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
  });

  test(
    'foreground resume catches up an arrived hold without new access',
    () async {
      var currentTime = now;
      final timers = _ManualBoundaryTimers();
      final notifications = _FakeHavenWindowNotifications();
      final service = await createService(
        notifications,
        nowSource: () => currentTime,
        boundaryTimerFactory: timers.create,
      );
      addTearDown(service.dispose);
      final suggestion = opening();

      expect(await service.hold(suggestion), isTrue);
      final suspendedTimer = timers.active.single;
      currentTime = suggestion.startsAt!.add(const Duration(minutes: 4));

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(suspendedTimer.isActive, isFalse);
      expect(service.holdState.isHeld, isTrue);
      expect(service.holdState.hasArrived, isTrue);
      expect(timers.active.single.duration, const Duration(minutes: 21));
      expect(notifications.permissionCalls, 1);
      expect(notifications.scheduleCalls, 1);
      expect(notifications.cancelCalls, 0);
    },
  );

  test(
    'foreground resume expires a passed hold without rescheduling',
    () async {
      var currentTime = now;
      final timers = _ManualBoundaryTimers();
      final notifications = _FakeHavenWindowNotifications();
      final service = await createService(
        notifications,
        nowSource: () => currentTime,
        boundaryTimerFactory: timers.create,
      );
      addTearDown(service.dispose);
      final suggestion = opening();

      expect(await service.hold(suggestion), isTrue);
      currentTime = suggestion.endsAt!;

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(service.holdState.isHeld, isFalse);
      expect(timers.active, isEmpty);
      expect(notifications.permissionCalls, 1);
      expect(notifications.scheduleCalls, 1);
      expect(notifications.cancelCalls, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
      expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
    },
  );

  test('expired, oversized, and incomplete saved holds fail closed', () async {
    final invalidStates = [
      {
        'havenWindowHoldStartsAtUtcMicros': now
            .subtract(const Duration(hours: 1))
            .toUtc()
            .microsecondsSinceEpoch,
        'havenWindowHoldEndsAtUtcMicros': now
            .subtract(const Duration(minutes: 30))
            .toUtc()
            .microsecondsSinceEpoch,
      },
      {
        'havenWindowHoldStartsAtUtcMicros': now
            .add(const Duration(hours: 37))
            .toUtc()
            .microsecondsSinceEpoch,
        'havenWindowHoldEndsAtUtcMicros': now
            .add(const Duration(hours: 38))
            .toUtc()
            .microsecondsSinceEpoch,
      },
      {
        'havenWindowHoldStartsAtUtcMicros': now
            .add(const Duration(hours: 1))
            .toUtc()
            .microsecondsSinceEpoch,
      },
    ];

    for (final state in invalidStates) {
      SharedPreferences.setMockInitialValues(state);
      final service = await createService(_FakeHavenWindowNotifications());
      expect(service.holdState.isHeld, isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
      expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
      service.dispose();
    }
  });

  test('release cancels the reminder and removes local boundaries', () async {
    final notifications = _FakeHavenWindowNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);
    await service.hold(opening());

    expect(await service.release(), isTrue);

    expect(notifications.cancelCalls, 1);
    expect(service.holdState.isHeld, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('havenWindowHoldStartsAtUtcMicros'), isNull);
    expect(preferences.get('havenWindowHoldEndsAtUtcMicros'), isNull);
  });

  test('overlapping explicit holds are serialized', () async {
    final permission = Completer<bool>();
    final notifications = _FakeHavenWindowNotifications(
      permissionResult: permission.future,
    );
    final service = await createService(notifications);
    addTearDown(service.dispose);

    final first = service.hold(opening());
    await Future<void>.delayed(Duration.zero);
    expect(service.isUpdating, isTrue);
    expect(await service.hold(opening()), isFalse);

    permission.complete(true);
    expect(await first, isTrue);
    expect(notifications.permissionCalls, 1);
    expect(notifications.scheduleCalls, 1);
  });

  test('actions are safely contained after disposal', () async {
    final notifications = _FakeHavenWindowNotifications();
    final service = HavenWindowHoldService(
      notificationService: notifications,
      now: () => now,
    );
    service.dispose();
    await service.initialized;

    expect(await service.hold(opening()), isFalse);
    expect(await service.release(), isFalse);
    expect(notifications.permissionCalls, 0);
    expect(notifications.scheduleCalls, 0);
    expect(notifications.cancelCalls, 0);
  });
}

final class _FakeHavenWindowNotifications implements HavenWindowReminderClient {
  _FakeHavenWindowNotifications({
    this.permissionGranted = true,
    this.scheduleSucceeds = true,
    this.permissionResult,
    this.scheduleResult,
  });

  final bool permissionGranted;
  final bool scheduleSucceeds;
  final Future<bool>? permissionResult;
  final Future<bool>? scheduleResult;
  int permissionCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  final List<DateTime> scheduledStarts = [];

  @override
  Future<bool> requestPermissions() async {
    permissionCalls += 1;
    final result = permissionResult;
    return result == null ? permissionGranted : await result;
  }

  @override
  Future<bool> scheduleHavenWindowReminder(DateTime startsAt) async {
    scheduleCalls += 1;
    final result = scheduleResult;
    final succeeds = result == null ? scheduleSucceeds : await result;
    if (succeeds) scheduledStarts.add(startsAt);
    return succeeds;
  }

  @override
  Future<void> cancelHavenWindowReminder() async {
    cancelCalls += 1;
  }
}

final class _ManualBoundaryTimers {
  final List<_ManualTimer> _timers = [];

  List<_ManualTimer> get active =>
      _timers.where((timer) => timer.isActive).toList(growable: false);

  Timer create(Duration duration, void Function() callback) {
    final timer = _ManualTimer(duration, callback);
    _timers.add(timer);
    return timer;
  }

  void fireNext() => active.first.fire();
}

final class _ManualTimer implements Timer {
  _ManualTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;

  @override
  void cancel() => _isActive = false;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _callback();
  }
}
