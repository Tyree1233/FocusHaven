import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/focus_session.dart';
import '../models/journal_entry.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/focus_profile_service.dart';
import '../services/focus_queue_service.dart';
import '../services/iap_service.dart';
import '../services/journal_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/theme_service.dart';
import '../services/timer_service.dart';

/// High-frequency state rendered by the countdown itself.
///
/// A Dart record gives this state structural equality. Riverpod can therefore
/// avoid notifying countdown consumers when unrelated timer data changes.
typedef TimerCountdownState = ({
  int secondsRemaining,
  int totalSessionSeconds,
  double progress,
});

/// Timer state that changes only when the user controls a session.
typedef TimerSessionState = ({
  SessionType sessionType,
  bool isRunning,
  bool isComplete,
  bool hasPendingResume,
  String focusTask,
  int parkedThoughtCount,
  String completionMessage,
});

/// Aggregated progress shown by the timer screen's summary cards.
typedef TimerSummaryState = ({
  int todayFocusMinutes,
  int currentStreak,
  int completedFocusSessions,
  int dailyGoalMinutes,
  double dailyGoalProgress,
  bool hasReachedDailyGoal,
  int todayFocusSessions,
  int dailyChallengeTarget,
  double dailyChallengeProgress,
  bool hasCompletedDailyChallenge,
});

/// Immutable queue data used by the Focus Queue sheets.
typedef FocusQueueState = ({
  List<FocusQueueItem> activeItems,
  List<FocusQueueItem> completedItems,
  int completedToday,
});

/// Immutable journal data used by the Reflection Journal sheet.
typedef JournalState = ({
  List<JournalEntry> entries,
  Map<String, int> recentMoodCounts,
  String? mostCommonRecentMood,
  String dailyPrompt,
  JournalEntry? todayEntry,
});

/// Immutable authentication data rendered by account-related views.
typedef AuthState = ({
  bool isSignedIn,
  String displayName,
  String? signInError,
});

/// Immutable reminder settings rendered by the reminder sheet.
typedef ReminderState = ({bool isEnabled, TimeOfDay time, Set<int> weekdays});

/// Central ownership and dependency wiring for FocusHaven's application state.
///
/// Existing [ChangeNotifier] services use Riverpod's compatibility providers
/// during the gradual migration. Each service can later move to a Riverpod
/// notifier without changing how views locate their dependencies.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
  name: 'notificationServiceProvider',
);

final timerServiceProvider = ChangeNotifierProvider<TimerService>(
  (ref) =>
      TimerService(notificationService: ref.watch(notificationServiceProvider)),
  name: 'timerServiceProvider',
);

final reminderServiceProvider = ChangeNotifierProvider<ReminderService>(
  (ref) => ReminderService(
    notificationService: ref.watch(notificationServiceProvider),
  ),
  name: 'reminderServiceProvider',
);

/// Narrow reminder snapshot that prevents views from depending on the complete
/// mutable service and protects the selected weekdays from accidental changes.
final reminderStateProvider = Provider<ReminderState>((ref) {
  final reminder = ref.watch(reminderServiceProvider);
  return (
    isEnabled: reminder.isEnabled,
    time: reminder.time,
    weekdays: Set<int>.unmodifiable(reminder.weekdays),
  );
}, name: 'reminderStateProvider');

final authServiceProvider = ChangeNotifierProvider<AuthService>(
  (ref) => AuthService(),
  name: 'authServiceProvider',
);

final focusProfileServiceProvider = ChangeNotifierProvider<FocusProfileService>(
  (ref) => FocusProfileService(),
  name: 'focusProfileServiceProvider',
);

final focusQueueServiceProvider = ChangeNotifierProvider<FocusQueueService>(
  (ref) => FocusQueueService(),
  name: 'focusQueueServiceProvider',
);

final journalServiceProvider = ChangeNotifierProvider<JournalService>(
  (ref) => JournalService(),
  name: 'journalServiceProvider',
);

final themeServiceProvider = ChangeNotifierProvider<ThemeService>(
  (ref) => ThemeService(),
  name: 'themeServiceProvider',
);

final cloudSyncServiceProvider = Provider<CloudSyncService>(
  (ref) => CloudSyncService(),
  name: 'cloudSyncServiceProvider',
);

final iapServiceProvider = Provider<IAPService>((ref) {
  final service = IAPService();
  ref.onDispose(service.dispose);
  return service;
}, name: 'iapServiceProvider');

/// Loads the persisted Pro entitlement, then follows purchase and restore
/// updates without coupling views to the store service implementation.
final proEntitlementProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(iapServiceProvider);

  yield await service.refreshEntitlement();
  yield* service.entitlementChanges;
}, name: 'proEntitlementProvider');

/// Narrow read model for the one-second timer updates.
final timerCountdownStateProvider = Provider<TimerCountdownState>((ref) {
  final timer = ref.watch(timerServiceProvider);
  return (
    secondsRemaining: timer.secondsRemaining,
    totalSessionSeconds: timer.totalSessionSeconds,
    progress: timer.progress,
  );
}, name: 'timerCountdownStateProvider');

/// Narrow read model for start, pause, reset, and completion state.
final timerSessionStateProvider = Provider<TimerSessionState>((ref) {
  final timer = ref.watch(timerServiceProvider);
  return (
    sessionType: timer.sessionType,
    isRunning: timer.isRunning,
    isComplete: timer.isComplete,
    hasPendingResume: timer.hasPendingResume,
    focusTask: timer.focusTask,
    parkedThoughtCount: timer.distractions.length,
    completionMessage: timer.completionMessage,
  );
}, name: 'timerSessionStateProvider');

/// Narrow read model for progress cards and daily encouragement.
final timerSummaryStateProvider = Provider<TimerSummaryState>((ref) {
  final timer = ref.watch(timerServiceProvider);
  return (
    todayFocusMinutes: timer.todayFocusMinutes,
    currentStreak: timer.currentStreak,
    completedFocusSessions: timer.completedFocusSessions,
    dailyGoalMinutes: timer.dailyGoalMinutes,
    dailyGoalProgress: timer.dailyGoalProgress,
    hasReachedDailyGoal: timer.hasReachedDailyGoal,
    todayFocusSessions: timer.todayFocusSessions,
    dailyChallengeTarget: timer.dailyChallengeTarget,
    dailyChallengeProgress: timer.dailyChallengeProgress,
    hasCompletedDailyChallenge: timer.hasCompletedDailyChallenge,
  );
}, name: 'timerSummaryStateProvider');

/// Immutable history snapshot that changes only when sessions are added,
/// restored, or cleared—not on every countdown tick.
final timerFocusHistoryProvider = Provider<List<FocusSession>>((ref) {
  ref.watch(timerServiceProvider.select((timer) => timer.focusHistoryRevision));

  return ref.read(timerServiceProvider).recentFocusSessions;
}, name: 'timerFocusHistoryProvider');

/// Immutable queue snapshot that changes only when queue data is loaded,
/// added, edited, completed, restored, removed, or cleared.
final focusQueueStateProvider = Provider<FocusQueueState>((ref) {
  ref.watch(focusQueueServiceProvider.select((queue) => queue.queueRevision));

  final queue = ref.read(focusQueueServiceProvider);
  return (
    activeItems: queue.items,
    completedItems: queue.completedItems,
    completedToday: queue.completedToday,
  );
}, name: 'focusQueueStateProvider');

/// Immutable journal snapshot that changes only when entries are loaded,
/// saved, replaced, or cleared.
final journalStateProvider = Provider<JournalState>((ref) {
  ref.watch(
    journalServiceProvider.select((journal) => journal.journalRevision),
  );

  final journal = ref.read(journalServiceProvider);
  return (
    entries: journal.entries,
    recentMoodCounts: Map.unmodifiable(journal.recentMoodCounts),
    mostCommonRecentMood: journal.mostCommonRecentMood,
    dailyPrompt: journal.dailyPrompt,
    todayEntry: journal.todayEntry,
  );
}, name: 'journalStateProvider');

/// Immutable authentication snapshot shared by account-related views.
final authStateProvider = Provider<AuthState>((ref) {
  final auth = ref.watch(authServiceProvider);
  return (
    isSignedIn: auth.isSignedIn,
    displayName: auth.displayName,
    signInError: auth.signInError,
  );
}, name: 'authStateProvider');

/// Exposes authentication status independently from account presentation data.
final authIsSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider.select((auth) => auth.isSignedIn)),
  name: 'authIsSignedInProvider',
);

/// Exposes the selected appearance palette without coupling views to the
/// complete theme service.
final selectedThemeProvider = Provider<FocusHavenTheme>(
  (ref) => ref.watch(themeServiceProvider).selectedTheme,
  name: 'selectedThemeProvider',
);

/// Exposes the saved focus profile without rebuilding for unrelated service
/// notifications.
final focusProfileTypeProvider = Provider<String?>(
  (ref) => ref.watch(focusProfileServiceProvider).focusType,
  name: 'focusProfileTypeProvider',
);

/// Exposes the queue badge count independently from the queue item collection.
final focusQueueRemainingCountProvider = Provider<int>(
  (ref) => ref.watch(focusQueueServiceProvider).remainingCount,
  name: 'focusQueueRemainingCountProvider',
);
