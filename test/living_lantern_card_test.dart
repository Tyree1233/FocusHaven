import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/living_lantern_state.dart';
import 'package:focushaven/widgets/living_lantern_card.dart';

Widget _app(
  LivingLanternState state, {
  double textScale = 1,
  double cardWidth = 360,
}) {
  return MaterialApp(
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
            child: LivingLanternCard(state: state),
          ),
        ),
      ),
    ),
  );
}

LivingLanternState _state(LivingLanternPhase phase) => LivingLanternState(
  phase: phase,
  headline: 'Headline for ${phase.name}',
  detail: 'Compassionate detail for ${phase.name}.',
  supportingSignalCount: phase == LivingLanternPhase.gentleReturn ? 2 : 0,
);

void main() {
  const phaseLabels = <LivingLanternPhase, String>{
    LivingLanternPhase.ready: 'READY',
    LivingLanternPhase.focusing: 'STEADY FOCUS',
    LivingLanternPhase.resting: 'RESTING',
    LivingLanternPhase.celebrating: 'CELEBRATING',
    LivingLanternPhase.gentleReturn: 'GENTLE RETURN',
  };

  testWidgets('renders every phase with the same complete illustration', (
    tester,
  ) async {
    for (final entry in phaseLabels.entries) {
      final state = _state(entry.key);
      await tester.pumpWidget(_app(state));

      expect(find.byKey(const ValueKey('living-lantern-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('living-lantern-illustration')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('living-lantern-illustration')),
        ),
        const Size(66, 78),
      );
      expect(find.text('LIVING LANTERN · ${entry.value}'), findsOneWidget);
      expect(find.text(state.headline), findsOneWidget);
      expect(find.text(state.detail), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('exposes one complete screen-reader description', (tester) async {
    const state = LivingLanternState(
      phase: LivingLanternPhase.gentleReturn,
      headline: 'A smaller return still carries light',
      detail: 'The lantern stays whole while you choose a gentler next step.',
      supportingSignalCount: 2,
    );
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(_app(state));

      expect(
        find.bySemanticsLabel(
          'Living Lantern. Gentle return. A smaller return still carries light. '
          'The lantern stays whole while you choose a gentler next step.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('remains informational without timer or navigation controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_state(LivingLanternPhase.focusing)));

    final card = find.byKey(const ValueKey('living-lantern-card'));
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports a narrow surface and large accessible text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_state(LivingLanternPhase.resting), textScale: 2, cardWidth: 260),
    );

    expect(find.text('LIVING LANTERN · RESTING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('living-lantern-illustration')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
