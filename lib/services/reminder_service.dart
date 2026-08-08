import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ReminderService extends ChangeNotifier {
  static const _enabledKey = 'dailyReminderEnabled';
  static const _hourKey = 'dailyReminderHour';
  static const _minuteKey = 'dailyReminderMinute';
  static const _weekdaysKey = 'dailyReminderWeekdays';
  static const _allWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};

  factory ReminderService({
    required ReminderNotificationClient notificationService,
  }) {
    return ReminderService._(notificationService);
  }

  ReminderService._(this._notificationService) {
    _load();
  }

  final ReminderNotificationClient _notificationService;
  bool _isEnabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _weekdays = Set<int>.from(_allWeekdays);

  bool get isEnabled => _isEnabled;
  TimeOfDay get time => _time;
  Set<int> get weekdays => Set<int>.unmodifiable(_weekdays);

  Future<bool> setDailyReminder(TimeOfDay time, {Set<int>? weekdays}) async {
    final selectedWeekdays = (weekdays ?? _weekdays)
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet();
    if (selectedWeekdays.isEmpty) return false;

    final permitted = await _notificationService.requestPermissions();
    if (!permitted) return false;

    final scheduled = await _notificationService.scheduleDailyReminder(
      time,
      selectedWeekdays,
    );
    if (!scheduled) return false;

    _time = time;
    _weekdays = selectedWeekdays;
    _isEnabled = true;
    final preferences = await SharedPreferences.getInstance();
    final orderedWeekdays = selectedWeekdays.toList()..sort();
    await Future.wait([
      preferences.setBool(_enabledKey, true),
      preferences.setInt(_hourKey, time.hour),
      preferences.setInt(_minuteKey, time.minute),
      preferences.setStringList(
        _weekdaysKey,
        orderedWeekdays.map((day) => day.toString()).toList(),
      ),
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
      _time = TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    }
    final savedWeekdays = preferences.getStringList(_weekdaysKey);
    if (savedWeekdays != null) {
      final parsedWeekdays = savedWeekdays
          .map(int.tryParse)
          .whereType<int>()
          .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
          .toSet();
      if (parsedWeekdays.isNotEmpty) _weekdays = parsedWeekdays;
    }
    notifyListeners();
  }
}
