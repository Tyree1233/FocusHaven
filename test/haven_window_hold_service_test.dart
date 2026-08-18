import 'dart:async';

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
    _FakeHavenWindowNotifications notifications,
  ) async {
    final service = HavenWindowHoldService(
      notificationService: notifications,
      now: () => now,
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
  });

  final bool permissionGranted;
  final bool scheduleSucceeds;
  final Future<bool>? permissionResult;
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
    if (scheduleSucceeds) scheduledStarts.add(startsAt);
    return scheduleSucceeds;
  }

  @override
  Future<void> cancelHavenWindowReminder() async {
    cancelCalls += 1;
  }
}
