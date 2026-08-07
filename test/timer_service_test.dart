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
    await Future<void>.delayed(Duration.zero);
    return timer;
  }

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
      'timerEndsAt': DateTime.now().add(const Duration(seconds: 100)).millisecondsSinceEpoch,
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
}
