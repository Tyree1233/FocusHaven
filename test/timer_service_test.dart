import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('starts with a 25-minute focus session', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    expect(timer.sessionType, SessionType.focus);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.isRunning, isFalse);
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

  test('switching sessions uses the correct saved duration', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.selectSession(SessionType.shortBreak);
    timer.setCustomDuration(3, 10);
    timer.selectSession(SessionType.focus);
    timer.beginNextSession();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.secondsRemaining, 190);
    expect(timer.isComplete, isFalse);
    expect(timer.isRunning, isFalse);
  });

  test('focus tasks and parked thoughts are cleaned before saving', () async {
    final timer = await createTimer();
    addTearDown(timer.dispose);

    timer.setFocusTask('  Write   project   outline  ');
    timer.captureDistraction('  Reply    to   that   email  ');

    expect(timer.focusTask, 'Write project outline');
    expect(timer.distractions, ['Reply to that email']);
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
}
