import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  NotificationService createService(
    _FakeNotificationGateway gateway, {
    TimeZoneIdentifierLoader? timeZoneIdentifierLoader,
  }) {
    return NotificationService(
      gateway: gateway,
      timeZoneIdentifierLoader: timeZoneIdentifierLoader ?? () async => 'UTC',
      zonedNow: (location) => tz.TZDateTime(location, 2026, 8, 9, 10),
    );
  }

  test(
    'initialization is idempotent and does not request permission',
    () async {
      final gateway = _FakeNotificationGateway();
      final service = createService(gateway);

      await Future.wait([service.initialize(), service.initialize()]);

      expect(gateway.initializeCalls, 1);
      expect(gateway.permissionCalls, 0);
    },
  );

  test('permission results and failures are safely contained', () async {
    final gateway = _FakeNotificationGateway(permissionGranted: true);
    final service = createService(gateway);

    expect(await service.requestPermissions(), isTrue);

    gateway.throwOnPermission = true;
    expect(await service.requestPermissions(), isFalse);
    expect(gateway.permissionCalls, 2);
  });

  test('test notification uses the production-ready message', () async {
    final gateway = _FakeNotificationGateway();
    final service = createService(gateway);

    await service.showTestNotification();

    expect(gateway.shownNotifications, hasLength(1));
    expect(
      gateway.shownNotifications.single.title,
      'FocusHaven notifications are ready',
    );
    expect(
      gateway.shownNotifications.single.body,
      'You will see an alert when your focus timer ends.',
    );
  });

  test('rejects an empty set of valid reminder weekdays', () async {
    final gateway = _FakeNotificationGateway();
    var timeZoneLoads = 0;
    final service = createService(
      gateway,
      timeZoneIdentifierLoader: () async {
        timeZoneLoads += 1;
        return 'UTC';
      },
    );

    expect(
      await service.scheduleDailyReminder(const TimeOfDay(hour: 9, minute: 0), {
        0,
        8,
      }),
      isFalse,
    );
    expect(timeZoneLoads, 0);
    expect(gateway.scheduledNotifications, isEmpty);
    expect(gateway.cancelledIds, isEmpty);
  });

  test('schedules sorted weekdays at the next local occurrence', () async {
    final gateway = _FakeNotificationGateway();
    var timeZoneLoads = 0;
    final service = createService(
      gateway,
      timeZoneIdentifierLoader: () async {
        timeZoneLoads += 1;
        return 'UTC';
      },
    );

    final scheduled = await service.scheduleDailyReminder(
      const TimeOfDay(hour: 9, minute: 0),
      {DateTime.sunday, DateTime.monday, 0, 8},
    );

    expect(scheduled, isTrue);
    expect(timeZoneLoads, 1);
    expect(gateway.cancelledIds, [2001, 2002, 2003, 2004, 2005, 2006, 2007]);
    expect(gateway.scheduledNotifications.map((item) => item.id), [2001, 2007]);

    final monday = gateway.scheduledNotifications.first.scheduledDate;
    expect(monday.weekday, DateTime.monday);
    expect(monday.day, 10);
    expect(monday.hour, 9);

    final sunday = gateway.scheduledNotifications.last.scheduledDate;
    expect(sunday.weekday, DateTime.sunday);
    expect(sunday.day, 16);
    expect(sunday.hour, 9);
  });

  test('partial scheduling failure cancels every reminder ID', () async {
    final gateway = _FakeNotificationGateway()..failOnScheduleCall = 2;
    final service = createService(gateway);

    expect(
      await service.scheduleDailyReminder(const TimeOfDay(hour: 9, minute: 0), {
        DateTime.monday,
        DateTime.tuesday,
      }),
      isFalse,
    );
    expect(gateway.scheduleCalls, 2);
    expect(gateway.cancelledIds, hasLength(14));
    expect(gateway.cancelledIds.sublist(7), [
      2001,
      2002,
      2003,
      2004,
      2005,
      2006,
      2007,
    ]);
  });

  test('failed timezone setup can be retried', () async {
    final gateway = _FakeNotificationGateway();
    var timeZoneLoads = 0;
    final service = createService(
      gateway,
      timeZoneIdentifierLoader: () async {
        timeZoneLoads += 1;
        if (timeZoneLoads == 1) throw StateError('timezone unavailable');
        return 'UTC';
      },
    );

    expect(
      await service.scheduleDailyReminder(const TimeOfDay(hour: 9, minute: 0), {
        DateTime.monday,
      }),
      isFalse,
    );
    expect(
      await service.scheduleDailyReminder(const TimeOfDay(hour: 9, minute: 0), {
        DateTime.monday,
      }),
      isTrue,
    );
    expect(timeZoneLoads, 2);
    expect(gateway.scheduledNotifications, hasLength(1));
  });
}

typedef _ShownNotification = ({int id, String title, String body});
typedef _ScheduledNotification = ({
  int id,
  String title,
  String body,
  tz.TZDateTime scheduledDate,
});

final class _FakeNotificationGateway implements NotificationGateway {
  _FakeNotificationGateway({this.permissionGranted = false});

  bool permissionGranted;
  bool throwOnPermission = false;
  int? failOnScheduleCall;
  int initializeCalls = 0;
  int permissionCalls = 0;
  int scheduleCalls = 0;
  final List<_ShownNotification> shownNotifications = [];
  final List<_ScheduledNotification> scheduledNotifications = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionCalls += 1;
    if (throwOnPermission) throw StateError('permission unavailable');
    return permissionGranted;
  }

  @override
  Future<void> showSessionNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    shownNotifications.add((id: id, title: title, body: body));
  }

  @override
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    scheduleCalls += 1;
    if (scheduleCalls == failOnScheduleCall) {
      throw StateError('schedule failed');
    }
    scheduledNotifications.add((
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    ));
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }
}
