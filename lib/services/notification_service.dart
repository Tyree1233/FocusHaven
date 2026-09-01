import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import 'haven_window_hold_service.dart';
import 'privacy_safe_diagnostics.dart';

abstract interface class ReminderNotificationClient {
  Future<bool> requestPermissions();
  Future<bool> scheduleDailyReminder(TimeOfDay time, Set<int> weekdays);
  Future<void> cancelDailyReminder();
}

typedef TimeZoneIdentifierLoader = Future<String> Function();
typedef ZonedNow = tz.TZDateTime Function(tz.Location location);

abstract interface class NotificationGateway {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> showSessionNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  });
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required tz.TZDateTime scheduledDate,
  });
  Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required tz.TZDateTime scheduledDate,
  });
  Future<void> cancelNotification(int id);
}

final class FlutterNotificationGateway implements NotificationGateway {
  FlutterNotificationGateway({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings: settings);
  }

  @override
  Future<bool> requestPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return (await _notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission()) ??
            false;
      case TargetPlatform.iOS:
        return (await _notifications
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true)) ??
            false;
      case TargetPlatform.macOS:
        return (await _notifications
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true)) ??
            false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  Future<void> showSessionNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_session_complete',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  @override
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required tz.TZDateTime scheduledDate,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_focus_reminder',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required tz.TZDateTime scheduledDate,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'haven_window_reminder',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelNotification(int id) => _notifications.cancel(id: id);
}

class NotificationService
    implements ReminderNotificationClient, HavenWindowReminderClient {
  NotificationService({
    NotificationGateway? gateway,
    AppLocalizations? localizations,
    TimeZoneIdentifierLoader? timeZoneIdentifierLoader,
    ZonedNow? zonedNow,
  }) : _gateway = gateway ?? FlutterNotificationGateway(),
       _localizations = localizations ?? defaultServiceLocalizations(),
       _loadTimeZoneIdentifier =
           timeZoneIdentifierLoader ?? _systemTimeZoneIdentifier,
       _zonedNow = zonedNow ?? _systemZonedNow;

  static const _dailyReminderId = 2000;
  static const _havenWindowReminderId = 2100;
  static const _maximumHavenWindowLeadTime = Duration(hours: 36);
  static const _weekdays = <int>{1, 2, 3, 4, 5, 6, 7};

  final NotificationGateway _gateway;
  final AppLocalizations _localizations;
  final TimeZoneIdentifierLoader _loadTimeZoneIdentifier;
  final ZonedNow _zonedNow;
  Future<void>? _initialization;
  Future<void>? _timeZoneConfiguration;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (kIsWeb) return;

    try {
      await _gateway.initialize();
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.notificationInitialize,
        error: error,
      );
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      return await _gateway.requestPermissions();
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.notificationPermission,
        error: error,
      );
      return false;
    }
  }

  Future<void> showTestNotification() => showSessionComplete(
    title: _localizations.notificationTestTitle,
    body: _localizations.notificationTestBody,
  );

  Future<void> showSessionComplete({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    try {
      await _gateway.showSessionNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
        channelName: _localizations.notificationFocusChannelName,
        channelDescription: _localizations.notificationFocusChannelDescription,
      );
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.notificationDisplay,
        error: error,
      );
    }
  }

  @override
  Future<bool> scheduleDailyReminder(TimeOfDay time, Set<int> weekdays) async {
    if (kIsWeb) return false;

    try {
      final selectedWeekdays = weekdays.where(_weekdays.contains).toList()
        ..sort();
      if (selectedWeekdays.isEmpty) return false;

      await _configureLocalTimeZone();
      await cancelDailyReminder();
      final now = _zonedNow(tz.local);

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

        await _gateway.scheduleDailyNotification(
          id: _dailyReminderId + weekday,
          title: _localizations.notificationDailyTitle,
          body: _localizations.notificationDailyBody,
          channelName: _localizations.notificationDailyChannelName,
          channelDescription:
              _localizations.notificationDailyChannelDescription,
          scheduledDate: scheduled,
        );
      }
      return true;
    } catch (error) {
      try {
        await cancelDailyReminder();
      } catch (cleanupError) {
        PrivacySafeDiagnostics.report(
          FocusHavenDiagnosticEvent.notificationPartialReminderCleanup,
          error: cleanupError,
        );
      }
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.notificationDailyReminderSchedule,
        error: error,
      );
      return false;
    }
  }

  @override
  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    for (final weekday in _weekdays) {
      await _gateway.cancelNotification(_dailyReminderId + weekday);
    }
  }

  @override
  Future<bool> scheduleHavenWindowReminder(DateTime startsAt) async {
    if (kIsWeb || startsAt.isUtc) return false;

    try {
      await _configureLocalTimeZone();
      final now = _zonedNow(tz.local);
      final scheduledDate = tz.TZDateTime.from(startsAt, tz.local);
      final leadTime = scheduledDate.difference(now);
      if (!scheduledDate.isAfter(now) ||
          leadTime > _maximumHavenWindowLeadTime) {
        return false;
      }

      await _gateway.scheduleOneTimeNotification(
        id: _havenWindowReminderId,
        title: _localizations.notificationHavenWindowTitle,
        body: _localizations.notificationHavenWindowBody,
        channelName: _localizations.notificationHavenWindowChannelName,
        channelDescription:
            _localizations.notificationHavenWindowChannelDescription,
        scheduledDate: scheduledDate,
      );
      return true;
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.notificationHavenWindowSchedule,
        error: error,
      );
      return false;
    }
  }

  @override
  Future<void> cancelHavenWindowReminder() async {
    if (kIsWeb) return;
    await _gateway.cancelNotification(_havenWindowReminderId);
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;

    final configuration = _timeZoneConfiguration ??=
        _performTimeZoneConfiguration();
    try {
      await configuration;
    } catch (_) {
      if (identical(_timeZoneConfiguration, configuration)) {
        _timeZoneConfiguration = null;
      }
      rethrow;
    }
  }

  Future<void> _performTimeZoneConfiguration() async {
    tz.initializeTimeZones();
    final identifier = await _loadTimeZoneIdentifier();
    tz.setLocalLocation(tz.getLocation(identifier));
  }

  static Future<String> _systemTimeZoneIdentifier() async {
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    return timeZoneInfo.identifier;
  }

  static tz.TZDateTime _systemZonedNow(tz.Location location) =>
      tz.TZDateTime.now(location);
}
