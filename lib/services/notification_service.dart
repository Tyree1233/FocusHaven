import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract interface class ReminderNotificationClient {
  Future<bool> requestPermissions();
  Future<bool> scheduleDailyReminder(TimeOfDay time, Set<int> weekdays);
  Future<void> cancelDailyReminder();
}

class NotificationService implements ReminderNotificationClient {
  static const _dailyReminderId = 2000;
  static const _weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _timeZoneConfigured = false;

  Future<void> initialize() async {
    if (kIsWeb) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    try {
      await _notifications.initialize(settings: settings);
      await requestPermissions();
    } catch (error) {
      debugPrint('Notification setup failed: $error');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return (await _notifications
                  .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin>()
                  ?.requestNotificationsPermission()) ??
              false;
        case TargetPlatform.iOS:
          return (await _notifications
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(alert: true, sound: true)) ??
              false;
        case TargetPlatform.macOS:
          return (await _notifications
                  .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(alert: true, sound: true)) ??
              false;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return false;
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  Future<void> showTestNotification() => showSessionComplete(
        title: 'FocusHaven notifications are ready',
        body: 'You will see an alert when your focus timer ends.',
      );

  Future<void> showSessionComplete({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_session_complete',
        'Focus session complete',
        channelDescription: 'Alerts when a FocusHaven timer finishes.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    try {
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (error) {
      debugPrint('Notification display failed: $error');
    }
  }

  @override
  Future<bool> scheduleDailyReminder(
    TimeOfDay time,
    Set<int> weekdays,
  ) async {
    if (kIsWeb) return false;

    try {
      final selectedWeekdays = weekdays.where(_weekdays.contains).toList()
        ..sort();
      if (selectedWeekdays.isEmpty) return false;

      await _configureLocalTimeZone();
      await cancelDailyReminder();
      final now = tz.TZDateTime.now(tz.local);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_focus_reminder',
          'Scheduled focus time',
          channelDescription:
              'A gentle invitation to begin a scheduled focus session.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        macOS:
            DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      for (final weekday in selectedWeekdays) {
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        await _notifications.zonedSchedule(
          id: _dailyReminderId + weekday,
          title: 'Your scheduled focus time',
          body: 'Whenever you are ready, make a little space for what matters.',
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return true;
    } catch (error) {
      await cancelDailyReminder();
      debugPrint('Scheduled focus reminder setup failed: $error');
      return false;
    }
  }

  @override
  Future<void> cancelDailyReminder() async {
    for (final weekday in _weekdays) {
      await _notifications.cancel(id: _dailyReminderId + weekday);
    }
  }

  Future<void> _configureLocalTimeZone() async {
    if (_timeZoneConfigured || kIsWeb) return;
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    _timeZoneConfigured = true;
  }
}
