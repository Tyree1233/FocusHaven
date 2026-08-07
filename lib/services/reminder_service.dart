import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ReminderService extends ChangeNotifier {
  static const _enabledKey = 'dailyReminderEnabled';
  static const _hourKey = 'dailyReminderHour';
  static const _minuteKey = 'dailyReminderMinute';

  ReminderService({required ReminderNotificationClient notificationService})
      : _notificationService = notificationService {
    _load();
  }

  final ReminderNotificationClient _notificationService;
  bool _isEnabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  bool get isEnabled => _isEnabled;
  TimeOfDay get time => _time;

  Future<bool> setDailyReminder(TimeOfDay time) async {
    final permitted = await _notificationService.requestPermissions();
    if (!permitted) return false;

    final scheduled = await _notificationService.scheduleDailyReminder(time);
    if (!scheduled) return false;

    _time = time;
    _isEnabled = true;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool(_enabledKey, true),
      preferences.setInt(_hourKey, time.hour),
      preferences.setInt(_minuteKey, time.minute),
    ]);
    notifyListeners();
    return true;
  }

  Future<void> disableDailyReminder() async {
    await _notificationService.cancelDailyReminder();
    _isEnabled = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    notifyListeners();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _isEnabled = preferences.getBool(_enabledKey) ?? false;
    final hour = preferences.getInt(_hourKey);
    final minute = preferences.getInt(_minuteKey);
    if (hour != null && minute != null) {
      _time = TimeOfDay(
        hour: hour.clamp(0, 23),
        minute: minute.clamp(0, 59),
      );
    }
    notifyListeners();
  }
}
