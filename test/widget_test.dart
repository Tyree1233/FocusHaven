import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/main.dart';
import 'package:focushaven/screens/onboarding_screen.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the FocusHaven welcome screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FocusHavenApp());

    expect(find.text('Welcome to FocusHaven'), findsOneWidget);
    expect(
      find.text('A calm place to focus, recharge, and stay mindful.'),
      findsOneWidget,
    );
    expect(find.text('Begin focus'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('begin focus saves onboarding and replaces the welcome route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (_) => const OnboardingScreen(),
          '/timer': (_) =>
              const Scaffold(body: Center(child: Text('Timer destination'))),
        },
      ),
    );

    await tester.tap(find.text('Begin focus'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('hasCompletedOnboarding'), isTrue);
    expect(find.text('Welcome to FocusHaven'), findsNothing);
    expect(find.text('Timer destination'), findsOneWidget);
  });

  testWidgets('uses the pre-initialized timer supplied at app startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 90,
      'totalSessionSeconds': 90,
      'secondsRemaining': 90,
    });
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(
      FocusHavenApp(timerService: timer, showOnboarding: false),
    );
    await tester.pump();

    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Begin focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
