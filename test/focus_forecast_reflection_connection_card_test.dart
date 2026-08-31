import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/widgets/focus_forecast_reflection_connection_card.dart';

void main() {
  const completion = (
    startedAtMicrosecondsSinceEpoch: 1,
    endedAtMicrosecondsSinceEpoch: 2,
    plannedDurationSeconds: 1500,
  );
  const forecast = FocusForecast(
    kind: FocusForecastKind.emergingWindow,
    headline: 'Completed focus often begins in the morning',
    detail: 'Treat this as a possible window.',
    evidence: '4 of 6 recent sessions.',
    signalCount: 6,
    window: FocusForecastWindow.morning,
  );

  Widget app(FocusForecastReflectionConnection connection) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF16FBA),
          secondary: Color(0xFFFFB5D8),
        ),
      ),
      home: Scaffold(
        body: FocusForecastReflectionConnectionCard(connection: connection),
      ),
    );
  }

  testWidgets('explains the saved fit without adding a control', (
    tester,
  ) async {
    const connection = FocusForecastReflectionConnection(
      kind: FocusForecastReflectionConnectionKind.alignsWithPossibleWindow,
      completion: completion,
      selectedFit: FocusSessionFit.aboutRight,
      forecast: forecast,
      completedWindow: FocusForecastWindow.morning,
      headline: 'This completion sits inside a possible focus window',
      detail: 'Your saved fit adds context, not proof.',
    );

    await tester.pumpWidget(app(connection));

    expect(
      find.byKey(const ValueKey('focus-forecast-reflection-connection')),
      findsOneWidget,
    );
    expect(find.text('About right'), findsOneWidget);
    expect(find.text(connection.headline), findsOneWidget);
    expect(find.text(connection.detail), findsOneWidget);
    expect(
      find.textContaining('A possible window is not a rule'),
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
    const connection = FocusForecastReflectionConnection(
      kind: FocusForecastReflectionConnectionKind.outsidePossibleWindow,
      completion: completion,
      selectedFit: FocusSessionFit.tooMuch,
      forecast: forecast,
      completedWindow: FocusForecastWindow.evening,
      headline: 'One session can sit outside a possible window',
      detail: 'Focus Forecast is an observation, not a rule.',
    );

    await tester.pumpWidget(app(connection));

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('focus-forecast-reflection-connection')),
    );
    expect(semantics.label, contains(connection.headline));
    expect(semantics.label, contains(connection.detail));
    expect(semantics.label, contains('Nothing changed automatically'));
    expect(semantics.label, contains('not a rule'));
  });
}
