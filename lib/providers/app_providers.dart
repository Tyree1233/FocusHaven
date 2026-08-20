import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/feature_flags.dart';
import '../models/coaching_message.dart';
import '../models/focus_event.dart';
import '../models/focus_forecast.dart';
import '../models/focus_shield_state.dart';
import '../models/focus_session.dart';
import '../models/haven_journey_state.dart';
import '../models/haven_plan.dart';
import '../models/haven_rhythm_insight.dart';
import '../models/haven_window_hold.dart';
import '../models/haven_window_suggestion.dart';
import '../models/living_lantern_state.dart';
import '../models/journal_entry.dart';
import '../models/parked_thought.dart';
import '../models/pro_entitlement.dart';
import '../models/system_focus_snapshot.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/coaching_service.dart';
import '../services/focus_forecast_service.dart';
import '../services/focus_profile_service.dart';
import '../services/focus_queue_service.dart';
import '../services/focus_shield_service.dart';
import '../services/focus_shield_platform_bridge.dart';
import '../services/haven_journey_service.dart';
import '../services/haven_plan_service.dart';
import '../services/haven_rhythm_service.dart';
import '../services/haven_window_hold_service.dart';
import '../services/haven_window_service.dart';
import '../services/haven_window_platform_bridge.dart';
import '../services/iap_service.dart';
import '../services/journal_service.dart';
import '../services/living_lantern_service.dart';
import '../services/notification_service.dart';
import '../services/remote_coaching_responder.dart';
import '../services/reminder_service.dart';
import '../services/smart_reset_service.dart';
import '../services/system_focus_command_router.dart';
import '../services/system_focus_platform_bridge.dart';
import '../services/system_focus_surface_service.dart';
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
  bool isManagingPrivateData,
  bool canRetryResponse,
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

/// One text-free, local reminder the user explicitly created for an opening.
typedef HavenWindowHoldState = ({
  bool isHeld,
  bool hasArrived,
  DateTime? startsAtUtc,
  DateTime? endsAtUtc,
  bool isUpdating,
  int lifecycleRevision,
});

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

/// Completion boundary required before trusted system surfaces publish or act.
final timerInitializationProvider = Provider<Future<void>>((ref) {
  return ref.watch(timerServiceProvider).initialized;
}, name: 'timerInitializationProvider');

/// Stable running deadline shared with system surfaces without widening the
/// high-frequency countdown read model.
final timerEndsAtProvider = Provider<DateTime?>((ref) {
  return ref.watch(timerServiceProvider.select((timer) => timer.endsAt));
}, name: 'timerEndsAtProvider');

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

final focusForecastServiceProvider = Provider<FocusForecastService>(
  (ref) => const FocusForecastService(),
  name: 'focusForecastServiceProvider',
);

final focusProfileServiceProvider = ChangeNotifierProvider<FocusProfileService>(
  (ref) => FocusProfileService(),
  name: 'focusProfileServiceProvider',
);

final focusQueueServiceProvider = ChangeNotifierProvider<FocusQueueService>(
  (ref) => FocusQueueService(),
  name: 'focusQueueServiceProvider',
);

final focusShieldServiceProvider = Provider<FocusShieldService>(
  (ref) => const FocusShieldService(),
  name: 'focusShieldServiceProvider',
);

final focusShieldPlatformBackendProvider = Provider<FocusShieldPlatformBackend>(
  (ref) => MethodChannelFocusShieldBackend(),
  name: 'focusShieldPlatformBackendProvider',
);

final focusShieldPlatformControllerProvider =
    ChangeNotifierProvider<FocusShieldPlatformController>((ref) {
      return FocusShieldPlatformController(
        backend: ref.watch(focusShieldPlatformBackendProvider),
      );
    }, name: 'focusShieldPlatformControllerProvider');

/// Text-free capability report owned by the native Focus Shield controller.
///
/// App and website selections stay native and never enter Riverpod. Unsupported
/// platforms fail open and cannot claim that protection is active.
final focusShieldCapabilityProvider = Provider<FocusShieldCapability>(
  (ref) => ref.watch(focusShieldPlatformControllerProvider).capability,
  name: 'focusShieldCapabilityProvider',
);

final havenJourneyServiceProvider = Provider<HavenJourneyService>(
  (ref) => const HavenJourneyService(),
  name: 'havenJourneyServiceProvider',
);

final havenPlanServiceProvider = Provider<HavenPlanService>(
  (ref) => const HavenPlanService(),
  name: 'havenPlanServiceProvider',
);

final havenRhythmServiceProvider = Provider<HavenRhythmService>(
  (ref) => const HavenRhythmService(),
  name: 'havenRhythmServiceProvider',
);

final havenWindowServiceProvider = Provider<HavenWindowService>(
  (ref) => const HavenWindowService(),
  name: 'havenWindowServiceProvider',
);

final havenWindowHoldServiceProvider =
    ChangeNotifierProvider<HavenWindowHoldService>((ref) {
      return HavenWindowHoldService(
        notificationService: ref.watch(notificationServiceProvider),
      );
    }, name: 'havenWindowHoldServiceProvider');

/// Narrow reminder state that contains only bounded UTC window boundaries.
final havenWindowHoldStateProvider = Provider<HavenWindowHoldState>((ref) {
  final service = ref.watch(havenWindowHoldServiceProvider);
  final HavenWindowHold hold = service.holdState;
  return (
    isHeld: hold.isHeld,
    hasArrived: hold.hasArrived,
    startsAtUtc: hold.startsAtUtc,
    endsAtUtc: hold.endsAtUtc,
    isUpdating: service.isUpdating,
    lifecycleRevision: service.lifecycleRevision,
  );
}, name: 'havenWindowHoldStateProvider');

final havenWindowPlatformBackendProvider = Provider<HavenWindowPlatformBackend>(
  (ref) => MethodChannelHavenWindowBackend(),
  name: 'havenWindowPlatformBackendProvider',
);

final havenWindowPlatformControllerProvider =
    ChangeNotifierProvider<HavenWindowPlatformController>((ref) {
      return HavenWindowPlatformController(
        backend: ref.watch(havenWindowPlatformBackendProvider),
      );
    }, name: 'havenWindowPlatformControllerProvider');

/// Redacted calendar availability from the dormant consent-first controller.
/// Unless a supported host explicitly starts that controller, the default
/// remains unsupported and reads or schedules nothing.
final privateCalendarAvailabilityProvider =
    Provider<PrivateCalendarAvailability>(
      (ref) => ref.watch(havenWindowPlatformControllerProvider).availability,
      name: 'privateCalendarAvailabilityProvider',
    );

/// Supplies a fresh local evaluation time whenever the private suggestion is
/// rebuilt. It is overridable so boundary behavior stays deterministic in
/// tests without introducing a background clock.
final havenWindowCurrentTimeProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'havenWindowCurrentTimeProvider',
);

final livingLanternServiceProvider = Provider<LivingLanternService>(
  (ref) => const LivingLanternService(),
  name: 'livingLanternServiceProvider',
);

final smartResetServiceProvider = Provider<SmartResetService>(
  (ref) => const SmartResetService(),
  name: 'smartResetServiceProvider',
);

final systemFocusSurfaceServiceProvider = Provider<SystemFocusSurfaceService>(
  (ref) => const SystemFocusSurfaceService(),
  name: 'systemFocusSurfaceServiceProvider',
);

final systemFocusCommandRouterProvider = Provider<SystemFocusCommandRouter>(
  (ref) => SystemFocusCommandRouter(),
  name: 'systemFocusCommandRouterProvider',
);

final systemFocusPlatformBackendProvider = Provider<SystemFocusPlatformBackend>(
  (ref) => MethodChannelSystemFocusBackend(),
  name: 'systemFocusPlatformBackendProvider',
);

/// Owns the dormant native bridge. A supported platform host must explicitly
/// start it after its native snapshot store and command adapter are installed.
final systemFocusPlatformBridgeProvider = Provider<SystemFocusPlatformBridge>((
  ref,
) {
  final timer = ref.read(timerServiceProvider);
  final bridge = SystemFocusPlatformBridge(
    backend: ref.watch(systemFocusPlatformBackendProvider),
    router: ref.watch(systemFocusCommandRouterProvider),
    readSnapshot: () => ref.read(systemFocusSnapshotProvider),
    target: (
      start: timer.start,
      pause: timer.pause,
      resumePending: timer.resumePendingSession,
      reset: timer.reset,
      beginNextSession: timer.beginNextSession,
      discardPending: timer.discardPendingSession,
    ),
  );
  ref.onDispose(bridge.dispose);
  return bridge;
}, name: 'systemFocusPlatformBridgeProvider');

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

/// Whether the current session has moved away from its fresh starting point.
/// This changes only at session boundaries, unlike the one-second countdown.
final timerHasProgressProvider = Provider<bool>((ref) {
  return ref.watch(
    timerServiceProvider.select(
      (timer) => timer.secondsRemaining < timer.totalSessionSeconds,
    ),
  );
}, name: 'timerHasProgressProvider');

/// Whether one explicit action may begin a fresh, idle focus session.
final timerCanBeginFreshFocusProvider = Provider<bool>((ref) {
  return ref.watch(
    timerServiceProvider.select((timer) => timer.canStartHavenPlan),
  );
}, name: 'timerCanBeginFreshFocusProvider');

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

/// Rebuilds a private, non-punitive Haven place from the cumulative completion
/// count already owned by the timer. The derived state is not persisted by
/// itself, and no interruption, missed day, pause, or reset can reduce it.
final havenJourneyStateProvider = Provider<HavenJourneyState>((ref) {
  final completedSessions = ref.watch(
    timerSummaryStateProvider.select(
      (summary) => summary.completedFocusSessions,
    ),
  );
  return ref
      .watch(havenJourneyServiceProvider)
      .createState(completedFocusSessions: completedSessions);
}, name: 'havenJourneyStateProvider');

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

/// Rebuilds one cautious, private time-of-day observation from the bounded
/// text-free event snapshot. It cannot schedule, start, or rank focus time.
final focusForecastProvider = Provider<FocusForecast>((ref) {
  final events = ref.watch(timerFocusEventsProvider);
  return ref
      .watch(focusForecastServiceProvider)
      .createForecast(recentEvents: events);
}, name: 'focusForecastProvider');

/// Combines only a cautious forecast and redacted busy-time boundaries into
/// one optional opening. The result cannot create calendar events or control
/// the timer.
final havenWindowSuggestionProvider = Provider<HavenWindowSuggestion>((ref) {
  ref.watch(
    havenWindowHoldStateProvider.select(
      (state) => (state.isHeld, state.hasArrived, state.lifecycleRevision),
    ),
  );
  return ref
      .watch(havenWindowServiceProvider)
      .createSuggestion(
        forecast: ref.watch(focusForecastProvider),
        availability: ref.watch(privateCalendarAvailabilityProvider),
        now: ref.watch(havenWindowCurrentTimeProvider)().toLocal(),
      );
}, name: 'havenWindowSuggestionProvider');

/// Rebuilds one transparent, ephemeral rhythm insight from private text-free
/// focus events. The insight is local and is never persisted by itself.
final havenRhythmInsightProvider = Provider<HavenRhythmInsight>((ref) {
  final events = ref.watch(timerFocusEventsProvider);
  return ref
      .watch(havenRhythmServiceProvider)
      .createInsight(recentEvents: events);
}, name: 'havenRhythmInsightProvider');

/// Rebuilds the lantern from current timer controls and private text-free
/// events. The result is local, ephemeral, informational, and non-punitive.
final livingLanternStateProvider = Provider<LivingLanternState>((ref) {
  final session = ref.watch(timerSessionStateProvider);
  final events = ref.watch(timerFocusEventsProvider);
  return ref
      .watch(livingLanternServiceProvider)
      .createState(
        sessionType: session.sessionType,
        isRunning: session.isRunning,
        isComplete: session.isComplete,
        hasPendingResume: session.hasPendingResume,
        recentEvents: events,
      );
}, name: 'livingLanternStateProvider');

/// Derives an honest Focus Shield request from narrow timer and native states.
/// The result cannot invoke native APIs, alter the timer, or receive selected
/// application and website identities.
final focusShieldStateProvider = Provider<FocusShieldState>((ref) {
  final session = ref.watch(timerSessionStateProvider);
  final hasProgress = ref.watch(timerHasProgressProvider);
  final activity = session.hasPendingResume
      ? SystemFocusActivity.pendingResume
      : session.isComplete
      ? SystemFocusActivity.completed
      : session.isRunning
      ? SystemFocusActivity.running
      : hasProgress
      ? SystemFocusActivity.paused
      : SystemFocusActivity.ready;
  final systemSession = switch (session.sessionType) {
    SessionType.focus => SystemFocusSession.focus,
    SessionType.shortBreak => SystemFocusSession.shortBreak,
    SessionType.longBreak => SystemFocusSession.longBreak,
  };
  return ref
      .watch(focusShieldServiceProvider)
      .createState(
        capability: ref.watch(focusShieldCapabilityProvider),
        timer: (session: systemSession, activity: activity),
      );
}, name: 'focusShieldStateProvider');

/// Creates the bounded, text-free state contract used by trusted system
/// surfaces. No task, journal, coach, history, mood, or account data enters it.
final systemFocusSnapshotProvider = Provider<SystemFocusSnapshot>((ref) {
  final countdown = ref.watch(timerCountdownStateProvider);
  final session = ref.watch(timerSessionStateProvider);
  final endsAt = ref.watch(timerEndsAtProvider);
  return ref
      .watch(systemFocusSurfaceServiceProvider)
      .createSnapshot(
        sessionType: session.sessionType,
        isRunning: session.isRunning,
        isComplete: session.isComplete,
        hasPendingResume: session.hasPendingResume,
        secondsRemaining: countdown.secondsRemaining,
        totalSessionSeconds: countdown.totalSessionSeconds,
        generatedAt: DateTime.now(),
        endsAt: endsAt,
      );
}, name: 'systemFocusSnapshotProvider');

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
    isManagingPrivateData: coach.isManagingPrivateData,
    canRetryResponse: coach.canRetryResponse,
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
