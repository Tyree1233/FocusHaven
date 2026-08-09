import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/timer_screen.dart';
import 'package:focushaven/services/timer_service.dart';

Widget _app(TimerService timer) {
  return ProviderScope(
    overrides: [
      timerServiceProvider.overrideWith((ref) => timer),
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
      home: const TimerScreen(),
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
