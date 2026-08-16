import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/timer_screen.dart';
import 'package:focushaven/services/coaching_service.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/coaching_sheet.dart';
import 'package:focushaven/widgets/focus_session_reflection_card.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';
import 'package:focushaven/widgets/haven_plan_sheet.dart';
import 'package:focushaven/widgets/haven_rhythm_card.dart';
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
  HavenRhythmInsight? rhythmInsight,
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
      if (rhythmInsight != null)
        havenRhythmInsightProvider.overrideWithValue(rhythmInsight),
    ],
    child: MaterialApp(
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
    expect(find.text('Plan my next session'), findsOneWidget);
    expect(find.byType(LivingLanternCard), findsOneWidget);
    expect(find.text('LIVING LANTERN · READY'), findsOneWidget);
    expect(find.byType(HavenRhythmCard), findsOneWidget);
    expect(find.byTooltip('Mindful pause'), findsOneWidget);
    expect(find.byTooltip('Reflection journal'), findsOneWidget);
    expect(find.byTooltip('Daily focus reminder'), findsOneWidget);
    expect(find.byTooltip('Sign in'), findsOneWidget);
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

  testWidgets('starts an accepted Haven Plan with its queued task', (
    tester,
  ) async {
    final timer = await _createTimer(tester);

    await tester.pumpWidget(
      _app(
        timer,
        havenQueue: const [
          FocusQueueItem(id: 'plan-task', title: 'Prepare the project brief'),
        ],
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
      find.text('Haven Plan started: 10 minutes of focus.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-haven-plan')), findsNothing);
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

    final takeBreak = find.widgetWithText(FilledButton, 'Take a break');
    await tester.ensureVisible(takeBreak);
    await tester.pumpAndSettle();
    await tester.tap(takeBreak);
    await tester.pump();

    expect(timer.sessionType, SessionType.shortBreak);
    expect(find.byType(FocusSessionReflectionCard), findsNothing);
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
}
