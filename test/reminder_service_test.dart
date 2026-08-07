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
  });

  test('loads a saved reminder time and enabled setting', () async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderEnabled': true,
      'dailyReminderHour': 18,
      'dailyReminderMinute': 30,
    });
    final service = await createService(FakeReminderNotifications());
    addTearDown(service.dispose);

    expect(service.isEnabled, isTrue);
    expect(service.time, const TimeOfDay(hour: 18, minute: 30));
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
    expect(notifications.scheduledTimes, [reminderTime]);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dailyReminderEnabled'), isTrue);
    expect(preferences.getInt('dailyReminderHour'), 10);
    expect(preferences.getInt('dailyReminderMinute'), 15);
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
  int cancelCalls = 0;

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalls += 1;
  }

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    if (scheduleSucceeds) scheduledTimes.add(time);
    return scheduleSucceeds;
  }
}
