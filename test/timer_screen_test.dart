import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/models/focus_shield_state.dart';
import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/models/haven_window_suggestion.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/timer_screen.dart';
import 'package:focushaven/services/coaching_service.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_loop_service.dart';
import 'package:focushaven/services/haven_window_platform_bridge.dart';
import 'package:focushaven/services/haven_window_hold_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/coaching_sheet.dart';
import 'package:focushaven/widgets/focus_session_reflection_card.dart';
import 'package:focushaven/widgets/focus_forecast_card.dart';
import 'package:focushaven/widgets/focus_forecast_reflection_connection_card.dart';
import 'package:focushaven/widgets/focus_shield_card.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';
import 'package:focushaven/widgets/haven_plan_sheet.dart';
import 'package:focushaven/widgets/haven_planner_sheet.dart';
import 'package:focushaven/widgets/haven_journey_card.dart';
import 'package:focushaven/widgets/haven_journey_completion_connection_card.dart';
import 'package:focushaven/widgets/haven_rhythm_card.dart';
import 'package:focushaven/widgets/haven_rhythm_reflection_connection_card.dart';
import 'package:focushaven/widgets/haven_window_card.dart';
import 'package:focushaven/widgets/living_lantern_card.dart';
import 'package:focushaven/widgets/smart_reset_sheet.dart';

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

Widget _app(
  TimerService timer, {
  NavigatorObserver? observer,
  CoachingService? coachingService,
  Future<bool> Function(Uri uri)? openExternalUrl,
  Future<void> Function(String text)? writeClipboard,
  List<FocusQueueItem> havenQueue = const [],
  FocusQueueService? focusQueueService,
  HavenJourneyState? journeyState,
  HavenRhythmInsight? rhythmInsight,
  FocusForecast? forecast,
  FocusShieldState? shieldState,
  HavenWindowPlatformController? havenWindowController,
  HavenWindowHoldService? havenWindowHoldService,
  HavenWindowSuggestion? havenWindowSuggestion,
  DateTime Function()? havenWindowCurrentTime,
}) {
  return ProviderScope(
    overrides: [
      timerServiceProvider.overrideWith((ref) => timer),
      if (coachingService != null)
        coachingServiceProvider.overrideWith((ref) => coachingService),
      authStateProvider.overrideWithValue((
        isSignedIn: false,
        displayName: 'Guest',
        signInError: null,
      )),
      authIsSignedInProvider.overrideWithValue(false),
      focusQueueRemainingCountProvider.overrideWithValue(havenQueue.length),
      focusQueueStateProvider.overrideWithValue((
        activeItems: havenQueue,
        completedItems: const [],
        completedToday: 0,
      )),
      if (focusQueueService != null)
        focusQueueServiceProvider.overrideWith((ref) => focusQueueService),
      if (rhythmInsight != null)
        havenRhythmInsightProvider.overrideWithValue(rhythmInsight),
      if (journeyState != null)
        havenJourneyStateProvider.overrideWithValue(journeyState),
      if (forecast != null) focusForecastProvider.overrideWithValue(forecast),
      if (shieldState != null)
        focusShieldStateProvider.overrideWithValue(shieldState),
      if (havenWindowController != null)
        havenWindowPlatformControllerProvider.overrideWith(
          (ref) => havenWindowController,
        ),
      if (havenWindowHoldService != null)
        havenWindowHoldServiceProvider.overrideWith(
          (ref) => havenWindowHoldService,
        ),
      if (havenWindowSuggestion != null)
        havenWindowSuggestionProvider.overrideWithValue(havenWindowSuggestion),
      if (havenWindowCurrentTime != null)
        havenWindowCurrentTimeProvider.overrideWithValue(
          havenWindowCurrentTime,
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF16FBA),
          secondary: Color(0xFFF58FC0),
          tertiary: Color(0xFFC58BFF),
          surface: Color(0xFF352260),
        ),
      ),
      navigatorObservers: [?observer],
      home: TimerScreen(
        openExternalUrl: openExternalUrl,
        writeClipboard: writeClipboard,
      ),
    ),
  );
}

Future<TimerService> _createTimer(WidgetTester tester) async {
  final timer = TimerService();
  await tester.pump();
  return timer;
}

class _TimerContextResponder implements CoachingResponder {
  int calls = 0;
  CoachingContext? context;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    this.context = context;
    return 'Use the live timer context.';
  }
}

class _RecordingHavenWindowBackend implements HavenWindowPlatformBackend {
  final operations = <String>[];

  @override
  Future<Map<String, Object?>> readAvailability() async {
    operations.add('read');
    return {'schemaVersion': 1, 'status': 'disconnected'};
  }

  @override
  Future<Map<String, Object?>> requestReadOnlyAccess() async {
    operations.add('request');
    return {'schemaVersion': 1, 'status': 'denied'};
  }
}

class _ReadyHavenWindowBackend implements HavenWindowPlatformBackend {
  _ReadyHavenWindowBackend({required this.rangeStart, required this.rangeEnd});

  final DateTime rangeStart;
  final DateTime rangeEnd;
  int readCalls = 0;

  @override
  Future<Map<String, Object?>> readAvailability() async {
    readCalls += 1;
    return {
      'schemaVersion': 1,
      'status': 'ready',
      'rangeStartUtc': rangeStart.toUtc().toIso8601String(),
      'rangeEndUtc': rangeEnd.toUtc().toIso8601String(),
      'busyBlocks': <Object?>[],
    };
  }

  @override
  Future<Map<String, Object?>> requestReadOnlyAccess() async {
    throw StateError('permission prompting is not expected');
  }
}

class _RecordingHavenWindowReminders implements HavenWindowReminderClient {
  int permissionRequests = 0;
  int cancellations = 0;
  final scheduledStarts = <DateTime>[];

  @override
  Future<bool> requestPermissions() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<bool> scheduleHavenWindowReminder(DateTime startsAt) async {
    scheduledStarts.add(startsAt);
    return true;
  }

  @override
  Future<void> cancelHavenWindowReminder() async {
    cancellations += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the complete initial focus dashboard', (tester) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    expect(find.text('FocusHaven'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('25 MINUTES'), findsOneWidget);
    expect(find.text('Begin focus'), findsOneWidget);
    expect(find.text('Open focus queue'), findsOneWidget);
    expect(find.text('Plan a goal'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-haven-ai-planner')), findsOneWidget);
    expect(find.text('Plan my next session'), findsOneWidget);
    expect(find.byType(LivingLanternCard), findsOneWidget);
    expect(find.text('LIVING LANTERN · READY'), findsOneWidget);
    expect(find.byType(FocusShieldCard), findsOneWidget);
    expect(find.text('FOCUS SHIELD · OFF'), findsOneWidget);
    expect(find.byType(HavenJourneyCard), findsOneWidget);
    expect(find.text('HAVEN JOURNEY · LANTERN'), findsOneWidget);
    expect(find.byType(HavenRhythmCard), findsOneWidget);
    expect(find.byType(FocusForecastCard), findsOneWidget);
    expect(find.text('FOCUS FORECAST · STILL LEARNING'), findsOneWidget);
    expect(find.byType(HavenWindowCard), findsOneWidget);
    expect(find.text('HAVEN WINDOW · OFF'), findsOneWidget);
    expect(find.byTooltip('Mindful pause'), findsOneWidget);
    expect(find.byTooltip('Reflection journal'), findsOneWidget);
    expect(find.byTooltip('Daily focus reminder'), findsOneWidget);
    expect(find.byTooltip('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Haven Window access remains explicit and leaves the timer alone',
    (tester) async {
      final timer = await _createTimer(tester);
      final backend = _RecordingHavenWindowBackend();
      final controller = HavenWindowPlatformController(backend: backend);
      expect(await controller.start(), isTrue);

      await tester.pumpWidget(_app(timer, havenWindowController: controller));
      await tester.pump();
      final secondsBefore = timer.secondsRemaining;
      final card = find.byKey(const ValueKey('haven-window-card'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
      await tester.pump();

      expect(find.text('HAVEN WINDOW · NOT CONNECTED'), findsOneWidget);
      expect(backend.operations, ['read']);
      await tester.tap(
        find.byKey(const ValueKey('haven-window-request-access')),
      );
      await tester.pumpAndSettle();

      expect(backend.operations, ['read', 'request']);
      expect(find.text('HAVEN WINDOW · ACCESS OFF'), findsOneWidget);
      expect(timer.secondsRemaining, secondsBefore);
      expect(timer.isRunning, isFalse);
      expect(timer.recentFocusEvents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Haven Window hold and release leave the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    final now = DateTime(2026, 8, 18, 8);
    final opening = HavenWindowSuggestion(
      kind: HavenWindowKind.opening,
      headline: 'A possible Haven Window is open',
      detail: 'Review this optional opening before deciding whether it fits.',
      evidence: 'One 25-minute opening fits the private forecast.',
      startsAt: now.add(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 1, minutes: 25)),
    );
    final controller = HavenWindowPlatformController(
      backend: _ReadyHavenWindowBackend(
        rangeStart: now,
        rangeEnd: now.add(const Duration(hours: 6)),
      ),
    );
    expect(await controller.start(), isTrue);
    final reminders = _RecordingHavenWindowReminders();
    final holdService = HavenWindowHoldService(
      notificationService: reminders,
      now: () => now,
    );
    await holdService.initialized;

    await tester.pumpWidget(
      _app(
        timer,
        havenWindowController: controller,
        havenWindowHoldService: holdService,
        havenWindowSuggestion: opening,
      ),
    );
    await tester.pump();
    final secondsBefore = timer.secondsRemaining;
    final card = find.byKey(const ValueKey('haven-window-card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(find.text('Hold this window'), findsOneWidget);
    expect(reminders.permissionRequests, 0);
    expect(reminders.scheduledStarts, isEmpty);
    await tester.tap(find.byKey(const ValueKey('haven-window-hold')));
    await tester.pumpAndSettle();

    expect(holdService.holdState.isHeld, isTrue);
    expect(reminders.permissionRequests, 1);
    expect(reminders.scheduledStarts, [opening.startsAt]);
    expect(find.text('HAVEN WINDOW · REMINDER HELD'), findsOneWidget);
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);

    await tester.tap(find.byKey(const ValueKey('haven-window-release-hold')));
    await tester.pumpAndSettle();

    expect(holdService.holdState.isHeld, isFalse);
    expect(reminders.cancellations, 1);
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an aged opening cannot reach reminder permission at hold tap', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    var now = DateTime(2026, 8, 18, 8);
    const forecast = FocusForecast(
      kind: FocusForecastKind.emergingWindow,
      headline: 'Morning may be one possible window',
      detail: 'A repeated completed-session pattern appears here.',
      evidence: 'Six private completed-session signals support this window.',
      signalCount: 6,
      window: FocusForecastWindow.morning,
    );
    final backend = _ReadyHavenWindowBackend(
      rangeStart: now,
      rangeEnd: now.add(const Duration(hours: 6)),
    );
    final controller = HavenWindowPlatformController(backend: backend);
    expect(await controller.start(), isTrue);
    final reminders = _RecordingHavenWindowReminders();
    final holdService = HavenWindowHoldService(
      notificationService: reminders,
      now: () => now,
    );
    await holdService.initialized;

    await tester.pumpWidget(
      _app(
        timer,
        forecast: forecast,
        havenWindowController: controller,
        havenWindowHoldService: holdService,
        havenWindowCurrentTime: () => now,
      ),
    );
    await tester.pump();
    final card = find.byKey(const ValueKey('haven-window-card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    final holdAction = find.byKey(const ValueKey('haven-window-hold'));
    expect(holdAction, findsOneWidget);
    expect(backend.readCalls, 1);

    now = now.add(const Duration(minutes: 16));
    await tester.tap(holdAction);
    await tester.pump();

    expect(holdService.holdState.isHeld, isFalse);
    expect(reminders.permissionRequests, 0);
    expect(reminders.scheduledStarts, isEmpty);
    expect(backend.readCalls, 1);
    expect(
      find.text(
        'This window is no longer current enough to hold. Refresh only if you want to check again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh your private availability'), findsOneWidget);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an arrived Haven Window starts focus only after its action', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    final now = DateTime(2026, 8, 18, 9, 5);
    final startsAtUtc = now.subtract(const Duration(minutes: 5)).toUtc();
    final endsAtUtc = now.add(const Duration(minutes: 20)).toUtc();
    SharedPreferences.setMockInitialValues({
      'havenWindowHoldStartsAtUtcMicros': startsAtUtc.microsecondsSinceEpoch,
      'havenWindowHoldEndsAtUtcMicros': endsAtUtc.microsecondsSinceEpoch,
    });
    final reminders = _RecordingHavenWindowReminders();
    final holdService = HavenWindowHoldService(
      notificationService: reminders,
      now: () => now,
    );
    await holdService.initialized;

    await tester.pumpWidget(_app(timer, havenWindowHoldService: holdService));
    await tester.pump();
    final card = find.byKey(const ValueKey('haven-window-card'));
    await tester.ensureVisible(card);
    await tester.pump();

    expect(holdService.holdState.hasArrived, isTrue);
    expect(find.text('HAVEN WINDOW · WINDOW ARRIVED'), findsOneWidget);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    final begin = find.byKey(const ValueKey('haven-window-begin-focus'));
    expect(begin, findsOneWidget);
    expect(timer.isRunning, isFalse);
    await tester.ensureVisible(begin);
    await tester.tap(begin);
    await tester.pump();

    expect(timer.isRunning, isTrue);
    expect(holdService.holdState.isHeld, isFalse);
    expect(reminders.cancellations, 1);
    expect(find.text('Focus began by your choice.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an arrived Haven Window cannot replace a paused attempt', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.start();
    timer.pause();
    final now = DateTime(2026, 8, 18, 9, 5);
    final startsAtUtc = now.subtract(const Duration(minutes: 5)).toUtc();
    final endsAtUtc = now.add(const Duration(minutes: 20)).toUtc();
    SharedPreferences.setMockInitialValues({
      'havenWindowHoldStartsAtUtcMicros': startsAtUtc.microsecondsSinceEpoch,
      'havenWindowHoldEndsAtUtcMicros': endsAtUtc.microsecondsSinceEpoch,
    });
    final holdService = HavenWindowHoldService(
      notificationService: _RecordingHavenWindowReminders(),
      now: () => now,
    );
    await holdService.initialized;

    await tester.pumpWidget(_app(timer, havenWindowHoldService: holdService));
    await tester.pump();
    final card = find.byKey(const ValueKey('haven-window-card'));
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toggle-haven-window')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('haven-window-begin-focus')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('haven-window-let-pass')), findsOneWidget);
    expect(timer.isRunning, isFalse);
    expect(timer.canStartHavenPlan, isFalse);
    expect(holdService.holdState.hasArrived, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showing an established Haven leaves the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    const journey = HavenJourneyState(
      place: HavenJourneyPlace.cabin,
      headline: 'Your Haven has a quiet cabin',
      detail: 'Pauses and resets never remove anything from it.',
      supportingSessionCount: 4,
    );

    await tester.pumpWidget(_app(timer, journeyState: journey));
    await tester.pump();
    final secondsBefore = timer.secondsRemaining;
    final card = find.byKey(const ValueKey('haven-journey-card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();

    expect(find.text('HAVEN JOURNEY · CABIN'), findsOneWidget);
    expect(find.text(journey.headline), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding Focus Shield status leaves the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    const shieldState = FocusShieldState(
      phase: FocusShieldPhase.protecting,
      headline: 'Your Haven is protected',
      detail: 'Only the selected distractions are restricted.',
      shouldProtect: true,
      nativeProtectionReported: true,
      availableActions: {FocusShieldAction.pauseProtection},
    );

    await tester.pumpWidget(_app(timer, shieldState: shieldState));
    await tester.pump();
    final secondsBefore = timer.secondsRemaining;
    final toggle = find.byKey(const ValueKey('toggle-focus-shield'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text('FOCUS SHIELD · PROTECTED'), findsOneWidget);
    expect(find.text(shieldState.detail), findsOneWidget);
    expect(find.text('Pause protection'), findsNothing);
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding Haven Rhythm evidence leaves the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    const insight = HavenRhythmInsight(
      kind: HavenRhythmKind.sustainablePace,
      headline: '25 minutes has felt sustainable',
      detail: 'Recent reflected sessions cluster near this pace.',
      evidence: '3 of 4 recent reflections said About right.',
      signalCount: 4,
      usesSessionReflections: true,
      suggestedFocusMinutes: 25,
    );

    await tester.pumpWidget(_app(timer, rhythmInsight: insight));
    await tester.pump();
    final secondsBefore = timer.secondsRemaining;
    final toggle = find.byKey(const ValueKey('toggle-haven-rhythm'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text(insight.evidence), findsOneWidget);
    expect(find.text('Possible pace · 25 min'), findsOneWidget);
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanding Focus Forecast evidence leaves the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    const forecast = FocusForecast(
      kind: FocusForecastKind.emergingWindow,
      headline: 'Completed focus often begins in the morning',
      detail: 'Treat this as a possible planning window, not a prediction.',
      evidence: '4 of 6 recent sessions began between 8 AM and noon.',
      signalCount: 6,
      window: FocusForecastWindow.morning,
    );

    await tester.pumpWidget(_app(timer, forecast: forecast));
    await tester.pump();
    final secondsBefore = timer.secondsRemaining;
    final toggle = find.byKey(const ValueKey('toggle-focus-forecast'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text('FOCUS FORECAST · POSSIBLE WINDOW'), findsOneWidget);
    expect(find.text(forecast.evidence), findsOneWidget);
    expect(timer.secondsRemaining, secondsBefore);
    expect(timer.isRunning, isFalse);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts an accepted Haven Plan with its queued task', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {
          'id': 'plan-task',
          'title': 'Prepare the project brief',
          'isComplete': false,
        },
      ]),
    });
    final timer = await _createTimer(tester);
    final queue = FocusQueueService();
    await queue.initialized;

    await tester.pumpWidget(
      _app(
        timer,
        havenQueue: const [
          FocusQueueItem(id: 'plan-task', title: 'Prepare the project brief'),
        ],
        focusQueueService: queue,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('open-haven-plan')));
    await tester.pumpAndSettle();

    expect(find.byType(HavenPlanSheet), findsOneWidget);
    expect(find.text('Prepare the project brief'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Low'));
    await tester.pump();
    final start = find.byKey(const ValueKey('haven-plan-start'));
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.byType(HavenPlanSheet), findsNothing);
    expect(timer.isRunning, isTrue);
    expect(timer.totalSessionSeconds, 10 * 60);
    expect(timer.focusTask, 'Prepare the project brief');
    expect(
      find.byKey(const ValueKey('haven-loop-linked-task')),
      findsOneWidget,
    );
    expect(
      find.text('Haven Plan started: 10 minutes of focus.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-haven-plan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a local Haven planner draft without changing the timer', (
    tester,
  ) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    final planner = find.byKey(const ValueKey('open-haven-ai-planner'));
    await tester.ensureVisible(planner);
    await tester.pumpAndSettle();
    await tester.tap(planner);
    await tester.pumpAndSettle();

    expect(find.byType(HavenPlannerSheet), findsOneWidget);
    expect(
      find.text('Local planner foundation • no remote AI'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('havenPlannerGoal')),
      'Prepare a careful launch checklist',
    );
    await tester.tap(find.byKey(const ValueKey('createHavenPlannerDraft')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('havenPlannerProposalContext')),
      findsOneWidget,
    );
    expect(find.text('Review each item'), findsOneWidget);
    expect(timer.isRunning, isFalse);
    expect(timer.secondsRemaining, 25 * 60);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing a Haven Plan leaves the timer untouched', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.setFocusTask('Keep the current intention');

    await tester.pumpWidget(_app(timer));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-haven-plan')));
    await tester.pumpAndSettle();

    final dismiss = find.text('Not right now');
    await tester.ensureVisible(dismiss);
    await tester.tap(dismiss);
    await tester.pumpAndSettle();

    expect(find.byType(HavenPlanSheet), findsNothing);
    expect(timer.isRunning, isFalse);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.focusTask, 'Keep the current intention');
    expect(find.byKey(const ValueKey('open-haven-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a paused focus attempt cannot be replaced by a Haven Plan', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.start();
    timer.pause();

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    expect(timer.canStartHavenPlan, isFalse);
    expect(find.byKey(const ValueKey('open-haven-plan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Smart Reset starts a smaller one-time recovery session', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.setFocusTask('Keep the recovery task');
    timer.start();

    await tester.pumpWidget(_app(timer));
    await tester.pump();
    final reset = find.byTooltip('Reset timer');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(timer.isRunning, isFalse);
    expect(find.byType(SmartResetSheet), findsOneWidget);
    expect(find.text('This session isn’t a failure'), findsOneWidget);

    final restart = find.byKey(const ValueKey('smart-reset-restart'));
    await tester.ensureVisible(restart);
    await tester.pumpAndSettle();
    await tester.tap(restart);
    await tester.pumpAndSettle();

    expect(find.byType(SmartResetSheet), findsNothing);
    expect(timer.isRunning, isTrue);
    expect(timer.totalSessionSeconds, 10 * 60);
    expect(timer.focusTask, 'Keep the recovery task');
    expect(timer.recentFocusEvents.single.outcome, FocusEventOutcome.reset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Smart Reset preserves one exact linked queue item end to end', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {
          'id': 'linked-recovery-task',
          'title': 'Prepare the recovery brief',
          'isComplete': false,
        },
      ]),
      HavenLoopService.storageKey: 'linked-recovery-task',
    });
    final timer = await _createTimer(tester);
    final queue = FocusQueueService();
    await queue.initialized;
    timer.setFocusTask('Prepare the recovery brief');
    timer.start();

    await tester.pumpWidget(
      _app(timer, havenQueue: queue.items, focusQueueService: queue),
    );
    await tester.pump();

    final reset = find.byTooltip('Reset timer');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(find.byType(SmartResetSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('smart-reset-linked-task-boundary')),
      findsOneWidget,
    );
    expect(
      find.textContaining('No task text is copied into Smart Reset'),
      findsOneWidget,
    );

    final restart = find.byKey(const ValueKey('smart-reset-restart'));
    await tester.ensureVisible(restart);
    await tester.pumpAndSettle();
    await tester.tap(restart);
    await tester.pumpAndSettle();

    expect(find.byType(SmartResetSheet), findsNothing);
    expect(timer.isRunning, isTrue);
    expect(timer.focusTask, 'Prepare the recovery brief');
    expect(queue.items.single.id, 'linked-recovery-task');
    expect(queue.completedItems, isEmpty);
    expect(
      find.byKey(const ValueKey('haven-loop-linked-task')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeping a running session resumes it after Smart Reset', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.start();

    await tester.pumpWidget(_app(timer));
    await tester.pump();
    final reset = find.byTooltip('Reset timer');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(timer.isRunning, isFalse);
    final keep = find.byKey(const ValueKey('smart-reset-keep'));
    await tester.ensureVisible(keep);
    await tester.pumpAndSettle();
    await tester.tap(keep);
    await tester.pumpAndSettle();

    expect(find.byType(SmartResetSheet), findsNothing);
    expect(timer.isRunning, isTrue);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.recentFocusEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain reset remains available from the recovery sheet', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.start();

    await tester.pumpWidget(_app(timer));
    await tester.pump();
    final reset = find.byTooltip('Reset timer');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    final plainReset = find.byKey(const ValueKey('smart-reset-plain-reset'));
    await tester.ensureVisible(plainReset);
    await tester.pumpAndSettle();
    await tester.tap(plainReset);
    await tester.pumpAndSettle();

    expect(find.byType(SmartResetSheet), findsNothing);
    expect(timer.isRunning, isFalse);
    expect(timer.totalSessionSeconds, 25 * 60);
    expect(timer.recentFocusEvents.single.outcome, FocusEventOutcome.reset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping timer overlay launches', (tester) async {
    final timer = await _createTimer(tester);
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(_app(timer, observer: observer));
    await tester.pump();

    final initialPushCount = observer.pushCount;
    final mindfulPause = tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.self_improvement_outlined),
        )
        .onPressed!;
    mindfulPause();
    mindfulPause();
    await tester.pumpAndSettle();

    expect(observer.pushCount - initialPushCount, 1);
    expect(find.byType(GuidedBreathingSheet), findsOneWidget);

    Navigator.of(tester.element(find.byType(GuidedBreathingSheet))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(GuidedBreathingSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens one coach with the current timer context', (tester) async {
    final timer = await _createTimer(tester);
    timer.setFocusTask('Prepare the product demo');
    timer.setDailyGoalMinutes(90);
    final responder = _TimerContextResponder();
    final coach = CoachingService(responder: responder);
    await coach.initialized;
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(
      _app(timer, observer: observer, coachingService: coach),
    );
    await tester.pump();

    final initialPushCount = observer.pushCount;
    final coachButton = tester.widget<FloatingActionButton>(
      find.widgetWithText(FloatingActionButton, 'Coach'),
    );
    coachButton.onPressed!.call();
    coachButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(observer.pushCount - initialPushCount, 1);
    expect(find.byType(CoachingSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'What should I do next?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(responder.calls, 1);
    expect(responder.context?.focusTask, 'Prepare the product demo');
    expect(responder.context?.dailyGoalMinutes, 90);
    expect(responder.context?.isTimerRunning, isFalse);
    expect(find.text('Use the live timer context.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account settings can open and return from nested sheets', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(_app(timer, observer: observer));
    await tester.pump();
    await tester.tap(find.byTooltip('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Your FocusHaven account'), findsOneWidget);
    final appearanceAction = find.text('Appearance');
    await tester.ensureVisible(appearanceAction);
    await tester.pumpAndSettle();
    final accountPushCount = observer.pushCount;

    await tester.tap(appearanceAction);
    await tester.pumpAndSettle();

    expect(observer.pushCount - accountPushCount, 1);
    expect(find.byTooltip('Back to account settings'), findsOneWidget);
    expect(
      find.text('Choose the atmosphere that feels best for your focus.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back to account settings'));
    await tester.pumpAndSettle();

    expect(find.text('Your FocusHaven account'), findsOneWidget);
    expect(find.byTooltip('Back to account settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refuses to claim local deletion when coaching remains', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    timer.setFocusTask('Keep this focus task');
    final firstCoach = CoachingService(responder: _TimerContextResponder());
    await firstCoach.initialized;
    expect(
      await firstCoach.send('Keep this conversation.', const CoachingContext()),
      isTrue,
    );
    firstCoach.dispose();
    final coach = CoachingService(removePreference: (_, _) async => false);
    await coach.initialized;

    await tester.pumpWidget(_app(timer, coachingService: coach));
    await tester.pump();
    await tester.tap(find.byTooltip('Sign in'));
    await tester.pumpAndSettle();

    final deleteAction = find.widgetWithText(TextButton, 'Delete local data');
    await tester.ensureVisible(deleteAction);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Delete local data?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('confirmation-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'That account action could not be completed. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your FocusHaven account'), findsOneWidget);
    expect(timer.focusTask, 'Keep this focus task');
    expect(coach.messages, hasLength(2));
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely cleared. '
      'Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports a refused privacy policy launch', (tester) async {
    final timer = await _createTimer(tester);
    Uri? attemptedUri;

    await tester.pumpWidget(
      _app(
        timer,
        openExternalUrl: (uri) async {
          attemptedUri = uri;
          return false;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Sign in'));
    await tester.pumpAndSettle();

    final privacyAction = find.widgetWithText(TextButton, 'Privacy Policy');
    await tester.ensureVisible(privacyAction);
    await tester.pumpAndSettle();
    await tester.tap(privacyAction);
    await tester.pumpAndSettle();

    expect(
      attemptedUri,
      Uri.parse('https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html'),
    );
    expect(
      find.text('Unable to open the privacy policy right now.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'That account action could not be completed. Please try again.',
      ),
      findsNothing,
    );
    expect(tester.widget<TextButton>(privacyAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains overlapping privacy policy launch failures', (
    tester,
  ) async {
    final timer = await _createTimer(tester);
    final pendingLaunch = Completer<bool>();
    var launchCalls = 0;

    await tester.pumpWidget(
      _app(
        timer,
        openExternalUrl: (uri) {
          launchCalls += 1;
          return pendingLaunch.future;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Sign in'));
    await tester.pumpAndSettle();

    final privacyAction = find.widgetWithText(TextButton, 'Privacy Policy');
    await tester.ensureVisible(privacyAction);
    await tester.pumpAndSettle();
    final initialButton = tester.widget<TextButton>(privacyAction);
    initialButton.onPressed!.call();
    initialButton.onPressed!.call();
    await tester.pump();

    expect(launchCalls, 1);
    expect(tester.widget<TextButton>(privacyAction).onPressed, isNull);

    pendingLaunch.completeError(StateError('launcher unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to open the privacy policy right now.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'That account action could not be completed. Please try again.',
      ),
      findsNothing,
    );
    expect(tester.widget<TextButton>(privacyAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains focus summary clipboard failures', (tester) async {
    SharedPreferences.setMockInitialValues({
      'completedFocusSessions': 1,
      'focusHistory': jsonEncode([
        {
          'completedAt': DateTime.utc(2026, 8, 10).toIso8601String(),
          'durationSeconds': 60,
          'focusTask': 'Clipboard integration session',
        },
      ]),
    });
    final timer = TimerService();
    await timer.initialized;
    String? attemptedSummary;

    await tester.pumpWidget(
      _app(
        timer,
        writeClipboard: (text) async {
          attemptedSummary = text;
          throw StateError('clipboard unavailable');
        },
      ),
    );
    await tester.pump();

    final viewAll = find.text('View all');
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    final copyAction = find.widgetWithText(TextButton, 'Copy full summary');
    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    expect(attemptedSummary, contains('Clipboard integration session'));
    expect(
      find.text('Focus summary could not be copied right now.'),
      findsOneWidget,
    );
    expect(find.textContaining('Focus summary copied.'), findsNothing);
    expect(tester.widget<TextButton>(copyAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session chips update the timer and primary action', (
    tester,
  ) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Short break'));
    await tester.pump();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(find.text('SHORT BREAK'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Begin short break'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Long break'));
    await tester.pump();

    expect(timer.sessionType, SessionType.longBreak);
    expect(find.text('LONG BREAK'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Begin long break'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reselecting the active session preserves a running timer', (
    tester,
  ) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    final beginButton = find.widgetWithText(FilledButton, 'Begin focus');
    await tester.ensureVisible(beginButton);
    await tester.tap(beginButton);
    await tester.pump();
    final remainingBeforeReselection = timer.secondsRemaining;

    final focusChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Focus'),
    );
    focusChip.onSelected!.call(false);
    await tester.pump();

    expect(timer.sessionType, SessionType.focus);
    expect(timer.isRunning, isTrue);
    expect(timer.secondsRemaining, remainingBeforeReselection);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('begin and pause controls update the running state', (
    tester,
  ) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    final beginButton = find.widgetWithText(FilledButton, 'Begin focus');
    await tester.ensureVisible(beginButton);
    await tester.tap(beginButton);
    await tester.pump();

    expect(timer.isRunning, isTrue);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pump();

    expect(timer.isRunning, isFalse);
    expect(find.widgetWithText(FilledButton, 'Begin focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping completed session transitions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1,
      'secondsRemaining': 1,
      'totalSessionSeconds': 1,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .subtract(const Duration(seconds: 2))
          .millisecondsSinceEpoch,
    });
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    expect(timer.isComplete, isTrue);
    final takeBreak = find.widgetWithText(FilledButton, 'Take a break');
    expect(takeBreak, findsOneWidget);

    final transition = tester.widget<FilledButton>(takeBreak).onPressed!;
    transition();
    transition();
    await tester.pump();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.isComplete, isFalse);
    expect(find.text('SHORT BREAK'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Begin short break'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('records an optional private reflection before the break', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 1,
      'secondsRemaining': 1,
      'totalSessionSeconds': 1,
      'sessionType': SessionType.focus.index,
      'timerEndsAt': DateTime.now()
          .subtract(const Duration(seconds: 2))
          .millisecondsSinceEpoch,
    });
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(_app(timer));
    await tester.pump();

    expect(find.byType(FocusSessionReflectionCard), findsOneWidget);
    final aboutRight = find.byKey(
      const ValueKey('focus-session-fit-aboutRight'),
    );
    await tester.ensureVisible(aboutRight);
    await tester.pumpAndSettle();
    await tester.tap(aboutRight);
    await tester.pump();

    expect(timer.completedFocusSessionFit, FocusSessionFit.aboutRight);
    expect(
      timer.recentFocusEvents.single.sessionFit,
      FocusSessionFit.aboutRight,
    );
    expect(find.textContaining('Saved privately'), findsOneWidget);
    expect(find.byType(HavenRhythmReflectionConnectionCard), findsOneWidget);
    expect(find.byType(FocusForecastReflectionConnectionCard), findsOneWidget);
    expect(
      find.text('One reflection is a beginning, not a pattern'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Nothing changed automatically. Your next session remains your choice.',
      ),
      findsOneWidget,
    );
    expect(timer.totalSessionSeconds, 1);

    final takeBreak = find.widgetWithText(FilledButton, 'Take a break');
    await tester.ensureVisible(takeBreak);
    await tester.pumpAndSettle();
    await tester.tap(takeBreak);
    await tester.pump();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(find.byType(FocusSessionReflectionCard), findsNothing);
    expect(find.byType(HavenRhythmReflectionConnectionCard), findsNothing);
    expect(find.byType(FocusForecastReflectionConnectionCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders restored dashboard dates in the device local time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final completedAt = DateTime.utc(2000, 1, 2, 2, 15);
    final localCompletedAt = completedAt.toLocal();
    SharedPreferences.setMockInitialValues({
      'completedFocusSessions': 1,
      'focusHistory': jsonEncode([
        {
          'completedAt': completedAt.toIso8601String(),
          'durationSeconds': 60,
          'focusTask': 'Restored UTC dashboard session',
        },
      ]),
    });
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(_app(timer));
    await tester.pump();
    await tester.ensureVisible(find.text('Restored UTC dashboard session'));
    await tester.pumpAndSettle();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final expectedDate =
        '${months[localCompletedAt.month - 1]} ${localCompletedAt.day}';

    expect(find.text('Restored UTC dashboard session'), findsOneWidget);
    expect(find.text(expectedDate), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'requires an explicit linked-task outcome before leaving completed focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'completedFocusSessions': 1,
        'focusQueue': jsonEncode([
          {
            'id': 'linked-task',
            'title': 'Prepare the launch brief',
            'isComplete': false,
          },
        ]),
        'focusTask': 'Prepare the launch brief',
        'secondsRemaining': 0,
        'totalSessionSeconds': 1500,
        'sessionType': SessionType.focus.index,
        'isComplete': true,
        'focusEvents': jsonEncode([
          {
            'schemaVersion': 1,
            'startedAt': DateTime.utc(2026, 8, 31, 12).toIso8601String(),
            'endedAt': DateTime.utc(2026, 8, 31, 12, 25).toIso8601String(),
            'plannedDurationSeconds': 1500,
            'focusedDurationSeconds': 1500,
            'pauseCount': 0,
            'didResume': false,
            'outcome': 'completed',
          },
        ]),
        HavenLoopService.storageKey: 'linked-task',
      });
      final timer = TimerService();
      final queue = FocusQueueService();
      await Future.wait([timer.initialized, queue.initialized]);

      await tester.pumpWidget(
        _app(timer, havenQueue: queue.items, focusQueueService: queue),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('haven-loop-completion-card')),
        findsOneWidget,
      );
      expect(find.byType(FocusSessionReflectionCard), findsNothing);
      expect(
        find.byKey(const ValueKey('haven-loop-resolution-required')),
        findsOneWidget,
      );
      final takeBreak = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Take a break'),
      );
      expect(takeBreak.onPressed, isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('haven-loop-keep-for-later')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('haven-loop-keep-for-later')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('haven-loop-completion-card')),
        findsNothing,
      );
      expect(find.byType(FocusSessionReflectionCard), findsOneWidget);
      expect(find.byType(HavenJourneyCompletionConnectionCard), findsOneWidget);
      expect(queue.items.single.id, 'linked-task');
      expect(queue.completedItems, isEmpty);
      expect(timer.focusTask, isEmpty);
      expect(timer.completedFocusSessionFit, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Take a break'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('can continue after a linked task without saving a reflection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'completedFocusSessions': 1,
      'focusQueue': jsonEncode([
        {
          'id': 'linked-task',
          'title': 'Keep the reflection optional',
          'isComplete': false,
        },
      ]),
      'focusTask': 'Keep the reflection optional',
      'secondsRemaining': 0,
      'totalSessionSeconds': 1500,
      'sessionType': SessionType.focus.index,
      'isComplete': true,
      'focusEvents': jsonEncode([
        {
          'schemaVersion': 1,
          'startedAt': DateTime.utc(2026, 8, 31, 13).toIso8601String(),
          'endedAt': DateTime.utc(2026, 8, 31, 13, 25).toIso8601String(),
          'plannedDurationSeconds': 1500,
          'focusedDurationSeconds': 1500,
          'pauseCount': 0,
          'didResume': false,
          'outcome': 'completed',
        },
      ]),
      HavenLoopService.storageKey: 'linked-task',
    });
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);

    await tester.pumpWidget(
      _app(timer, havenQueue: queue.items, focusQueueService: queue),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('haven-loop-mark-complete')),
    );
    await tester.tap(find.byKey(const ValueKey('haven-loop-mark-complete')));
    await tester.pumpAndSettle();

    expect(queue.items, isEmpty);
    expect(queue.completedItems.single.id, 'linked-task');
    expect(find.byType(FocusSessionReflectionCard), findsOneWidget);
    expect(find.byType(HavenJourneyCompletionConnectionCard), findsOneWidget);
    expect(timer.completedFocusSessionFit, isNull);

    final takeBreak = find.widgetWithText(FilledButton, 'Take a break');
    await tester.ensureVisible(takeBreak);
    await tester.tap(takeBreak);
    await tester.pumpAndSettle();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(timer.recentFocusEvents.single.sessionFit, isNull);
    expect(find.byType(FocusSessionReflectionCard), findsNothing);
    expect(find.byType(HavenJourneyCompletionConnectionCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
