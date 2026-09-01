import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';

import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/widgets/haven_journey_completion_connection_card.dart';

const completion = (
  startedAtMicrosecondsSinceEpoch: 1,
  endedAtMicrosecondsSinceEpoch: 2,
  plannedDurationSeconds: 1500,
);

HavenJourneyCompletionConnection connection({required bool changed}) =>
    HavenJourneyCompletionConnection(
      kind: changed
          ? HavenJourneyCompletionConnectionKind.placeChanged
          : HavenJourneyCompletionConnectionKind.placeHeld,
      completion: completion,
      previousPlace: changed
          ? HavenJourneyPlace.campsite
          : HavenJourneyPlace.cabin,
      currentPlace: HavenJourneyPlace.cabin,
      headline: changed
          ? 'This completed Focus session opened a new Haven place'
          : 'This completed Focus session belongs in your Haven',
      detail: changed
          ? 'Your private Journey now rests at the quiet cabin'
          : 'Your private Journey remains at the quiet cabin',
    );

Widget app(HavenJourneyCompletionConnection value) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: HavenJourneyCompletionConnectionCard(connection: value),
    ),
  ),
);

void main() {
  testWidgets('explains an existing place transition without a control', (
    tester,
  ) async {
    await tester.pumpWidget(app(connection(changed: true)));

    expect(
      find.byKey(const ValueKey('haven-journey-completion-connection')),
      findsOneWidget,
    );
    expect(find.text('HAVEN JOURNEY · NEW PLACE'), findsOneWidget);
    expect(find.textContaining('opened a new Haven place'), findsOneWidget);
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps ordinary completions equal and non-scoring', (
    tester,
  ) async {
    await tester.pumpWidget(app(connection(changed: false)));

    expect(find.text('HAVEN JOURNEY · COMPLETION KEPT'), findsOneWidget);
    expect(
      find.textContaining('free of scores or streak pressure'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces one complete privacy boundary', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(app(connection(changed: true)));

      expect(
        find.bySemanticsLabel(
          'Haven Journey completion update. This completed Focus session opened a new Haven place. Your private Journey now rests at the quiet cabin. This advisory changed nothing automatically.',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}
