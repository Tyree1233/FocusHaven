import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/widgets/haven_rhythm_card.dart';

Widget _app(HavenRhythmInsight insight) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF16FBA),
        secondary: Color(0xFFC58BFF),
      ),
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: HavenRhythmCard(insight: insight),
      ),
    ),
  );
}

void main() {
  const learning = HavenRhythmInsight(
    kind: HavenRhythmKind.learning,
    headline: 'Your Haven Rhythm is still forming',
    detail: 'Complete and optionally reflect on a few sessions.',
    evidence: 'No private focus-attempt signals are available yet.',
    signalCount: 0,
    usesSessionReflections: false,
  );

  testWidgets('keeps a learning insight compact until explicitly expanded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(learning));

    expect(find.byKey(const ValueKey('haven-rhythm-card')), findsOneWidget);
    expect(find.textContaining('STILL LEARNING'), findsOneWidget);
    expect(find.text(learning.headline), findsOneWidget);
    expect(find.text(learning.detail), findsNothing);
    expect(find.text(learning.evidence), findsNothing);
    expect(find.textContaining('No productivity score'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-haven-rhythm')));
    await tester.pump();

    expect(find.byKey(const ValueKey('haven-rhythm-details')), findsOneWidget);
    expect(find.text(learning.detail), findsOneWidget);
    expect(find.text(learning.evidence), findsOneWidget);
    expect(find.textContaining('No productivity score'), findsOneWidget);
    expect(find.textContaining('Possible pace'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can collapse expanded evidence without changing the insight', (
    tester,
  ) async {
    await tester.pumpWidget(_app(learning));
    final toggle = find.byKey(const ValueKey('toggle-haven-rhythm'));

    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text(learning.headline), findsOneWidget);
    expect(find.byKey(const ValueKey('haven-rhythm-details')), findsNothing);
    expect(find.text(learning.evidence), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows evidence and a possible pace for an established pattern', (
    tester,
  ) async {
    const insight = HavenRhythmInsight(
      kind: HavenRhythmKind.sustainablePace,
      headline: '25 minutes has felt sustainable',
      detail: 'Recent sessions marked About right cluster near this pace.',
      evidence: '3 of 4 recent reflections said About right.',
      signalCount: 4,
      usesSessionReflections: true,
      suggestedFocusMinutes: 25,
    );
    await tester.pumpWidget(_app(insight));

    expect(find.textContaining('SUSTAINABLE PACE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-haven-rhythm')));
    await tester.pump();

    expect(find.text(insight.detail), findsOneWidget);
    expect(find.text(insight.evidence), findsOneWidget);
    expect(find.text('Possible pace · 25 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
