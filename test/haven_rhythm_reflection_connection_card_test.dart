import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/widgets/haven_rhythm_reflection_connection_card.dart';

void main() {
  const completion = (
    startedAtMicrosecondsSinceEpoch: 1,
    endedAtMicrosecondsSinceEpoch: 2,
    plannedDurationSeconds: 1500,
  );

  Widget app(HavenRhythmReflectionConnection connection) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF16FBA),
          tertiary: Color(0xFFC58BFF),
        ),
      ),
      home: Scaffold(
        body: HavenRhythmReflectionConnectionCard(connection: connection),
      ),
    );
  }

  testWidgets('explains one saved reflection without changing the timer', (
    tester,
  ) async {
    const insight = HavenRhythmInsight(
      kind: HavenRhythmKind.learning,
      headline: 'Your Haven Rhythm is still forming',
      detail: 'More evidence is needed.',
      evidence: 'One private reflection is available.',
      signalCount: 1,
      usesSessionReflections: true,
    );
    const connection = HavenRhythmReflectionConnection(
      kind: HavenRhythmReflectionConnectionKind.learning,
      completion: completion,
      selectedFit: FocusSessionFit.aboutRight,
      insight: insight,
      headline: 'One reflection is a beginning, not a pattern',
      detail: 'Haven Rhythm will wait for repeated private signals.',
    );

    await tester.pumpWidget(app(connection));

    expect(
      find.byKey(const ValueKey('haven-rhythm-reflection-connection')),
      findsOneWidget,
    );
    expect(find.text('About right'), findsOneWidget);
    expect(find.text(connection.headline), findsOneWidget);
    expect(find.text(connection.detail), findsOneWidget);
    expect(
      find.textContaining('Nothing changed automatically'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces the complete advisory boundary as one container', (
    tester,
  ) async {
    const insight = HavenRhythmInsight(
      kind: HavenRhythmKind.gentlerPace,
      headline: 'Less may fit better right now',
      detail: 'Repeated reflections support this observation.',
      evidence: '2 of 2 said Too much.',
      signalCount: 2,
      usesSessionReflections: true,
      suggestedFocusMinutes: 15,
    );
    const connection = HavenRhythmReflectionConnection(
      kind: HavenRhythmReflectionConnectionKind.reflectionPattern,
      completion: completion,
      selectedFit: FocusSessionFit.tooMuch,
      insight: insight,
      headline: 'Your private Rhythm has new evidence',
      detail: 'This reflection contributed to the current local observation.',
    );

    await tester.pumpWidget(app(connection));

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('haven-rhythm-reflection-connection')),
    );
    expect(semantics.label, contains(connection.headline));
    expect(semantics.label, contains(connection.detail));
    expect(semantics.label, contains('Nothing changed automatically'));
  });
}
