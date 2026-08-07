import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';
import 'notification_service.dart';

enum SessionType { focus, shortBreak, longBreak }

extension SessionTypeDetails on SessionType {
  String get label => switch (this) {
        SessionType.focus => 'Focus',
        SessionType.shortBreak => 'Short break',
        SessionType.longBreak => 'Long break',
      };

  String get encouragement => switch (this) {
        SessionType.focus => 'Give your full attention to one thing.',
        SessionType.shortBreak => 'Step away and let your mind breathe.',
        SessionType.longBreak => 'You earned a longer moment to recharge.',
      };
}

class TimerService extends ChangeNotifier with WidgetsBindingObserver {
  static const _timerEndsAtKey = 'timerEndsAt';
  static const _pendingResumeKey = 'hasPendingTimerResume';
  static const _defaultFocusSeconds = 25 * 60;
  static const _defaultShortBreakSeconds = 5 * 60;
  static const _defaultLongBreakSeconds = 15 * 60;
  static const _defaultDailyGoalMinutes = 60;
  static const _dailyChallengeTarget = 3;

  Timer? _ticker;
  int _focusSeconds = _defaultFocusSeconds;
  int _shortBreakSeconds = _defaultShortBreakSeconds;
  int _longBreakSeconds = _defaultLongBreakSeconds;
  int _secondsRemaining = _defaultFocusSeconds;
  int _totalSessionSeconds = _defaultFocusSeconds;
  int _completedFocusSessions = 0;
  List<FocusSession> _focusHistory = [];
  List<String> _distractions = [];
  String _focusTask = '';
  int _dailyGoalMinutes = _defaultDailyGoalMinutes;
  bool _isRunning = false;
  bool _isComplete = false;
  bool _hasPendingResume = false;
  bool _hasLoaded = false;
  DateTime? _endsAt;
  SessionType _sessionType = SessionType.focus;
  final NotificationService? _notificationService;

  int get secondsRemaining => _secondsRemaining;
  int get totalSessionSeconds => _totalSessionSeconds;
  int get completedFocusSessions => _completedFocusSessions;
  String get focusTask => _focusTask;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  Map<String, dynamic> get cloudBackup => {
        'focusSeconds': _focusSeconds,
        'shortBreakSeconds': _shortBreakSeconds,
        'longBreakSeconds': _longBreakSeconds,
        'completedFocusSessions': _completedFocusSessions,
        'focusTask': _focusTask,
        'dailyGoalMinutes': _dailyGoalMinutes,
        'focusHistory':
            _focusHistory.map((session) => session.toJson()).toList(),
      };
  List<FocusSession> get recentFocusSessions =>
      List.unmodifiable(_focusHistory.reversed);
  List<String> get distractions => List.unmodifiable(_distractions.reversed);
  int get totalFocusSeconds => _focusHistory.fold(
      0, (total, session) => total + session.durationSeconds);

  /// A private, readable summary that can be copied to the user's clipboard.
  /// FocusHaven never sends this text anywhere on its own.
  String get focusHistoryExport {
    final buffer = StringBuffer()
      ..writeln('FocusHaven focus history')
      ..writeln('Exported: ${_exportDateTime(DateTime.now())}')
      ..writeln()
      ..writeln('Summary')
      ..writeln('- Total focus time: ${_exportDuration(totalFocusSeconds)}')
      ..writeln('- Completed sessions: $completedFocusSessions')
      ..writeln(
          '- Current streak: $currentStreak ${currentStreak == 1 ? 'day' : 'days'}')
      ..writeln('- Daily goal: $dailyGoalMinutes minutes')
      ..writeln()
      ..writeln('Sessions');

    if (_focusHistory.isEmpty) {
      buffer.writeln('- No completed focus sessions yet.');
    } else {
      for (final session in recentFocusSessions) {
        final task = session.focusTask?.trim();
        final taskLabel = task == null || task.isEmpty ? 'Focus session' : task;
        buffer.writeln(
          '- ${_exportDateTime(session.completedAt)} — '
          '${_exportDuration(session.durationSeconds)} — $taskLabel',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  int get todayFocusMinutes => _focusHistory
      .where((session) => _isSameDay(session.completedAt, DateTime.now()))
      .fold(0, (total, session) => total + (session.durationSeconds ~/ 60));
  int get todayFocusSeconds => _focusHistory
      .where((session) => _isSameDay(session.completedAt, DateTime.now()))
      .fold(0, (total, session) => total + session.durationSeconds);
  int get todayFocusSessions => _focusHistory
      .where((session) => _isSameDay(session.completedAt, DateTime.now()))
      .length;
  List<int> get lastSevenDaysFocusSeconds {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return _focusHistory
          .where((session) => _isSameDay(session.completedAt, day))
          .fold(0, (total, session) => total + session.durationSeconds);
    });
  }

  int get weeklyFocusSeconds =>
      lastSevenDaysFocusSeconds.fold(0, (total, seconds) => total + seconds);
  int get weeklyFocusSessions {
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    return _focusHistory
        .where((session) => !session.completedAt.isBefore(cutoff))
        .length;
  }

  int get dailyChallengeTarget => _dailyChallengeTarget;
  double get dailyChallengeProgress =>
      (todayFocusSessions / _dailyChallengeTarget).clamp(0, 1);
  bool get hasCompletedDailyChallenge =>
      todayFocusSessions >= _dailyChallengeTarget;
  double get dailyGoalProgress => _dailyGoalMinutes == 0
      ? 0
      : (todayFocusSeconds / (_dailyGoalMinutes * 60)).clamp(0, 1);
  bool get hasReachedDailyGoal => todayFocusSeconds >= _dailyGoalMinutes * 60;
  int get currentStreak {
    final completedDays =
        _focusHistory.map((session) => _dateKey(session.completedAt)).toSet();
    var streak = 0;
    var day = DateTime.now();
    while (completedDays.contains(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  bool get isRunning => _isRunning;
  bool get isComplete => _isComplete;
  bool get hasPendingResume => _hasPendingResume;
  SessionType get sessionType => _sessionType;
  String get completionMessage => _completionMessage;
  double get progress => _totalSessionSeconds == 0
      ? 0
      : 1 - (_secondsRemaining / _totalSessionSeconds);

  TimerService({NotificationService? notificationService})
      : _notificationService = notificationService {
    WidgetsBinding.instance.addObserver(this);
    _loadFromPrefs();
  }

  void start() {
    if (_isRunning || _isComplete || _secondsRemaining == 0) return;
    _hasPendingResume = false;
    _isRunning = true;
    _endsAt = DateTime.now().add(Duration(seconds: _secondsRemaining));
    _startTicker();
    notifyListeners();
    _saveToPrefs();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endsAt = _endsAt;
      if (endsAt == null) return;
      final remaining =
          (endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (remaining <= 0) {
        _secondsRemaining = 0;
        _finishSession();
      } else {
        _secondsRemaining = remaining;
        notifyListeners();
      }
    });
  }

  void _synchronizeWithDeadline() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final remaining =
        (endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    if (remaining <= 0) {
      _secondsRemaining = 0;
      _finishSession();
    } else {
      _secondsRemaining = remaining;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasLoaded) return;
    if (state == AppLifecycleState.resumed) {
      _synchronizeWithDeadline();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveToPrefs();
    }
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _hasPendingResume = false;
    _endsAt = null;
    notifyListeners();
    _saveToPrefs();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _isComplete = false;
    _hasPendingResume = false;
    _endsAt = null;
    _secondsRemaining = _durationFor(_sessionType);
    _totalSessionSeconds = _secondsRemaining;
    notifyListeners();
    _saveToPrefs();
  }

  void selectSession(SessionType type) {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _isComplete = false;
    _hasPendingResume = false;
    _endsAt = null;
    _sessionType = type;
    _secondsRemaining = _durationFor(type);
    _totalSessionSeconds = _secondsRemaining;
    notifyListeners();
    _saveToPrefs();
  }

  void beginNextSession() {
    if (_sessionType == SessionType.focus) {
      final isLongBreak =
          _completedFocusSessions > 0 && _completedFocusSessions % 4 == 0;
      selectSession(
          isLongBreak ? SessionType.longBreak : SessionType.shortBreak);
    } else {
      selectSession(SessionType.focus);
    }
  }

  void resumePendingSession() {
    if (!_hasPendingResume) return;
    _hasPendingResume = false;
    start();
  }

  void discardPendingSession() {
    if (!_hasPendingResume) return;
    _hasPendingResume = false;
    reset();
  }

  void setCustomDuration(int minutes, int seconds) {
    final totalSeconds =
        (minutes * 60 + seconds).clamp(1, 24 * 60 * 60).toInt();
    switch (_sessionType) {
      case SessionType.focus:
        _focusSeconds = totalSeconds;
        break;
      case SessionType.shortBreak:
        _shortBreakSeconds = totalSeconds;
        break;
      case SessionType.longBreak:
        _longBreakSeconds = totalSeconds;
        break;
    }
    reset();
  }

  void setCustomMinutes(int minutes) => setCustomDuration(minutes, 0);

  void setFocusTask(String task) {
    _focusTask = task.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (_focusTask.length > 80) {
      _focusTask = _focusTask.substring(0, 80);
    }
    notifyListeners();
    _saveToPrefs();
  }

  void captureDistraction(String distraction) {
    final cleaned = distraction.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    _distractions
        .add(cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned);
    notifyListeners();
    _saveToPrefs();
  }

  void updateDistraction(int index, String distraction) {
    if (index < 0 || index >= _distractions.length) return;
    final cleaned = distraction.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    _distractions[index] =
        cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned;
    notifyListeners();
    _saveToPrefs();
  }

  void removeDistractionAt(int index) {
    if (index < 0 || index >= _distractions.length) return;
    _distractions.removeAt(index);
    notifyListeners();
    _saveToPrefs();
  }

  void clearDistractions() {
    if (_distractions.isEmpty) return;
    _distractions = [];
    notifyListeners();
    _saveToPrefs();
  }

  void setDailyGoalMinutes(int minutes) {
    _dailyGoalMinutes = minutes.clamp(5, 480).toInt();
    notifyListeners();
    _saveToPrefs();
  }

  void clearFocusHistory() {
    _focusHistory = [];
    _completedFocusSessions = 0;
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> clearLocalData() async {
    _ticker?.cancel();
    _ticker = null;
    _focusSeconds = _defaultFocusSeconds;
    _shortBreakSeconds = _defaultShortBreakSeconds;
    _longBreakSeconds = _defaultLongBreakSeconds;
    _secondsRemaining = _defaultFocusSeconds;
    _totalSessionSeconds = _defaultFocusSeconds;
    _completedFocusSessions = 0;
    _focusHistory = [];
    _distractions = [];
    _focusTask = '';
    _dailyGoalMinutes = _defaultDailyGoalMinutes;
    _isRunning = false;
    _isComplete = false;
    _hasPendingResume = false;
    _endsAt = null;
    _sessionType = SessionType.focus;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('focusSeconds'),
      prefs.remove('shortBreakSeconds'),
      prefs.remove('longBreakSeconds'),
      prefs.remove('secondsRemaining'),
      prefs.remove('totalSessionSeconds'),
      prefs.remove('completedFocusSessions'),
      prefs.remove('focusTask'),
      prefs.remove('dailyGoalMinutes'),
      prefs.remove('sessionType'),
      prefs.remove(_timerEndsAtKey),
      prefs.remove(_pendingResumeKey),
      prefs.remove('focusHistory'),
      prefs.remove('distractions'),
    ]);
    notifyListeners();
  }

  bool restoreCloudBackup(Map<String, dynamic> backup) {
    try {
      final focusSeconds = backup['focusSeconds'];
      final shortBreakSeconds = backup['shortBreakSeconds'];
      final longBreakSeconds = backup['longBreakSeconds'];
      final completedFocusSessions = backup['completedFocusSessions'];
      final history = backup['focusHistory'];
      final focusTask = backup['focusTask'];
      final dailyGoalMinutes = backup['dailyGoalMinutes'];

      if (focusSeconds is! int ||
          shortBreakSeconds is! int ||
          longBreakSeconds is! int ||
          completedFocusSessions is! int ||
          history is! List ||
          (focusTask != null && focusTask is! String) ||
          (dailyGoalMinutes != null && dailyGoalMinutes is! int)) {
        return false;
      }

      final restoredHistory = history
          .whereType<Map>()
          .map((item) => FocusSession.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      _ticker?.cancel();
      _ticker = null;
      _isRunning = false;
      _isComplete = false;
      _hasPendingResume = false;
      _endsAt = null;
      _focusSeconds = focusSeconds.clamp(1, 24 * 60 * 60).toInt();
      _shortBreakSeconds = shortBreakSeconds.clamp(1, 24 * 60 * 60).toInt();
      _longBreakSeconds = longBreakSeconds.clamp(1, 24 * 60 * 60).toInt();
      _completedFocusSessions =
          completedFocusSessions.clamp(0, 1 << 31).toInt();
      _focusHistory = restoredHistory;
      _focusTask = focusTask ?? '';
      if (dailyGoalMinutes != null) {
        _dailyGoalMinutes = dailyGoalMinutes.clamp(5, 480).toInt();
      }
      _sessionType = SessionType.focus;
      _totalSessionSeconds = _focusSeconds;
      _secondsRemaining = _focusSeconds;
      notifyListeners();
      _saveToPrefs();
      return true;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  void _finishSession() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _isComplete = true;
    _hasPendingResume = false;
    _endsAt = null;
    unawaited(
      _notificationService?.showSessionComplete(
            title: '${_sessionType.label} complete',
            body: _completionMessage,
          ) ??
          Future<void>.value(),
    );
    if (_sessionType == SessionType.focus) {
      _completedFocusSessions++;
      _focusHistory.add(
        FocusSession(
          completedAt: DateTime.now(),
          durationSeconds: _totalSessionSeconds,
          focusTask: _focusTask.isEmpty ? null : _focusTask,
        ),
      );
    }
    notifyListeners();
    _saveToPrefs();
  }

  int _durationFor(SessionType type) => switch (type) {
        SessionType.focus => _focusSeconds,
        SessionType.shortBreak => _shortBreakSeconds,
        SessionType.longBreak => _longBreakSeconds,
      };

  String get _completionMessage => switch (_sessionType) {
        SessionType.focus =>
          'You showed up for what matters. Let yourself take a real breath.',
        SessionType.shortBreak =>
          'A small pause counts. Return when you feel ready.',
        SessionType.longBreak =>
          'You made room to restore. Carry the calm forward.',
      };

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('focusSeconds', _focusSeconds),
      prefs.setInt('shortBreakSeconds', _shortBreakSeconds),
      prefs.setInt('longBreakSeconds', _longBreakSeconds),
      prefs.setInt('secondsRemaining', _secondsRemaining),
      prefs.setInt('totalSessionSeconds', _totalSessionSeconds),
      prefs.setInt('completedFocusSessions', _completedFocusSessions),
      prefs.setString('focusTask', _focusTask),
      prefs.setInt('dailyGoalMinutes', _dailyGoalMinutes),
      prefs.setInt('sessionType', _sessionType.index),
      _endsAt == null
          ? prefs.remove(_timerEndsAtKey)
          : prefs.setInt(_timerEndsAtKey, _endsAt!.millisecondsSinceEpoch),
      prefs.setBool(_pendingResumeKey, _hasPendingResume),
      prefs.setString(
        'focusHistory',
        jsonEncode(_focusHistory.map((session) => session.toJson()).toList()),
      ),
      prefs.setStringList('distractions', _distractions),
    ]);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _focusSeconds = prefs.getInt('focusSeconds') ?? _focusSeconds;
    _shortBreakSeconds =
        prefs.getInt('shortBreakSeconds') ?? _shortBreakSeconds;
    _longBreakSeconds = prefs.getInt('longBreakSeconds') ?? _longBreakSeconds;
    _completedFocusSessions = prefs.getInt('completedFocusSessions') ?? 0;
    _focusTask = prefs.getString('focusTask') ?? '';
    _dailyGoalMinutes = prefs.getInt('dailyGoalMinutes') ?? _dailyGoalMinutes;
    _hasPendingResume = prefs.getBool(_pendingResumeKey) ?? false;
    _distractions = prefs.getStringList('distractions') ?? [];
    final historyJson = prefs.getString('focusHistory');
    if (historyJson != null) {
      try {
        final decoded = jsonDecode(historyJson);
        if (decoded is List) {
          _focusHistory = decoded
              .whereType<Map>()
              .map((item) =>
                  FocusSession.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } on FormatException {
        _focusHistory = [];
      } on TypeError {
        _focusHistory = [];
      }
    }
    _sessionType = SessionType.values[prefs.getInt('sessionType') ?? 0];
    _totalSessionSeconds =
        prefs.getInt('totalSessionSeconds') ?? _durationFor(_sessionType);
    _secondsRemaining =
        prefs.getInt('secondsRemaining') ?? _totalSessionSeconds;
    final savedEndsAt = prefs.getInt(_timerEndsAtKey);
    if (savedEndsAt != null) {
      _endsAt = DateTime.fromMillisecondsSinceEpoch(savedEndsAt);
      final remaining =
          (_endsAt!.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (remaining <= 0) {
        _secondsRemaining = 0;
        _finishSession();
      } else {
        _secondsRemaining = remaining;
        _endsAt = null;
        _hasPendingResume = true;
        _saveToPrefs();
      }
    }
    _hasLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static String _exportDateTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }

  static String _exportDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final minuteLabel = '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    if (remainingSeconds == 0) {
      return minuteLabel;
    }
    return '$minuteLabel $remainingSeconds '
        '${remainingSeconds == 1 ? 'second' : 'seconds'}';
  }
}
