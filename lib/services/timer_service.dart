import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_event.dart';
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
  static const _completeKey = 'isComplete';
  static const _parkedThoughtsKey = 'parkedThoughts';
  static const _focusEventsKey = 'focusEvents';
  static const _activeFocusAttemptKey = 'activeFocusAttempt';
  static const _storageKeys = <String>{
    'focusSeconds',
    'shortBreakSeconds',
    'longBreakSeconds',
    'secondsRemaining',
    'totalSessionSeconds',
    'completedFocusSessions',
    'focusTask',
    'dailyGoalMinutes',
    'sessionType',
    _timerEndsAtKey,
    _pendingResumeKey,
    _completeKey,
    'focusHistory',
    _focusEventsKey,
    _activeFocusAttemptKey,
    'distractions',
    _parkedThoughtsKey,
  };
  static const _defaultFocusSeconds = 25 * 60;
  static const _defaultShortBreakSeconds = 5 * 60;
  static const _defaultLongBreakSeconds = 15 * 60;
  static const _defaultDailyGoalMinutes = 60;
  static const _dailyChallengeTarget = 3;
  static const _maxSessionSeconds = 24 * 60 * 60;
  static const _maxFocusEvents = 500;
  static const _maxPauseCount = 10000;

  Timer? _ticker;
  int _focusSeconds = _defaultFocusSeconds;
  int _shortBreakSeconds = _defaultShortBreakSeconds;
  int _longBreakSeconds = _defaultLongBreakSeconds;
  int _secondsRemaining = _defaultFocusSeconds;
  int _totalSessionSeconds = _defaultFocusSeconds;
  int _completedFocusSessions = 0;
  int _focusHistoryRevision = 0;
  int _focusEventsRevision = 0;
  int _parkedThoughtsRevision = 0;
  List<FocusSession> _focusHistory = [];
  List<FocusEvent> _focusEvents = [];
  List<ParkedThought> _parkedThoughts = [];
  String _focusTask = '';
  int _dailyGoalMinutes = _defaultDailyGoalMinutes;
  bool _isRunning = false;
  bool _isComplete = false;
  bool _hasPendingResume = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;
  DateTime? _endsAt;
  DateTime? _activeFocusStartedAt;
  int? _activeFocusPlannedSeconds;
  int _activeFocusPauseCount = 0;
  bool _activeFocusDidResume = false;
  SessionType _sessionType = SessionType.focus;
  final NotificationService? _notificationService;
  late final Future<void> _initialization;

  int get secondsRemaining => _secondsRemaining;
  int get totalSessionSeconds => _totalSessionSeconds;
  DateTime? get endsAt => _endsAt?.toUtc();
  int get completedFocusSessions => _completedFocusSessions;
  int get focusHistoryRevision => _focusHistoryRevision;
  int get focusEventsRevision => _focusEventsRevision;
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
    _focusEventsKey: _focusEvents.map((event) => event.toJson()).toList(),
  };
  List<FocusSession> get recentFocusSessions =>
      List.unmodifiable(_focusHistory.reversed);
  List<FocusEvent> get recentFocusEvents =>
      List.unmodifiable(_focusEvents.reversed);
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
  bool get canOfferSmartReset =>
      _sessionType == SessionType.focus &&
      !_isComplete &&
      !_hasPendingResume &&
      _activeFocusStartedAt != null &&
      (_activeFocusPlannedSeconds ?? 0) > 1;
  int get activeFocusPlannedSeconds =>
      _activeFocusPlannedSeconds ?? _totalSessionSeconds;
  int get activeFocusFocusedSeconds =>
      (activeFocusPlannedSeconds - _secondsRemaining)
          .clamp(0, activeFocusPlannedSeconds)
          .toInt();
  bool get canStartHavenPlan =>
      _sessionType == SessionType.focus &&
      !_isRunning &&
      !_isComplete &&
      !_hasPendingResume &&
      _activeFocusStartedAt == null;
  FocusSessionFit? get completedFocusSessionFit {
    if (_sessionType != SessionType.focus ||
        !_isComplete ||
        _focusEvents.isEmpty) {
      return null;
    }
    final latest = _focusEvents.last;
    return latest.wasCompleted ? latest.sessionFit : null;
  }

  FocusCompletionIdentity? get completedFocusIdentity {
    if (_sessionType != SessionType.focus ||
        !_isComplete ||
        _focusEvents.isEmpty) {
      return null;
    }
    return _focusEvents.last.completionIdentity;
  }

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
    _beginOrResumeFocusAttempt();
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
    if (!_isRunning) return;
    if (_sessionType == SessionType.focus &&
        _activeFocusStartedAt != null &&
        _activeFocusPauseCount < _maxPauseCount) {
      _activeFocusPauseCount++;
    }
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _hasPendingResume = false;
    _endsAt = null;
    notifyListeners();
    _saveToPrefs();
  }

  /// Adds time to an active or paused session without changing its saved
  /// default duration. Invalid requests fail closed instead of being clamped.
  bool addTime(Duration duration) {
    final additionalSeconds = duration.inSeconds;
    if (additionalSeconds <= 0 ||
        _isComplete ||
        _hasPendingResume ||
        (!_isRunning &&
            _activeFocusStartedAt == null &&
            _secondsRemaining >= _totalSessionSeconds) ||
        _totalSessionSeconds + additionalSeconds > _maxSessionSeconds) {
      return false;
    }

    _secondsRemaining += additionalSeconds;
    _totalSessionSeconds += additionalSeconds;
    if (_activeFocusPlannedSeconds != null) {
      _activeFocusPlannedSeconds =
          _activeFocusPlannedSeconds! + additionalSeconds;
    }
    final endsAt = _endsAt;
    if (_isRunning && endsAt != null) {
      _endsAt = endsAt.add(Duration(seconds: additionalSeconds));
    }
    notifyListeners();
    _saveToPrefs();
    return true;
  }

  void reset() => _reset(FocusEventOutcome.reset);

  void startSmartReset(int restartDurationSeconds) {
    if (!canOfferSmartReset) return;
    final boundedDuration = restartDurationSeconds
        .clamp(1, activeFocusPlannedSeconds - 1)
        .toInt();
    _recordFocusEvent(FocusEventOutcome.reset);
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _isComplete = false;
    _hasPendingResume = false;
    _endsAt = null;
    _secondsRemaining = boundedDuration;
    _totalSessionSeconds = boundedDuration;
    start();
  }

  void _reset(FocusEventOutcome outcome) {
    final sessionSeconds = _durationFor(_sessionType);
    if (_ticker == null &&
        !_isRunning &&
        !_isComplete &&
        !_hasPendingResume &&
        _endsAt == null &&
        _activeFocusStartedAt == null &&
        _secondsRemaining == sessionSeconds &&
        _totalSessionSeconds == sessionSeconds) {
      return;
    }
    _recordFocusEvent(outcome);
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _isComplete = false;
    _hasPendingResume = false;
    _endsAt = null;
    _secondsRemaining = sessionSeconds;
    _totalSessionSeconds = _secondsRemaining;
    notifyListeners();
    _saveToPrefs();
  }

  void selectSession(SessionType type) {
    if (_sessionType == type) return;
    _recordFocusEvent(FocusEventOutcome.changedSession);
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
    if (!_isComplete) return;
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

  /// Adds or updates a private, text-free reflection on this completion.
  ///
  /// Reflections are accepted only while the matching completed focus session
  /// is still on screen, so stale callbacks cannot rewrite older history.
  bool reflectOnCompletedFocus(
    FocusCompletionIdentity completion,
    FocusSessionFit sessionFit,
  ) {
    if (_sessionType != SessionType.focus ||
        !_isComplete ||
        _focusEvents.isEmpty) {
      return false;
    }
    final index = _focusEvents.length - 1;
    final event = _focusEvents[index];
    if (event.completionIdentity != completion) return false;
    if (event.sessionFit == sessionFit) return true;
    _focusEvents[index] = event.withSessionFit(sessionFit);
    _focusEventsRevision++;
    notifyListeners();
    _saveToPrefs();
    return true;
  }

  void resumePendingSession() {
    if (!_hasPendingResume) return;
    _hasPendingResume = false;
    start();
  }

  void discardPendingSession() {
    if (!_hasPendingResume) return;
    _reset(FocusEventOutcome.discardedResume);
  }

  void setCustomDuration(int minutes, int seconds) {
    final totalSeconds = (minutes * 60 + seconds)
        .clamp(1, _maxSessionSeconds)
        .toInt();
    final currentSessionSeconds = switch (_sessionType) {
      SessionType.focus => _focusSeconds,
      SessionType.shortBreak => _shortBreakSeconds,
      SessionType.longBreak => _longBreakSeconds,
    };
    if (currentSessionSeconds == totalSeconds) return;
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
    final cleaned = _cleanFocusTask(task);
    if (_focusTask == cleaned) return;
    _focusTask = cleaned;
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
    if (_parkedThoughts[storageIndex].text == cleaned) return;
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
    final clampedMinutes = minutes.clamp(5, 480).toInt();
    if (_dailyGoalMinutes == clampedMinutes) return;
    _dailyGoalMinutes = clampedMinutes;
    notifyListeners();
    _saveToPrefs();
  }

  void clearFocusHistory() {
    final hadHistory =
        _focusHistory.isNotEmpty ||
        _focusEvents.isNotEmpty ||
        _completedFocusSessions != 0;
    if (!hadHistory) return;
    _focusHistory = [];
    _focusEvents = [];
    _completedFocusSessions = 0;
    _focusHistoryRevision++;
    _focusEventsRevision++;
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;

    final hadHistory =
        _focusHistory.isNotEmpty ||
        _focusEvents.isNotEmpty ||
        _completedFocusSessions != 0;
    _ticker?.cancel();
    _ticker = null;
    _focusSeconds = _defaultFocusSeconds;
    _shortBreakSeconds = _defaultShortBreakSeconds;
    _longBreakSeconds = _defaultLongBreakSeconds;
    _secondsRemaining = _defaultFocusSeconds;
    _totalSessionSeconds = _defaultFocusSeconds;
    _completedFocusSessions = 0;
    _focusHistory = [];
    _focusEvents = [];
    if (hadHistory) {
      _focusHistoryRevision++;
      _focusEventsRevision++;
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
    _clearActiveFocusAttempt();
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
      prefs.remove(_completeKey),
      prefs.remove('focusHistory'),
      prefs.remove(_focusEventsKey),
      prefs.remove(_activeFocusAttemptKey),
      prefs.remove('distractions'),
      prefs.remove(_parkedThoughtsKey),
    ]);
    if (_isDisposed) return;
    notifyListeners();
  }

  bool restoreCloudBackup(Map<String, dynamic> backup) {
    try {
      final focusSeconds = backup['focusSeconds'];
      final shortBreakSeconds = backup['shortBreakSeconds'];
      final longBreakSeconds = backup['longBreakSeconds'];
      final completedFocusSessions = backup['completedFocusSessions'];
      final history = backup['focusHistory'];
      final events = backup[_focusEventsKey];
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
      final restoredEvents = _parseCloudFocusEvents(events);
      if (restoredEvents == null) return false;

      _ticker?.cancel();
      _ticker = null;
      _isRunning = false;
      _isComplete = false;
      _hasPendingResume = false;
      _endsAt = null;
      _clearActiveFocusAttempt();
      _focusSeconds = focusSeconds;
      _shortBreakSeconds = shortBreakSeconds;
      _longBreakSeconds = longBreakSeconds;
      _completedFocusSessions = completedFocusSessions;
      _focusHistory = restoredHistory;
      _focusHistoryRevision++;
      _focusEvents = restoredEvents;
      _focusEventsRevision++;
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

  List<FocusEvent>? _parseCloudFocusEvents(Object? value) {
    if (value == null) return [];
    if (value is! List || value.length > _maxFocusEvents) return null;

    final events = <FocusEvent>[];
    for (final record in value) {
      if (record is! Map) return null;
      try {
        final event = FocusEvent.fromJson(Map<String, dynamic>.from(record));
        if (event.plannedDurationSeconds > _maxSessionSeconds ||
            event.pauseCount > _maxPauseCount) {
          return null;
        }
        events.add(event);
      } on FormatException {
        return null;
      } on TypeError {
        return null;
      }
    }
    return events;
  }

  void _beginOrResumeFocusAttempt() {
    if (_sessionType != SessionType.focus) return;
    if (_activeFocusStartedAt == null) {
      _activeFocusStartedAt = DateTime.now().toUtc();
      _activeFocusPlannedSeconds = _totalSessionSeconds;
      _activeFocusPauseCount = 0;
      _activeFocusDidResume = false;
      return;
    }
    _activeFocusDidResume = true;
  }

  void _recordFocusEvent(FocusEventOutcome outcome, {DateTime? endedAt}) {
    if (_sessionType != SessionType.focus) return;
    final completedAt = (endedAt ?? DateTime.now()).toUtc();
    var startedAt = _activeFocusStartedAt;
    var plannedSeconds = _activeFocusPlannedSeconds;
    if (startedAt == null || plannedSeconds == null) {
      if (outcome != FocusEventOutcome.completed) return;
      plannedSeconds = _totalSessionSeconds;
      startedAt = completedAt.subtract(Duration(seconds: plannedSeconds));
    }

    final focusedSeconds = outcome == FocusEventOutcome.completed
        ? plannedSeconds
        : (plannedSeconds - _secondsRemaining).clamp(0, plannedSeconds).toInt();
    if (_focusEvents.length >= _maxFocusEvents) {
      _focusEvents.removeAt(0);
    }
    _focusEvents.add(
      FocusEvent(
        startedAt: startedAt,
        endedAt: completedAt.isBefore(startedAt) ? startedAt : completedAt,
        plannedDurationSeconds: plannedSeconds,
        focusedDurationSeconds: focusedSeconds,
        pauseCount: _activeFocusPauseCount,
        didResume: _activeFocusDidResume,
        outcome: outcome,
      ),
    );
    _focusEventsRevision++;
    _clearActiveFocusAttempt();
  }

  void _clearActiveFocusAttempt() {
    _activeFocusStartedAt = null;
    _activeFocusPlannedSeconds = null;
    _activeFocusPauseCount = 0;
    _activeFocusDidResume = false;
  }

  void _finishSession() {
    final completedAt = DateTime.now();
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
      _recordFocusEvent(FocusEventOutcome.completed, endedAt: completedAt);
      _completedFocusSessions++;
      _focusHistory.add(
        FocusSession(
          completedAt: completedAt,
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
      prefs.setBool(_completeKey, _isComplete),
      prefs.setString(
        'focusHistory',
        jsonEncode(_focusHistory.map((session) => session.toJson()).toList()),
      ),
      prefs.setString(
        _focusEventsKey,
        jsonEncode(_focusEvents.map((event) => event.toJson()).toList()),
      ),
      _activeFocusAttemptJson == null
          ? prefs.remove(_activeFocusAttemptKey)
          : prefs.setString(_activeFocusAttemptKey, _activeFocusAttemptJson!),
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
    final hasSavedState = prefs.getKeys().any(_storageKeys.contains);

    _focusSeconds = _clampStoredInt(
      _storedInt(prefs, 'focusSeconds'),
      _focusSeconds,
      1,
      _maxSessionSeconds,
    );
    _shortBreakSeconds = _clampStoredInt(
      _storedInt(prefs, 'shortBreakSeconds'),
      _shortBreakSeconds,
      1,
      _maxSessionSeconds,
    );
    _longBreakSeconds = _clampStoredInt(
      _storedInt(prefs, 'longBreakSeconds'),
      _longBreakSeconds,
      1,
      _maxSessionSeconds,
    );
    _completedFocusSessions = _clampStoredInt(
      _storedInt(prefs, 'completedFocusSessions'),
      0,
      0,
      1 << 31,
    );
    _focusTask = _cleanFocusTask(_storedString(prefs, 'focusTask') ?? '');
    _dailyGoalMinutes = _clampStoredInt(
      _storedInt(prefs, 'dailyGoalMinutes'),
      _dailyGoalMinutes,
      5,
      480,
    );
    _hasPendingResume = _storedBool(prefs, _pendingResumeKey) ?? false;
    final parkedThoughtsJson = _storedString(prefs, _parkedThoughtsKey);
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
          _storedStringList(prefs, 'distractions') ?? const <String>[];
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
      }
    }
    if (_parkedThoughts.isNotEmpty) {
      _parkedThoughtsRevision++;
    }
    final historyJson = _storedString(prefs, 'focusHistory');
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
    final eventsJson = _storedString(prefs, _focusEventsKey);
    if (eventsJson != null) {
      _focusEvents = _decodeFocusEvents(eventsJson);
      final normalizedEvents = jsonEncode(
        _focusEvents.map((event) => event.toJson()).toList(),
      );
      if (normalizedEvents != eventsJson) {
        await prefs.setString(_focusEventsKey, normalizedEvents);
      }
    }
    if (_focusEvents.isNotEmpty) {
      _focusEventsRevision++;
    }
    _loadActiveFocusAttempt(_storedString(prefs, _activeFocusAttemptKey));
    _sessionType = _sessionTypeFromIndex(_storedInt(prefs, 'sessionType'));
    if (_sessionType != SessionType.focus) {
      _clearActiveFocusAttempt();
    }
    _totalSessionSeconds = _clampStoredInt(
      _storedInt(prefs, 'totalSessionSeconds'),
      _durationFor(_sessionType),
      1,
      _maxSessionSeconds,
    );
    _secondsRemaining = _clampStoredInt(
      _storedInt(prefs, 'secondsRemaining'),
      _totalSessionSeconds,
      0,
      _totalSessionSeconds,
    );
    final savedEndsAt = _storedInt(prefs, _timerEndsAtKey);
    // A zero-second timer with no recoverable deadline is complete by
    // definition. Inferring this invariant migrates builds that predate the
    // explicit completion key and prevents a cold start from restoring an
    // unstartable ready timer at 00:00.
    if (_secondsRemaining == 0 && savedEndsAt == null) {
      _isComplete = true;
      _hasPendingResume = false;
      _clearActiveFocusAttempt();
    } else {
      _isComplete = false;
    }
    if (savedEndsAt != null) {
      _isComplete = false;
      _endsAt = DateTime.fromMillisecondsSinceEpoch(savedEndsAt);
      final remaining =
          (_endsAt!.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (remaining <= 0) {
        _secondsRemaining = 0;
        _finishSession();
      } else {
        // A wall-clock rollback or damaged future deadline must never restore
        // more time than the already-validated session total. Keeping this
        // state bounded also guarantees that trusted system surfaces can
        // publish their first cold-start snapshot instead of remaining stale.
        _secondsRemaining = remaining.clamp(1, _totalSessionSeconds).toInt();
        _endsAt = null;
        _hasPendingResume = true;
        _saveToPrefs();
      }
    }
    if (hasSavedState && _timerStorageNeedsRepair(prefs)) {
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

  static List<FocusEvent> _decodeFocusEvents(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return [];

      final events = <FocusEvent>[];
      for (final value in decoded.whereType<Map>()) {
        try {
          final event = FocusEvent.fromJson(Map<String, dynamic>.from(value));
          if (event.plannedDurationSeconds <= _maxSessionSeconds &&
              event.pauseCount <= _maxPauseCount) {
            events.add(event);
          }
        } on FormatException {
          // Ignore one damaged record without discarding valid local signals.
        } on TypeError {
          // Ignore values with an unexpected persisted shape.
        }
      }
      return events.length <= _maxFocusEvents
          ? events
          : events.sublist(events.length - _maxFocusEvents);
    } on FormatException {
      return [];
    }
  }

  void _loadActiveFocusAttempt(String? source) {
    if (source == null) return;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      final startedAtValue = json['startedAt'];
      final plannedDurationSeconds = json['plannedDurationSeconds'];
      final pauseCount = json['pauseCount'];
      final didResume = json['didResume'];
      if (startedAtValue is! String ||
          plannedDurationSeconds is! int ||
          pauseCount is! int ||
          didResume is! bool) {
        return;
      }
      final startedAt = DateTime.tryParse(startedAtValue);
      if (startedAt == null ||
          plannedDurationSeconds < 1 ||
          plannedDurationSeconds > _maxSessionSeconds ||
          pauseCount < 0 ||
          pauseCount > _maxPauseCount) {
        return;
      }
      _activeFocusStartedAt = startedAt.toUtc();
      _activeFocusPlannedSeconds = plannedDurationSeconds;
      _activeFocusPauseCount = pauseCount;
      _activeFocusDidResume = didResume;
    } on FormatException {
      // A damaged active attempt is discarded without affecting history.
    } on TypeError {
      // Ignore values with an unexpected persisted shape.
    }
  }

  String? get _activeFocusAttemptJson {
    final startedAt = _activeFocusStartedAt;
    final plannedDurationSeconds = _activeFocusPlannedSeconds;
    if (startedAt == null || plannedDurationSeconds == null) return null;
    return jsonEncode({
      'startedAt': startedAt.toUtc().toIso8601String(),
      'plannedDurationSeconds': plannedDurationSeconds,
      'pauseCount': _activeFocusPauseCount,
      'didResume': _activeFocusDidResume,
    });
  }

  bool _timerStorageNeedsRepair(SharedPreferences preferences) {
    final normalizedHistory = jsonEncode(
      _focusHistory.map((session) => session.toJson()).toList(),
    );
    final normalizedParkedThoughts = jsonEncode(
      _parkedThoughts.map((thought) => thought.toJson()).toList(),
    );
    final normalizedEvents = jsonEncode(
      _focusEvents.map((event) => event.toJson()).toList(),
    );
    return preferences.get('focusSeconds') != _focusSeconds ||
        preferences.get('shortBreakSeconds') != _shortBreakSeconds ||
        preferences.get('longBreakSeconds') != _longBreakSeconds ||
        preferences.get('secondsRemaining') != _secondsRemaining ||
        preferences.get('totalSessionSeconds') != _totalSessionSeconds ||
        preferences.get('completedFocusSessions') != _completedFocusSessions ||
        preferences.get('focusTask') != _focusTask ||
        preferences.get('dailyGoalMinutes') != _dailyGoalMinutes ||
        preferences.get('sessionType') != _sessionType.index ||
        preferences.get(_timerEndsAtKey) != _endsAt?.millisecondsSinceEpoch ||
        preferences.get(_pendingResumeKey) != _hasPendingResume ||
        preferences.get(_completeKey) != _isComplete ||
        preferences.get('focusHistory') != normalizedHistory ||
        preferences.get(_focusEventsKey) != normalizedEvents ||
        preferences.get(_activeFocusAttemptKey) != _activeFocusAttemptJson ||
        preferences.get(_parkedThoughtsKey) != normalizedParkedThoughts ||
        preferences.containsKey('distractions');
  }

  static int? _storedInt(SharedPreferences preferences, String key) {
    final value = preferences.get(key);
    return value is int ? value : null;
  }

  static String? _storedString(SharedPreferences preferences, String key) {
    final value = preferences.get(key);
    return value is String ? value : null;
  }

  static bool? _storedBool(SharedPreferences preferences, String key) {
    final value = preferences.get(key);
    return value is bool ? value : null;
  }

  static List<String>? _storedStringList(
    SharedPreferences preferences,
    String key,
  ) {
    final value = preferences.get(key);
    return value is List ? value.whereType<String>().toList() : null;
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
