import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/timer_screen.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';

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
  Future<bool> Function(Uri uri)? openExternalUrl,
  Future<void> Function(String text)? writeClipboard,
}) {
  return ProviderScope(
    overrides: [
      timerServiceProvider.overrideWith((ref) => timer),
      authStateProvider.overrideWithValue((
        isSignedIn: false,
        displayName: 'Guest',
        signInError: null,
      )),
      authIsSignedInProvider.overrideWithValue(false),
      focusQueueRemainingCountProvider.overrideWithValue(0),
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
    expect(find.byTooltip('Mindful pause'), findsOneWidget);
    expect(find.byTooltip('Reflection journal'), findsOneWidget);
    expect(find.byTooltip('Daily focus reminder'), findsOneWidget);
    expect(find.byTooltip('Sign in'), findsOneWidget);
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
