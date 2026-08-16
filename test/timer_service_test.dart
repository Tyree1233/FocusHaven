import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimerService> createTimer() async {
    final timer = TimerService();
    await timer.initialized;
    return timer;
  }

  test('initialization completes safely after immediate disposal', () async {
    final timer = TimerService();

    timer.dispose();

    await expectLater(timer.initialized, completes);
  });

  test('clear local data is safe after disposal', () async {
    SharedPreferences.setMockInitialValues({'focusTask': 'Keep saved task'});

    final timer = TimerService();
    timer.dispose();

    await timer.initialized;
    await expectLater(timer.clearLocalData(), completes);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusTask'), 'Keep saved task');
  });

  test('starts with a 25-minute focus session', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.sessionType, SessionType.focus);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.isRunning, isFalse);
  });

  test('duplicate pause callbacks publish one state change', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.start();
    notifications = 0;
    final pause = timer.pause;

    pause();
    pause();

    expect(timer.isRunning, isFalse);
    expect(notifications, 1);
  });

  test('duplicate reset callbacks publish one state change', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.start();
    notifications = 0;
    final reset = timer.reset;

    reset();
    reset();

    expect(timer.isRunning, isFalse);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(notifications, 1);
  });

  test('active session reselection is a no-op', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.start();
    notifications = 0;
    final remainingBeforeReselection = timer.secondsRemaining;

    timer.selectSession(SessionType.focus);

    expect(timer.sessionType, SessionType.focus);
    expect(timer.isRunning, isTrue);
    expect(timer.secondsRemaining, remainingBeforeReselection);
    expect(notifications, 0);
  });

  test('equivalent custom duration preserves a running timer', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.start();
    notifications = 0;
    final remainingBeforeSubmission = timer.secondsRemaining;

    timer.setCustomDuration(24, 60);

    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.isRunning, isTrue);
    expect(timer.secondsRemaining, remainingBeforeSubmission);
    expect(notifications, 0);
  });

  test('equivalent timer preferences publish one state change each', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.setFocusTask('  Write   project   outline  ');
    timer.setFocusTask('Write project outline');

    expect(timer.focusTask, 'Write project outline');
    expect(notifications, 1);

    timer.setDailyGoalMinutes(1);
    timer.setDailyGoalMinutes(-20);

    expect(timer.dailyGoalMinutes, 5);
    expect(notifications, 2);
  });

  test('custom duration accepts minutes and seconds', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.setCustomDuration(2, 5);

    expect(timer.secondsRemaining, 125);
    expect(timer.totalSessionSeconds, 125);
  });

  test('custom duration remains within the allowed range', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.setCustomDuration(0, 0);
    expect(timer.secondsRemaining, 1);

    timer.setCustomDuration(24 * 60, 1);
    expect(timer.secondsRemaining, 24 * 60 * 60);
  });

  test('completed sessions use the correct saved next duration', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1,
      'shortBreakSeconds': 190,
      'secondsRemaining': 1,
      'totalSessionSeconds': 1,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .subtract(const Duration(seconds: 2))
          .millisecondsSinceEpoch,
    });
    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.isComplete, isTrue);
    timer.beginNextSession();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.secondsRemaining, 190);
    expect(timer.isComplete, isFalse);
    expect(timer.isRunning, isFalse);
  });

  test('stale next-session callbacks publish one transition', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1,
      'secondsRemaining': 1,
      'totalSessionSeconds': 1,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .subtract(const Duration(seconds: 2))
          .millisecondsSinceEpoch,
    });
    final timer = await createTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });
    final transition = timer.beginNextSession;

    transition();
    transition();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.isComplete, isFalse);
    expect(timer.isRunning, isFalse);
    expect(notifications, 1);
  });

  test('focus tasks and parked thoughts are cleaned before saving', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.setFocusTask('  Write   project   outline  ');
    timer.captureDistraction('  Reply    to   that   email  ');

    expect(timer.focusTask, 'Write project outline');
    expect(timer.distractions, ['Reply to that email']);
  });

  test('equivalent parked thought renames are no-ops', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    timer.captureDistraction('Reply to email');
    final thought = timer.parkedThoughts.single;
    final revision = timer.parkedThoughtsRevision;
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });

    timer.renameParkedThought(thought.id, '  Reply   to   email  ');

    expect(timer.parkedThoughts.single.text, 'Reply to email');
    expect(timer.parkedThoughtsRevision, revision);
    expect(notifications, 0);

    timer.renameParkedThought(thought.id, 'Schedule appointment');

    expect(timer.parkedThoughts.single.text, 'Schedule appointment');
    expect(timer.parkedThoughtsRevision, revision + 1);
    expect(notifications, 1);
  });

  test('daily goal stays within its supported range', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.setDailyGoalMinutes(1);
    expect(timer.dailyGoalMinutes, 5);

    timer.setDailyGoalMinutes(999);
    expect(timer.dailyGoalMinutes, 480);
  });

  test('restores a valid cloud backup', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    final completedAt = DateTime(2026, 8, 6, 12);

    final restored = timer.restoreCloudBackup({
      'focusSeconds': 45 * 60,
      'shortBreakSeconds': 6 * 60,
      'longBreakSeconds': 18 * 60,
      'completedFocusSessions': 4,
      'focusTask': 'Finish the proposal',
      'dailyGoalMinutes': 90,
      'focusHistory': [
        {
          'completedAt': completedAt.toIso8601String(),
          'durationSeconds': 45 * 60,
          'focusTask': 'Finish the proposal',
        },
      ],
    });

    expect(restored, isTrue);
    expect(timer.secondsRemaining, 45 * 60);
    expect(timer.completedFocusSessions, 4);
    expect(timer.focusTask, 'Finish the proposal');
    expect(timer.dailyGoalMinutes, 90);
    expect(timer.recentFocusSessions, hasLength(1));
  });

  test('rejects an incomplete cloud backup', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.restoreCloudBackup({'focusSeconds': 20}), isFalse);
  });

  test(
    'rejects partially corrupt cloud history without changing state',
    () async {
      final timer = await createTimer();
      addTearDown(timer.dispose);
      timer.setCustomDuration(35, 0);
      timer.setFocusTask('Keep this local task');
      timer.setDailyGoalMinutes(75);
      final initialHistoryRevision = timer.focusHistoryRevision;
      var notifications = 0;
      timer.addListener(() => notifications++);

      final restored = timer.restoreCloudBackup({
        'focusSeconds': 45 * 60,
        'shortBreakSeconds': 6 * 60,
        'longBreakSeconds': 18 * 60,
        'completedFocusSessions': 4,
        'focusTask': 'Do not apply this task',
        'dailyGoalMinutes': 90,
        'focusHistory': [
          {
            'completedAt': DateTime(2026, 8, 6, 12).toIso8601String(),
            'durationSeconds': 45 * 60,
          },
          null,
        ],
      });

      expect(restored, isFalse);
      expect(timer.secondsRemaining, 35 * 60);
      expect(timer.focusTask, 'Keep this local task');
      expect(timer.dailyGoalMinutes, 75);
      expect(timer.completedFocusSessions, 0);
      expect(timer.recentFocusSessions, isEmpty);
      expect(timer.focusHistoryRevision, initialHistoryRevision);
      expect(notifications, 0);
    },
  );

  test('rejects out-of-range cloud values without changing state', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    timer.setCustomDuration(30, 0);
    final validBackup = <String, dynamic>{
      'focusSeconds': 45 * 60,
      'shortBreakSeconds': 6 * 60,
      'longBreakSeconds': 18 * 60,
      'completedFocusSessions': 4,
      'focusTask': 'Finish the proposal',
      'dailyGoalMinutes': 90,
      'focusHistory': <Object?>[],
    };

    final invalidBackups = [
      {...validBackup, 'focusSeconds': 0},
      {...validBackup, 'shortBreakSeconds': 24 * 60 * 60 + 1},
      {...validBackup, 'completedFocusSessions': -1},
      {...validBackup, 'dailyGoalMinutes': 481},
      {
        ...validBackup,
        'focusHistory': [
          {'completedAt': 'not-a-date', 'durationSeconds': 45 * 60},
        ],
      },
      {
        ...validBackup,
        'focusHistory': [
          {
            'completedAt': DateTime(2026, 8, 6, 12).toIso8601String(),
            'durationSeconds': 0,
          },
        ],
      },
    ];

    for (final backup in invalidBackups) {
      expect(timer.restoreCloudBackup(backup), isFalse);
    }
    expect(timer.secondsRemaining, 30 * 60);
    expect(timer.completedFocusSessions, 0);
    expect(timer.recentFocusSessions, isEmpty);
  });

  test('loads a saved short-break timer after reopening', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1500,
      'shortBreakSeconds': 185,
      'longBreakSeconds': 900,
      'secondsRemaining': 181,
      'totalSessionSeconds': 185,
      'sessionType': SessionType.shortBreak.index,
      'completedFocusSessions': 2,
      'focusTask': 'Finish the outline',
      'dailyGoalMinutes': 75,
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.secondsRemaining, 181);
    expect(timer.totalSessionSeconds, 185);
    expect(timer.completedFocusSessions, 2);
    expect(timer.focusTask, 'Finish the outline');
    expect(timer.dailyGoalMinutes, 75);
  });

  test('clamps corrupted saved timer values to safe limits', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': -25,
      'shortBreakSeconds': 999999,
      'longBreakSeconds': 0,
      'completedFocusSessions': -4,
      'focusTask': '  ${List.filled(90, 'a').join()}  ',
      'dailyGoalMinutes': 999,
      'sessionType': 99,
      'totalSessionSeconds': -50,
      'secondsRemaining': 999999,
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.sessionType, SessionType.focus);
    expect(timer.totalSessionSeconds, 1);
    expect(timer.secondsRemaining, 1);
    expect(timer.completedFocusSessions, 0);
    expect(timer.focusTask, hasLength(80));
    expect(timer.dailyGoalMinutes, 480);

    timer.selectSession(SessionType.shortBreak);
    expect(timer.secondsRemaining, 24 * 60 * 60);

    timer.selectSession(SessionType.longBreak);
    expect(timer.secondsRemaining, 1);
  });

  test('repairs mistyped timer storage without aborting startup', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': '1500',
      'shortBreakSeconds': 420,
      'longBreakSeconds': false,
      'secondsRemaining': '300',
      'totalSessionSeconds': '420',
      'completedFocusSessions': '4',
      'focusTask': 17,
      'dailyGoalMinutes': '90',
      'sessionType': '1',
      'timerEndsAt': 'not-a-deadline',
      'hasPendingTimerResume': 'true',
      'focusHistory': false,
      'parkedThoughts': 42,
      'distractions': 'not-a-list',
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.sessionType, SessionType.focus);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.completedFocusSessions, 0);
    expect(timer.focusTask, isEmpty);
    expect(timer.dailyGoalMinutes, 60);
    expect(timer.hasPendingResume, isFalse);
    expect(timer.recentFocusSessions, isEmpty);
    expect(timer.parkedThoughts, isEmpty);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('focusSeconds'), 25 * 60);
    expect(preferences.getInt('shortBreakSeconds'), 420);
    expect(preferences.getInt('longBreakSeconds'), 15 * 60);
    expect(preferences.getInt('secondsRemaining'), 25 * 60);
    expect(preferences.getInt('totalSessionSeconds'), 25 * 60);
    expect(preferences.getInt('completedFocusSessions'), 0);
    expect(preferences.getString('focusTask'), isEmpty);
    expect(preferences.getInt('dailyGoalMinutes'), 60);
    expect(preferences.getInt('sessionType'), SessionType.focus.index);
    expect(preferences.containsKey('timerEndsAt'), isFalse);
    expect(preferences.getBool('hasPendingTimerResume'), isFalse);
    expect(preferences.getString('focusHistory'), '[]');
    expect(preferences.getString('parkedThoughts'), '[]');
    expect(preferences.containsKey('distractions'), isFalse);

    timer.selectSession(SessionType.shortBreak);
    expect(timer.secondsRemaining, 420);
  });

  test('preserves valid focus history around damaged saved records', () async {
    SharedPreferences.setMockInitialValues({
      'focusHistory': jsonEncode([
        {
          'completedAt': '2026-08-06T09:00:00.000',
          'durationSeconds': 60,
          'focusTask': '  First   valid session  ',
          'accidentalMetadata': 'remove me',
        },
        {'durationSeconds': 120, 'focusTask': 'Missing completion date'},
        {
          'completedAt': 'not-a-date',
          'durationSeconds': 180,
          'focusTask': 'Invalid completion date',
        },
        {
          'completedAt': '2026-08-06T10:00:00.000',
          'durationSeconds': 0,
          'focusTask': 'Impossible duration',
        },
        'not a focus session',
        {
          'completedAt': '2026-08-06T11:00:00.000',
          'durationSeconds': 90,
          'focusTask': 'Second valid session',
        },
      ]),
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.recentFocusSessions, hasLength(2));
    expect(timer.recentFocusSessions.map((session) => session.focusTask), [
      'Second valid session',
      'First valid session',
    ]);
    expect(timer.totalFocusSeconds, 150);

    final preferences = await SharedPreferences.getInstance();
    final repaired = jsonDecode(preferences.getString('focusHistory')!) as List;
    expect(repaired, [
      {
        'completedAt': '2026-08-06T09:00:00.000',
        'durationSeconds': 60,
        'focusTask': 'First valid session',
      },
      {
        'completedAt': '2026-08-06T11:00:00.000',
        'durationSeconds': 90,
        'focusTask': 'Second valid session',
      },
    ]);
  });

  test('weekly statistics include the full oldest calendar day', () async {
    final now = DateTime.now().toLocal();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final oldestIncluded = startOfToday
        .subtract(const Duration(days: 6))
        .add(const Duration(minutes: 1));
    final previousDay = startOfToday
        .subtract(const Duration(days: 7))
        .add(const Duration(hours: 23, minutes: 59));
    SharedPreferences.setMockInitialValues({
      'focusHistory': jsonEncode([
        {
          'completedAt': previousDay.toIso8601String(),
          'durationSeconds': 120,
          'focusTask': 'Outside the seven-day window',
        },
        {
          'completedAt': oldestIncluded.toIso8601String(),
          'durationSeconds': 60,
          'focusTask': 'Oldest included day',
        },
      ]),
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.weeklyFocusSessions, 1);
    expect(timer.weeklyFocusSeconds, 60);
  });

  test('duplicate focus history clears publish one update', () async {
    SharedPreferences.setMockInitialValues({
      'completedFocusSessions': 1,
      'focusHistory': jsonEncode([
        {
          'completedAt': '2026-08-09T12:00:00.000',
          'durationSeconds': 1500,
          'focusTask': 'Finish the proposal',
        },
      ]),
    });
    final timer = await createTimer();
    addTearDown(timer.dispose);
    final revision = timer.focusHistoryRevision;
    var notifications = 0;
    timer.addListener(() {
      notifications += 1;
    });
    final clearHistory = timer.clearFocusHistory;

    clearHistory();
    clearHistory();

    expect(timer.recentFocusSessions, isEmpty);
    expect(timer.completedFocusSessions, 0);
    expect(timer.focusHistoryRevision, revision + 1);
    expect(notifications, 1);
  });

  test('clearing local data restores the timer defaults', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 120,
      'secondsRemaining': 95,
      'totalSessionSeconds': 120,
      'sessionType': SessionType.shortBreak.index,
      'completedFocusSessions': 6,
      'focusTask': 'Finish the proposal',
      'dailyGoalMinutes': 120,
      'distractions': ['Reply to email'],
    });
    final timer = await createTimer();
    addTearDown(timer.dispose);

    await timer.clearLocalData();

    expect(timer.sessionType, SessionType.focus);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.completedFocusSessions, 0);
    expect(timer.focusTask, isEmpty);
    expect(timer.dailyGoalMinutes, 60);
    expect(timer.distractions, isEmpty);
    expect(timer.recentFocusSessions, isEmpty);
    expect(timer.isRunning, isFalse);
  });

  test('reopens an interrupted timer paused and ready to resume', () async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1500,
      'secondsRemaining': 100,
      'totalSessionSeconds': 1500,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .add(const Duration(seconds: 100))
          .millisecondsSinceEpoch,
    });
    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.hasPendingResume, isTrue);
    expect(timer.isRunning, isFalse);
    expect(timer.isComplete, isFalse);
    expect(timer.secondsRemaining, inInclusiveRange(1, 100));

    timer.discardPendingSession();
    expect(timer.hasPendingResume, isFalse);
    expect(timer.secondsRemaining, 1500);
  });

  test(
    'completed parked thoughts remain available and can be reopened',
    () async {
      final timer = await createTimer();
      addTearDown(timer.dispose);

      timer.captureDistraction('First thought');
      timer.captureDistraction('Second thought');
      final firstThought = timer.parkedThoughts.last;

      timer.completeParkedThought(firstThought.id);

      expect(timer.distractions, ['Second thought']);
      expect(timer.completedParkedThoughts, hasLength(1));
      expect(timer.completedParkedThoughts.single.text, 'First thought');
      expect(timer.completedParkedThoughts.single.completedAt, isNotNull);

      timer.clearDistractions();

      expect(timer.parkedThoughts, isEmpty);
      expect(timer.completedParkedThoughts, hasLength(1));

      timer.reopenParkedThought(firstThought.id);

      expect(timer.completedParkedThoughts, isEmpty);
      expect(timer.distractions, ['First thought']);
    },
  );

  test(
    'parked thought completion history survives reopening the app',
    () async {
      final firstTimer = await createTimer();
      addTearDown(firstTimer.dispose);
      firstTimer.captureDistraction('Schedule the appointment');
      final thoughtId = firstTimer.parkedThoughts.single.id;
      firstTimer.completeParkedThought(thoughtId);
      await Future<void>.delayed(Duration.zero);

      final reopenedTimer = await createTimer();
      addTearDown(reopenedTimer.dispose);

      expect(reopenedTimer.parkedThoughts, isEmpty);
      expect(reopenedTimer.completedParkedThoughts, hasLength(1));
      expect(reopenedTimer.completedParkedThoughts.single.id, thoughtId);
      expect(
        reopenedTimer.completedParkedThoughts.single.text,
        'Schedule the appointment',
      );
    },
  );

  test(
    'repairs parked thought storage and removes stale legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        'parkedThoughts': jsonEncode([
          {
            'id': '  thought-1  ',
            'text': '  Call   the dentist  ',
            'createdAt': '2026-08-08T12:00:00.000',
            'accidentalMetadata': 'remove me',
          },
          {
            'id': 'thought-1',
            'text': 'Duplicate identity',
            'createdAt': '2026-08-08T13:00:00.000',
          },
          {
            'id': 'broken-thought',
            'text': 'Broken record',
            'createdAt': 'not-a-date',
          },
          'not a parked thought',
        ]),
        'distractions': ['Stale legacy thought'],
      });

      final timer = await createTimer();
      addTearDown(timer.dispose);

      expect(timer.parkedThoughts, hasLength(1));
      expect(timer.parkedThoughts.single.id, 'thought-1');
      expect(timer.parkedThoughts.single.text, 'Call the dentist');
      final preferences = await SharedPreferences.getInstance();
      final repaired = jsonDecode(preferences.getString('parkedThoughts')!);
      expect(repaired, [
        {
          'id': 'thought-1',
          'text': 'Call the dentist',
          'createdAt': '2026-08-08T12:00:00.000',
        },
      ]);
      expect(preferences.getStringList('distractions'), isNull);
    },
  );

  test('legacy parked thoughts migrate without changing their order', () async {
    SharedPreferences.setMockInitialValues({
      'distractions': ['  First   saved thought  ', ' Second   saved thought '],
    });

    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.distractions, ['Second saved thought', 'First saved thought']);
    expect(
      timer.parkedThoughts.every((thought) => !thought.isCompleted),
      isTrue,
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('parkedThoughts'), isNotNull);
    expect(preferences.getStringList('distractions'), isNull);
  });

  test('reset records a text-free focus attempt and its return', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);
    timer.setCustomDuration(1, 0);
    timer.setFocusTask('Private presentation details');

    timer.start();
    timer.pause();
    timer.start();
    timer.reset();

    final event = timer.recentFocusEvents.single;
    expect(event.outcome, FocusEventOutcome.reset);
    expect(event.plannedDurationSeconds, 60);
    expect(event.focusedDurationSeconds, 0);
    expect(event.pauseCount, 1);
    expect(event.didResume, isTrue);
    final backupEvents = timer.cloudBackup['focusEvents'] as List;
    expect(backupEvents, hasLength(1));
    expect(backupEvents.single.toString(), isNot(contains('presentation')));
    expect(backupEvents.single.toString(), isNot(contains('task')));
  });

  test(
    'completed focus restores and closes an active private attempt',
    () async {
      final startedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 1),
      );
      SharedPreferences.setMockInitialValues({
        'focusSeconds': 60,
        'secondsRemaining': 1,
        'totalSessionSeconds': 60,
        'sessionType': SessionType.focus.index,
        'timerEndsAt': DateTime.now()
            .subtract(const Duration(seconds: 2))
            .millisecondsSinceEpoch,
        'activeFocusAttempt': jsonEncode({
          'startedAt': startedAt.toIso8601String(),
          'plannedDurationSeconds': 60,
          'pauseCount': 1,
          'didResume': true,
        }),
      });

      final timer = await createTimer();
      addTearDown(timer.dispose);

      final event = timer.recentFocusEvents.single;
      expect(event.outcome, FocusEventOutcome.completed);
      expect(event.focusedDurationSeconds, 60);
      expect(event.pauseCount, 1);
      expect(event.didResume, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('activeFocusAttempt'), isNull);
    },
  );

  test(
    'repairs damaged saved focus events without losing valid signals',
    () async {
      final valid = FocusEvent(
        startedAt: DateTime.utc(2026, 8, 16, 12),
        endedAt: DateTime.utc(2026, 8, 16, 12, 10),
        plannedDurationSeconds: 15 * 60,
        focusedDurationSeconds: 10 * 60,
        pauseCount: 0,
        didResume: false,
        outcome: FocusEventOutcome.reset,
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'focusEvents': jsonEncode([
          {...valid, 'privateTask': 'Do not retain this'},
          {...valid, 'outcome': 'unknown'},
          'not an event',
        ]),
      });

      final timer = await createTimer();
      addTearDown(timer.dispose);

      expect(timer.recentFocusEvents, hasLength(1));
      final preferences = await SharedPreferences.getInstance();
      final repaired =
          jsonDecode(preferences.getString('focusEvents')!) as List;
      expect(repaired, hasLength(1));
      expect(repaired.single.toString(), isNot(contains('privateTask')));
      expect(repaired.single.toString(), isNot(contains('retain')));
    },
  );

  test('older cloud backups remain valid without focus events', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    final restored = timer.restoreCloudBackup({
      'focusSeconds': 25 * 60,
      'shortBreakSeconds': 5 * 60,
      'longBreakSeconds': 15 * 60,
      'completedFocusSessions': 0,
      'focusTask': '',
      'dailyGoalMinutes': 60,
      'focusHistory': <Object?>[],
    });

    expect(restored, isTrue);
    expect(timer.recentFocusEvents, isEmpty);
  });

  test(
    'malformed cloud focus events fail without changing local data',
    () async {
      final timer = await createTimer();
      addTearDown(timer.dispose);
      timer.setCustomDuration(30, 0);
      final revision = timer.focusEventsRevision;

      final restored = timer.restoreCloudBackup({
        'focusSeconds': 25 * 60,
        'shortBreakSeconds': 5 * 60,
        'longBreakSeconds': 15 * 60,
        'completedFocusSessions': 0,
        'focusTask': '',
        'dailyGoalMinutes': 60,
        'focusHistory': <Object?>[],
        'focusEvents': [
          {'schemaVersion': 1, 'outcome': 'completed'},
        ],
      });

      expect(restored, isFalse);
      expect(timer.totalSessionSeconds, 30 * 60);
      expect(timer.recentFocusEvents, isEmpty);
      expect(timer.focusEventsRevision, revision);
    },
  );
}
