import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/smart_reset_plan.dart';
import 'package:focushaven/widgets/smart_reset_sheet.dart';

Widget _app(SmartResetPlan plan) => MaterialApp(
  theme: ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF16FBA),
      surface: Color(0xFF352260),
    ),
  ),
  home: Scaffold(body: SmartResetSheet(plan: plan)),
);

void main() {
  testWidgets('presents recovery without framing the attempt as failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SmartResetPlan(
          restartDurationSeconds: 10 * 60,
          originalDurationSeconds: 25 * 60,
          focusedDurationSeconds: 7 * 60,
          basis: SmartResetBasis.meaningfulProgress,
          explanation:
              'The focus you already gave still counts. This offers a smaller finish line.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('This session isn’t a failure'), findsOneWidget);
    expect(find.text('7 min of focus still counts.'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.textContaining('smaller finish line'), findsOneWidget);
    expect(find.textContaining('time-only focus signals'), findsOneWidget);
    expect(find.text('Restart with 10 min'), findsOneWidget);
    expect(find.text('Reset without restarting'), findsOneWidget);
    expect(find.text('Keep this session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a just-started attempt receives neutral acknowledgement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SmartResetPlan(
          restartDurationSeconds: 5 * 60,
          originalDurationSeconds: 10 * 60,
          focusedDurationSeconds: 0,
          basis: SmartResetBasis.gentleReturn,
          explanation:
              'A shorter restart can make the next step feel more reachable.',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Pausing to choose a better fit still counts.'),
      findsOneWidget,
    );
    expect(find.text('Restart with 5 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
