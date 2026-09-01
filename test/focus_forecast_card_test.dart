import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';

import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/widgets/focus_forecast_card.dart';

Widget _app(
  FocusForecast forecast, {
  double textScale = 1,
  double cardWidth = 380,
}) => MaterialApp(
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
          child: FocusForecastCard(forecast: forecast),
        ),
      ),
    ),
  ),
);

const _learning = FocusForecast(
  kind: FocusForecastKind.learning,
  headline: 'Your Focus Forecast is still forming',
  detail: 'Complete a few sessions at times that naturally fit.',
  evidence: 'Two completed timing signals are available.',
  signalCount: 2,
);

void main() {
  testWidgets('labels every forecast without claiming a best time', (
    tester,
  ) async {
    const forecasts = <FocusForecast, String>{
      _learning: 'STILL LEARNING',
      FocusForecast(
        kind: FocusForecastKind.emergingWindow,
        headline: 'Completed focus often begins in the morning',
        detail: 'Treat this as a possible planning window.',
        evidence: 'Four of six sessions began between 8 AM and noon.',
        signalCount: 6,
        window: FocusForecastWindow.morning,
      ): 'POSSIBLE WINDOW',
      FocusForecast(
        kind: FocusForecastKind.flexible,
        headline: 'Your completed focus moves across the day',
        detail: 'Current energy and availability should keep leading.',
        evidence: 'Six sessions are spread across the day.',
        signalCount: 6,
      ): 'FLEXIBLE TIMING',
    };

    for (final entry in forecasts.entries) {
      await tester.pumpWidget(_app(entry.key));

      expect(find.text('FOCUS FORECAST · ${entry.value}'), findsOneWidget);
      expect(find.text(entry.key.headline), findsOneWidget);
      expect(find.textContaining('best time'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps evidence and boundaries behind an explicit tap', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_learning));

    expect(find.text(_learning.detail), findsNothing);
    expect(find.text(_learning.evidence), findsNothing);
    expect(find.byKey(const ValueKey('focus-forecast-details')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-focus-forecast')));
    await tester.pump();

    expect(find.text(_learning.detail), findsOneWidget);
    expect(find.text(_learning.evidence), findsOneWidget);
    expect(find.textContaining('not a promise'), findsOneWidget);
    expect(find.textContaining('No task text'), findsOneWidget);
    expect(find.textContaining('automatic schedule'), findsOneWidget);
  });

  testWidgets('exposes one complete screen-reader toggle description', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(_app(_learning));

      expect(
        find.bySemanticsLabel(
          'Focus Forecast. Still learning. '
          'Your Focus Forecast is still forming. Show details.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('toggle-focus-forecast')));
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          'Focus Forecast. Still learning. '
          'Your Focus Forecast is still forming. Hide details.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('remains informational without timer or scheduling controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_learning));
    await tester.tap(find.byKey(const ValueKey('toggle-focus-forecast')));
    await tester.pump();

    final card = find.byKey(const ValueKey('focus-forecast-card'));
    expect(
      find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports a narrow surface and large accessible text', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_learning, textScale: 2, cardWidth: 260));
    await tester.tap(find.byKey(const ValueKey('toggle-focus-forecast')));
    await tester.pump();

    expect(find.text('FOCUS FORECAST · STILL LEARNING'), findsOneWidget);
    expect(find.text(_learning.detail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
