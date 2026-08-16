import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/feature_flags.dart';
import '../models/coaching_message.dart';
import '../models/focus_event.dart';
import '../models/focus_session.dart';
import '../models/haven_plan.dart';
import '../models/haven_rhythm_insight.dart';
import '../models/journal_entry.dart';
import '../models/parked_thought.dart';
import '../models/pro_entitlement.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/coaching_service.dart';
import '../services/focus_profile_service.dart';
import '../services/focus_queue_service.dart';
import '../services/haven_plan_service.dart';
import '../services/haven_rhythm_service.dart';
import '../services/iap_service.dart';
import '../services/journal_service.dart';
import '../services/notification_service.dart';
import '../services/remote_coaching_responder.dart';
import '../services/reminder_service.dart';
import '../services/smart_reset_service.dart';
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
  FocusSessionFit? completedFocusSessionFit,
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

typedef HavenPlanRequest = ({HavenEnergy energy, int availableMinutes});

/// Immutable journal data used by the Reflection Journal sheet.
typedef JournalState = ({
  List<JournalEntry> entries,
  List<JournalEntry> todayEntries,
  Map<String, int> recentMoodCounts,
  String? mostCommonRecentMood,
  String dailyPrompt,
});

/// Immutable conversation data rendered by the private focus coach.
typedef CoachingState = ({
  List<CoachingMessage> messages,
  bool isResponding,
  bool enhancedCoachingAvailable,
  bool enhancedCoachingEnabled,
  String? errorMessage,
  String? noticeMessage,
  int conversationRevision,
});

/// Immutable parking-lot data separated from the one-second timer state.
typedef ParkedThoughtState = ({
  List<ParkedThought> activeThoughts,
  List<ParkedThought> completedThoughts,
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

final havenPlanServiceProvider = Provider<HavenPlanService>(
  (ref) => const HavenPlanService(),
  name: 'havenPlanServiceProvider',
);

final havenRhythmServiceProvider = Provider<HavenRhythmService>(
  (ref) => const HavenRhythmService(),
  name: 'havenRhythmServiceProvider',
);

final smartResetServiceProvider = Provider<SmartResetService>(
  (ref) => const SmartResetService(),
  name: 'smartResetServiceProvider',
);

final journalServiceProvider = ChangeNotifierProvider<JournalService>(
  (ref) => JournalService(),
  name: 'journalServiceProvider',
);

final coachingServiceProvider = ChangeNotifierProvider<CoachingService>(
  (ref) => CoachingService(
    enhancedResponder: FeatureFlags.remoteCoachingEnabled
        ? createEnhancedCoachingResponder()
        : null,
  ),
  name: 'coachingServiceProvider',
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
  final service = IAPService(
    legacyLifetimePurchasesEnabled: FeatureFlags.legacyLifetimePurchasesEnabled,
  );
  ref.onDispose(service.dispose);
  return service;
}, name: 'iapServiceProvider');

/// Loads the complete local Pro entitlement, then follows purchase and restore
/// updates without coupling views to the store service implementation.
final proEntitlementDetailsProvider = StreamProvider<ProEntitlement>((
  ref,
) async* {
  final service = ref.watch(iapServiceProvider);

  await service.initialized;
  yield service.lastKnownEntitlement ?? await service.refreshProEntitlement();
  yield* service.proEntitlementChanges;
}, name: 'proEntitlementDetailsProvider');

/// Compatibility view used by existing Pro surfaces while subscription-aware
/// presentation and server verification are introduced incrementally.
final proEntitlementProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(iapServiceProvider);

  await service.initialized;
  final initial =
      service.lastKnownEntitlement ?? await service.refreshProEntitlement();
  yield initial.isActiveAt(DateTime.now());
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
    completedFocusSessionFit: timer.completedFocusSessionFit,
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

/// Text-free focus attempt signals used by future local recovery and rhythm
/// features. This snapshot changes only when an attempt ends or history clears.
final timerFocusEventsProvider = Provider<List<FocusEvent>>((ref) {
  ref.watch(timerServiceProvider.select((timer) => timer.focusEventsRevision));

  return ref.read(timerServiceProvider).recentFocusEvents;
}, name: 'timerFocusEventsProvider');

/// Rebuilds one transparent, ephemeral rhythm insight from private text-free
/// focus events. The insight is local and is never persisted by itself.
final havenRhythmInsightProvider = Provider<HavenRhythmInsight>((ref) {
  final events = ref.watch(timerFocusEventsProvider);
  return ref
      .watch(havenRhythmServiceProvider)
      .createInsight(recentEvents: events);
}, name: 'havenRhythmInsightProvider');

/// Parking-lot snapshot that changes only when a thought is captured, edited,
/// completed, reopened, removed, migrated, or cleared.
final parkedThoughtStateProvider = Provider<ParkedThoughtState>((ref) {
  ref.watch(
    timerServiceProvider.select((timer) => timer.parkedThoughtsRevision),
  );

  final timer = ref.read(timerServiceProvider);
  return (
    activeThoughts: timer.parkedThoughts,
    completedThoughts: timer.completedParkedThoughts,
  );
}, name: 'parkedThoughtStateProvider');

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

/// Creates an ephemeral, local-only plan from the current queue, the user's
/// explicit energy check-in, available time, and text-free focus events.
final havenPlanProvider = Provider.family<HavenPlan, HavenPlanRequest>((
  ref,
  request,
) {
  final queue = ref.watch(focusQueueStateProvider).activeItems;
  final events = ref.watch(timerFocusEventsProvider);
  return ref
      .watch(havenPlanServiceProvider)
      .createPlan(
        queue: [
          for (final item in queue)
            HavenTaskCandidate(id: item.id, title: item.title),
        ],
        recentEvents: events,
        energy: request.energy,
        availableMinutes: request.availableMinutes,
      );
}, name: 'havenPlanProvider');

/// Immutable journal snapshot that changes only when entries are loaded,
/// added, updated, replaced, or cleared.
final journalStateProvider = Provider<JournalState>((ref) {
  ref.watch(
    journalServiceProvider.select((journal) => journal.journalRevision),
  );

  final journal = ref.read(journalServiceProvider);
  final now = DateTime.now().toLocal();
  final todayEntries = journal.entries
      .where((entry) {
        final createdAt = entry.createdAt.toLocal();
        return createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day;
      })
      .toList(growable: false);
  return (
    entries: journal.entries,
    todayEntries: List.unmodifiable(todayEntries),
    recentMoodCounts: Map.unmodifiable(journal.recentMoodCounts),
    mostCommonRecentMood: journal.mostCommonRecentMood,
    dailyPrompt: journal.dailyPrompt,
  );
}, name: 'journalStateProvider');

/// Conversation snapshot that updates only when coaching state changes.
final coachingStateProvider = Provider<CoachingState>((ref) {
  final coach = ref.watch(coachingServiceProvider);
  return (
    messages: List<CoachingMessage>.unmodifiable(coach.messages),
    isResponding: coach.isResponding,
    enhancedCoachingAvailable: coach.enhancedCoachingAvailable,
    enhancedCoachingEnabled: coach.enhancedCoachingEnabled,
    errorMessage: coach.errorMessage,
    noticeMessage: coach.noticeMessage,
    conversationRevision: coach.conversationRevision,
  );
}, name: 'coachingStateProvider');

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
