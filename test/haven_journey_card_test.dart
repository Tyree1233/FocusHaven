import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';

import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/widgets/haven_journey_card.dart';

Widget _app(
  HavenJourneyState state, {
  double textScale = 1,
  double cardWidth = 380,
}) {
  return MaterialApp(
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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: cardWidth,
            child: HavenJourneyCard(state: state),
          ),
        ),
      ),
    ),
  );
}

HavenJourneyState _state(HavenJourneyPlace place) => HavenJourneyState(
  place: place,
  headline: 'A whole ${place.name} is here',
  detail: 'This ${place.name} stays complete without pressure or decay.',
  supportingSessionCount: place.index,
);

void main() {
  const placeLabels = <HavenJourneyPlace, String>{
    HavenJourneyPlace.lantern: 'LANTERN',
    HavenJourneyPlace.campsite: 'CAMPSITE',
    HavenJourneyPlace.cabin: 'CABIN',
    HavenJourneyPlace.garden: 'GARDEN',
    HavenJourneyPlace.sanctuary: 'SANCTUARY',
  };

  testWidgets('renders every place as one complete responsive scene', (
    tester,
  ) async {
    for (final entry in placeLabels.entries) {
      final state = _state(entry.key);
      await tester.pumpWidget(_app(state));

      expect(find.byKey(const ValueKey('haven-journey-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('haven-journey-illustration')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('haven-journey-illustration')),
        ),
        const Size(118, 92),
      );
      expect(find.text('HAVEN JOURNEY · ${entry.value}'), findsOneWidget);
      expect(find.text(state.headline), findsOneWidget);
      expect(find.text(state.detail), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('exposes one complete non-scoring screen-reader description', (
    tester,
  ) async {
    const state = HavenJourneyState(
      place: HavenJourneyPlace.garden,
      headline: 'A gentle garden is growing',
      detail: 'The garden keeps its shape without demanding a streak.',
      supportingSessionCount: 10,
    );
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(_app(state));

      expect(
        find.bySemanticsLabel(
          'Haven Journey. Garden. A gentle garden is growing. '
          'The garden keeps its shape without demanding a streak. '
          'Built privately from completed focus sessions. No score or public ranking.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('has no milestone countdown timer or navigation controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_state(HavenJourneyPlace.cabin)));

    final card = find.byKey(const ValueKey('haven-journey-card'));
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(find.textContaining('next', findRichText: true), findsNothing);
    expect(find.textContaining('until', findRichText: true), findsNothing);
    expect(find.textContaining('locked', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports a narrow surface and large accessible text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_state(HavenJourneyPlace.sanctuary), textScale: 2, cardWidth: 260),
    );

    expect(find.text('HAVEN JOURNEY · SANCTUARY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('haven-journey-illustration')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
