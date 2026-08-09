import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';

Widget _app() {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: const Scaffold(body: GuidedBreathingSheet()),
  );
}

void main() {
  testWidgets('renders the initial breathing instructions', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Mindful pause'), findsOneWidget);
    expect(
      find.text('Follow a calming 4–4–6 breath for one minute.'),
      findsOneWidget,
    );
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('0:60'), findsOneWidget);
    expect(find.text('4 seconds'), findsOneWidget);
    expect(find.text('Begin breathing'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advances phases and remains still while paused', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Begin breathing'));
    await tester.pump();

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Hold gently'), findsOneWidget);
    expect(find.text('0:56'), findsOneWidget);
    expect(find.text('4 seconds'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Hold gently'), findsOneWidget);
    expect(find.text('0:56'), findsOneWidget);
    expect(find.text('Begin breathing'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);

    await tester.tap(find.text('Begin breathing'));
    await tester.pump();

    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('0:60'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes the minute and can begin again', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Begin breathing'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));

    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('You made space for yourself.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('0:60'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
