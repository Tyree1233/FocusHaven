import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/notification_service.dart';
import 'package:focushaven/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ReminderService> createService(
    FakeReminderNotifications notifications,
  ) async {
    final service = ReminderService(notificationService: notifications);
    await Future<void>.delayed(Duration.zero);
    return service;
  }

  test('starts with reminders disabled at 9:00 AM', () async {
    final service = await createService(FakeReminderNotifications());
    addTearDown(service.dispose);

    expect(service.isEnabled, isFalse);
    expect(service.time, const TimeOfDay(hour: 9, minute: 0));
    expect(service.weekdays, {1, 2, 3, 4, 5, 6, 7});
  });

  test('loads a saved reminder time and enabled setting', () async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderEnabled': true,
      'dailyReminderHour': 18,
      'dailyReminderMinute': 30,
      'dailyReminderWeekdays': ['1', '3', '5'],
    });
    final service = await createService(FakeReminderNotifications());
    addTearDown(service.dispose);

    expect(service.isEnabled, isTrue);
    expect(service.time, const TimeOfDay(hour: 18, minute: 30));
    expect(service.weekdays, {1, 3, 5});
  });

  test('clamps an invalid saved reminder time to a valid time', () async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderHour': 42,
      'dailyReminderMinute': -5,
    });
    final service = await createService(FakeReminderNotifications());
    addTearDown(service.dispose);

    expect(service.time, const TimeOfDay(hour: 23, minute: 0));
  });

  test('does not enable a reminder when permission is declined', () async {
    final notifications = FakeReminderNotifications(permissionGranted: false);
    final service = await createService(notifications);
    addTearDown(service.dispose);

    final enabled = await service.setDailyReminder(
      const TimeOfDay(hour: 10, minute: 15),
    );

    expect(enabled, isFalse);
    expect(notifications.scheduledTimes, isEmpty);
    expect(service.isEnabled, isFalse);
  });

  test('saves a successfully scheduled daily reminder', () async {
    final notifications = FakeReminderNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);
    const reminderTime = TimeOfDay(hour: 10, minute: 15);

    final enabled = await service.setDailyReminder(reminderTime);

    expect(enabled, isTrue);
    expect(service.isEnabled, isTrue);
    expect(service.time, reminderTime);
    expect(service.weekdays, {1, 2, 3, 4, 5, 6, 7});
    expect(notifications.scheduledTimes, [reminderTime]);
    expect(notifications.scheduledWeekdays, [
      {1, 2, 3, 4, 5, 6, 7},
    ]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dailyReminderEnabled'), isTrue);
    expect(preferences.getInt('dailyReminderHour'), 10);
    expect(preferences.getInt('dailyReminderMinute'), 15);
    expect(
      preferences.getStringList('dailyReminderWeekdays'),
      ['1', '2', '3', '4', '5', '6', '7'],
    );
  });

  test('saves selected weekdays for a scheduled focus time', () async {
    final notifications = FakeReminderNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);

    final enabled = await service.setDailyReminder(
      const TimeOfDay(hour: 7, minute: 30),
      weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
    );

    expect(enabled, isTrue);
    expect(service.weekdays, {1, 3, 5});
    expect(notifications.scheduledWeekdays.single, {1, 3, 5});
  });

  test('disabling a reminder cancels it and saves the disabled setting',
      () async {
    final notifications = FakeReminderNotifications();
    final service = await createService(notifications);
    addTearDown(service.dispose);

    await service.setDailyReminder(const TimeOfDay(hour: 8, minute: 0));
    await service.disableDailyReminder();

    expect(service.isEnabled, isFalse);
    expect(notifications.cancelCalls, 1);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dailyReminderEnabled'), isFalse);
  });
}

class FakeReminderNotifications implements ReminderNotificationClient {
  FakeReminderNotifications({
    this.permissionGranted = true,
    this.scheduleSucceeds = true,
  });

  final bool permissionGranted;
  final bool scheduleSucceeds;
  final List<TimeOfDay> scheduledTimes = [];
  final List<Set<int>> scheduledWeekdays = [];
  int cancelCalls = 0;

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalls += 1;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<bool> scheduleDailyReminder(
    TimeOfDay time,
    Set<int> weekdays,
  ) async {
    if (scheduleSucceeds) {
      scheduledTimes.add(time);
      scheduledWeekdays.add(Set<int>.from(weekdays));
    }
    return scheduleSucceeds;
  }
}
