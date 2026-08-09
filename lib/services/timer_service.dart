import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';
import '../models/parked_thought.dart';
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
  static const _parkedThoughtsKey = 'parkedThoughts';
  static const _defaultFocusSeconds = 25 * 60;
  static const _defaultShortBreakSeconds = 5 * 60;
  static const _defaultLongBreakSeconds = 15 * 60;
  static const _defaultDailyGoalMinutes = 60;
  static const _dailyChallengeTarget = 3;
  static const _maxSessionSeconds = 24 * 60 * 60;

  Timer? _ticker;
  int _focusSeconds = _defaultFocusSeconds;
  int _shortBreakSeconds = _defaultShortBreakSeconds;
  int _longBreakSeconds = _defaultLongBreakSeconds;
  int _secondsRemaining = _defaultFocusSeconds;
  int _totalSessionSeconds = _defaultFocusSeconds;
  int _completedFocusSessions = 0;
  int _focusHistoryRevision = 0;
  int _parkedThoughtsRevision = 0;
  List<FocusSession> _focusHistory = [];
  List<ParkedThought> _parkedThoughts = [];
  String _focusTask = '';
  int _dailyGoalMinutes = _defaultDailyGoalMinutes;
  bool _isRunning = false;
  bool _isComplete = false;
  bool _hasPendingResume = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;
  DateTime? _endsAt;
  SessionType _sessionType = SessionType.focus;
  final NotificationService? _notificationService;
  late final Future<void> _initialization;

  int get secondsRemaining => _secondsRemaining;
  int get totalSessionSeconds => _totalSessionSeconds;
  int get completedFocusSessions => _completedFocusSessions;
  int get focusHistoryRevision => _focusHistoryRevision;
  int get parkedThoughtsRevision => _parkedThoughtsRevision;
  String get focusTask => _focusTask;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  Map<String, dynamic> get cloudBackup => {
    'focusSeconds': _focusSeconds,
    'shortBreakSeconds': _shortBreakSeconds,
    'longBreakSeconds': _longBreakSeconds,
    'completedFocusSessions': _completedFocusSessions,
    'focusTask': _focusTask,
    'dailyGoalMinutes': _dailyGoalMinutes,
    'focusHistory': _focusHistory.map((session) => session.toJson()).toList(),
  };
  List<FocusSession> get recentFocusSessions =>
      List.unmodifiable(_focusHistory.reversed);
  List<ParkedThought> get parkedThoughts => List.unmodifiable(
    _parkedThoughts.where((thought) => !thought.isCompleted).toList().reversed,
  );
  List<ParkedThought> get completedParkedThoughts => List.unmodifiable(
    _parkedThoughts.where((thought) => thought.isCompleted).toList().reversed,
  );

  /// Temporary compatibility view for screens that still render plain text.
  List<String> get distractions =>
      List.unmodifiable(parkedThoughts.map((thought) => thought.text));
  int get totalFocusSeconds => _focusHistory.fold(
    0,
    (total, session) => total + session.durationSeconds,
  );

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
        '- Current streak: $currentStreak ${currentStreak == 1 ? 'day' : 'days'}',
      )
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
    final now = DateTime.now().toLocal();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return _focusHistory.where((session) {
      final completedAt = session.completedAt.toLocal();
      return !completedAt.isBefore(cutoff);
    }).length;
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
    final completedDays = _focusHistory
        .map((session) => _dateKey(session.completedAt))
        .toSet();
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
  Future<void> get initialized => _initialization;
  SessionType get sessionType => _sessionType;
  String get completionMessage => _completionMessage;
  double get progress => _totalSessionSeconds == 0
      ? 0
      : 1 - (_secondsRemaining / _totalSessionSeconds);

  factory TimerService({NotificationService? notificationService}) {
    return TimerService._(notificationService);
  }

  TimerService._(this._notificationService) {
    WidgetsBinding.instance.addObserver(this);
    _initialization = _loadFromPrefs();
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
    final remaining = (endsAt.difference(DateTime.now()).inMilliseconds / 1000)
        .ceil();
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
        isLongBreak ? SessionType.longBreak : SessionType.shortBreak,
      );
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
    final totalSeconds = (minutes * 60 + seconds)
        .clamp(1, _maxSessionSeconds)
        .toInt();
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
    _focusTask = _cleanFocusTask(task);
    notifyListeners();
    _saveToPrefs();
  }

  void captureDistraction(String distraction) {
    final cleaned = _cleanParkedThoughtText(distraction);
    if (cleaned.isEmpty) return;
    final now = DateTime.now();
    _parkedThoughts.add(
      ParkedThought(
        id: '${now.microsecondsSinceEpoch}-${_parkedThoughts.length}',
        text: cleaned,
        createdAt: now,
      ),
    );
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void updateDistraction(int index, String distraction) {
    final activeThoughts = parkedThoughts;
    if (index < 0 || index >= activeThoughts.length) return;
    renameParkedThought(activeThoughts[index].id, distraction);
  }

  void renameParkedThought(String id, String distraction) {
    final cleaned = _cleanParkedThoughtText(distraction);
    if (cleaned.isEmpty) return;
    final storageIndex = _indexOfParkedThought(id);
    if (storageIndex == -1) return;
    _parkedThoughts[storageIndex] = _parkedThoughts[storageIndex].rename(
      cleaned,
    );
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void removeDistractionAt(int index) {
    final activeThoughts = parkedThoughts;
    if (index < 0 || index >= activeThoughts.length) return;
    removeParkedThought(activeThoughts[index].id);
  }

  void completeParkedThought(String id) {
    final storageIndex = _indexOfParkedThought(id);
    if (storageIndex == -1 || _parkedThoughts[storageIndex].isCompleted) return;
    _parkedThoughts[storageIndex] = _parkedThoughts[storageIndex].complete(
      DateTime.now(),
    );
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void reopenParkedThought(String id) {
    final storageIndex = _indexOfParkedThought(id);
    if (storageIndex == -1 || !_parkedThoughts[storageIndex].isCompleted) {
      return;
    }
    _parkedThoughts[storageIndex] = _parkedThoughts[storageIndex].reopen();
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void removeParkedThought(String id) {
    final storageIndex = _indexOfParkedThought(id);
    if (storageIndex == -1) return;
    _parkedThoughts.removeAt(storageIndex);
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void clearDistractions() {
    final previousLength = _parkedThoughts.length;
    _parkedThoughts.removeWhere((thought) => !thought.isCompleted);
    if (_parkedThoughts.length == previousLength) return;
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  void clearCompletedParkedThoughts() {
    final previousLength = _parkedThoughts.length;
    _parkedThoughts.removeWhere((thought) => thought.isCompleted);
    if (_parkedThoughts.length == previousLength) return;
    _parkedThoughtsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  int _indexOfParkedThought(String id) =>
      _parkedThoughts.indexWhere((thought) => thought.id == id);

  void setDailyGoalMinutes(int minutes) {
    _dailyGoalMinutes = minutes.clamp(5, 480).toInt();
    notifyListeners();
    _saveToPrefs();
  }

  void clearFocusHistory() {
    final hadHistory = _focusHistory.isNotEmpty || _completedFocusSessions != 0;
    _focusHistory = [];
    _completedFocusSessions = 0;
    if (hadHistory) {
      _focusHistoryRevision++;
    }
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> clearLocalData() async {
    final hadHistory = _focusHistory.isNotEmpty || _completedFocusSessions != 0;
    _ticker?.cancel();
    _ticker = null;
    _focusSeconds = _defaultFocusSeconds;
    _shortBreakSeconds = _defaultShortBreakSeconds;
    _longBreakSeconds = _defaultLongBreakSeconds;
    _secondsRemaining = _defaultFocusSeconds;
    _totalSessionSeconds = _defaultFocusSeconds;
    _completedFocusSessions = 0;
    _focusHistory = [];
    if (hadHistory) {
      _focusHistoryRevision++;
    }
    if (_parkedThoughts.isNotEmpty) {
      _parkedThoughts = [];
      _parkedThoughtsRevision++;
    }
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
      prefs.remove(_parkedThoughtsKey),
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
          focusSeconds < 1 ||
          focusSeconds > _maxSessionSeconds ||
          shortBreakSeconds is! int ||
          shortBreakSeconds < 1 ||
          shortBreakSeconds > _maxSessionSeconds ||
          longBreakSeconds is! int ||
          longBreakSeconds < 1 ||
          longBreakSeconds > _maxSessionSeconds ||
          completedFocusSessions is! int ||
          completedFocusSessions < 0 ||
          completedFocusSessions > (1 << 31) ||
          (focusTask != null && focusTask is! String) ||
          (dailyGoalMinutes != null &&
              (dailyGoalMinutes is! int ||
                  dailyGoalMinutes < 5 ||
                  dailyGoalMinutes > 480))) {
        return false;
      }

      final restoredHistory = _parseCloudFocusHistory(history);
      if (restoredHistory == null) return false;

      _ticker?.cancel();
      _ticker = null;
      _isRunning = false;
      _isComplete = false;
      _hasPendingResume = false;
      _endsAt = null;
      _focusSeconds = focusSeconds;
      _shortBreakSeconds = shortBreakSeconds;
      _longBreakSeconds = longBreakSeconds;
      _completedFocusSessions = completedFocusSessions;
      _focusHistory = restoredHistory;
      _focusHistoryRevision++;
      _focusTask = _cleanFocusTask(focusTask ?? '');
      if (dailyGoalMinutes != null) {
        _dailyGoalMinutes = dailyGoalMinutes;
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

  List<FocusSession>? _parseCloudFocusHistory(Object? value) {
    if (value is! List) return null;

    final sessions = <FocusSession>[];
    for (final record in value) {
      if (record is! Map) return null;

      final json = Map<String, dynamic>.from(record);
      final completedAtValue = json['completedAt'];
      final durationSeconds = json['durationSeconds'];
      final focusTask = json['focusTask'];
      if (completedAtValue is! String ||
          durationSeconds is! int ||
          durationSeconds < 1 ||
          durationSeconds > _maxSessionSeconds ||
          (focusTask != null && focusTask is! String)) {
        return null;
      }

      final completedAt = DateTime.tryParse(completedAtValue);
      if (completedAt == null) return null;
      final cleanedTask = focusTask == null ? '' : _cleanFocusTask(focusTask);
      sessions.add(
        FocusSession(
          completedAt: completedAt,
          durationSeconds: durationSeconds,
          focusTask: cleanedTask.isEmpty ? null : cleanedTask,
        ),
      );
    }
    return sessions;
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
      _focusHistoryRevision++;
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
      prefs.setString(
        _parkedThoughtsKey,
        jsonEncode(_parkedThoughts.map((thought) => thought.toJson()).toList()),
      ),
      prefs.remove('distractions'),
    ]);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;

    var migratedLegacyThoughts = false;
    _focusSeconds = _clampStoredInt(
      prefs.getInt('focusSeconds'),
      _focusSeconds,
      1,
      _maxSessionSeconds,
    );
    _shortBreakSeconds = _clampStoredInt(
      prefs.getInt('shortBreakSeconds'),
      _shortBreakSeconds,
      1,
      _maxSessionSeconds,
    );
    _longBreakSeconds = _clampStoredInt(
      prefs.getInt('longBreakSeconds'),
      _longBreakSeconds,
      1,
      _maxSessionSeconds,
    );
    _completedFocusSessions = _clampStoredInt(
      prefs.getInt('completedFocusSessions'),
      0,
      0,
      1 << 31,
    );
    _focusTask = _cleanFocusTask(prefs.getString('focusTask') ?? '');
    _dailyGoalMinutes = _clampStoredInt(
      prefs.getInt('dailyGoalMinutes'),
      _dailyGoalMinutes,
      5,
      480,
    );
    _hasPendingResume = prefs.getBool(_pendingResumeKey) ?? false;
    final parkedThoughtsJson = prefs.getString(_parkedThoughtsKey);
    if (parkedThoughtsJson != null) {
      _parkedThoughts = _decodeParkedThoughts(parkedThoughtsJson);
      final normalizedParkedThoughts = jsonEncode(
        _parkedThoughts.map((thought) => thought.toJson()).toList(),
      );
      if (normalizedParkedThoughts != parkedThoughtsJson) {
        await prefs.setString(_parkedThoughtsKey, normalizedParkedThoughts);
      }
      await prefs.remove('distractions');
    } else {
      final legacyThoughts =
          prefs.getStringList('distractions') ?? const <String>[];
      if (legacyThoughts.isNotEmpty) {
        final migrationTime = DateTime.now();
        _parkedThoughts = [
          for (var index = 0; index < legacyThoughts.length; index++)
            if (legacyThoughts[index].trim().isNotEmpty)
              ParkedThought(
                id: 'legacy-${migrationTime.microsecondsSinceEpoch}-$index',
                text: _cleanParkedThoughtText(legacyThoughts[index]),
                createdAt: migrationTime.add(Duration(microseconds: index)),
              ),
        ];
        migratedLegacyThoughts = true;
      }
    }
    if (_parkedThoughts.isNotEmpty) {
      _parkedThoughtsRevision++;
    }
    final historyJson = prefs.getString('focusHistory');
    if (historyJson != null) {
      _focusHistory = _decodeFocusHistory(historyJson);
      final normalizedHistory = jsonEncode(
        _focusHistory.map((session) => session.toJson()).toList(),
      );
      if (normalizedHistory != historyJson) {
        await prefs.setString('focusHistory', normalizedHistory);
      }
    }
    if (_focusHistory.isNotEmpty) {
      _focusHistoryRevision++;
    }
    _sessionType = _sessionTypeFromIndex(prefs.getInt('sessionType'));
    _totalSessionSeconds = _clampStoredInt(
      prefs.getInt('totalSessionSeconds'),
      _durationFor(_sessionType),
      1,
      _maxSessionSeconds,
    );
    _secondsRemaining = _clampStoredInt(
      prefs.getInt('secondsRemaining'),
      _totalSessionSeconds,
      0,
      _totalSessionSeconds,
    );
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
    if (migratedLegacyThoughts) {
      await _saveToPrefs();
    }
    if (_isDisposed) return;

    _hasLoaded = true;
    notifyListeners();
  }

  static List<ParkedThought> _decodeParkedThoughts(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return [];

      final thoughts = <ParkedThought>[];
      final loadedIds = <String>{};
      for (final value in decoded.whereType<Map>()) {
        try {
          final thought = ParkedThought.fromJson(
            Map<String, dynamic>.from(value),
          );
          final id = thought.id.trim();
          if (!loadedIds.add(id)) continue;
          final text = _cleanParkedThoughtText(thought.text);
          thoughts.add(
            ParkedThought(
              id: id,
              text: text,
              createdAt: thought.createdAt,
              completedAt: thought.completedAt,
            ),
          );
        } on FormatException {
          // Ignore one damaged record without discarding valid local history.
        } on TypeError {
          // Ignore values with an unexpected persisted shape.
        }
      }
      return thoughts;
    } on FormatException {
      return [];
    }
  }

  static List<FocusSession> _decodeFocusHistory(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return [];

      final sessions = <FocusSession>[];
      for (final value in decoded.whereType<Map>()) {
        try {
          final session = FocusSession.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (session.durationSeconds > 0 &&
              session.durationSeconds <= _maxSessionSeconds) {
            final cleanedTask = session.focusTask == null
                ? ''
                : _cleanFocusTask(session.focusTask!);
            sessions.add(
              FocusSession(
                completedAt: session.completedAt,
                durationSeconds: session.durationSeconds,
                focusTask: cleanedTask.isEmpty ? null : cleanedTask,
              ),
            );
          }
        } on FormatException {
          // Ignore one damaged record without discarding valid focus history.
        } on TypeError {
          // Ignore values with an unexpected persisted shape.
        }
      }
      return sessions;
    } on FormatException {
      return [];
    }
  }

  static int _clampStoredInt(
    int? value,
    int fallback,
    int minimum,
    int maximum,
  ) => (value ?? fallback).clamp(minimum, maximum).toInt();

  static SessionType _sessionTypeFromIndex(int? index) {
    if (index == null || index < 0 || index >= SessionType.values.length) {
      return SessionType.focus;
    }
    return SessionType.values[index];
  }

  static String _cleanFocusTask(String task) {
    final cleaned = task.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  static String _cleanParkedThoughtText(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.length > 140 ? cleaned.substring(0, 140) : cleaned;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    final localFirst = first.toLocal();
    final localSecond = second.toLocal();
    return localFirst.year == localSecond.year &&
        localFirst.month == localSecond.month &&
        localFirst.day == localSecond.day;
  }

  static String _dateKey(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month}-${localDate.day}';
  }

  static String _exportDateTime(DateTime date) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day $hour:$minute';
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
