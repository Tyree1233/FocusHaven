import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/widgets/focus_session_reflection_card.dart';

Widget _app({
  FocusSessionFit? selected,
  required ValueChanged<FocusSessionFit> onSelected,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(
        child: FocusSessionReflectionCard(
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers three optional text-free reflection choices', (
    tester,
  ) async {
    FocusSessionFit? chosen;
    await tester.pumpWidget(_app(onSelected: (value) => chosen = value));

    expect(find.text('How did that session feel?'), findsOneWidget);
    expect(find.text('Too much'), findsOneWidget);
    expect(find.text('About right'), findsOneWidget);
    expect(find.text('Could do more'), findsOneWidget);
    expect(find.textContaining('Optional and text-free'), findsOneWidget);
    expect(find.textContaining('Saved privately'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('focus-session-fit-aboutRight')),
    );
    await tester.pump();

    expect(chosen, FocusSessionFit.aboutRight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the selected answer can still be changed', (tester) async {
    FocusSessionFit? chosen;
    await tester.pumpWidget(
      _app(
        selected: FocusSessionFit.tooMuch,
        onSelected: (value) => chosen = value,
      ),
    );

    final selectedChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('focus-session-fit-tooMuch')),
    );
    expect(selectedChip.selected, isTrue);
    expect(find.textContaining('You can change your answer'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('focus-session-fit-couldDoMore')),
    );
    await tester.pump();

    expect(chosen, FocusSessionFit.couldDoMore);
    expect(tester.takeException(), isNull);
  });
}
