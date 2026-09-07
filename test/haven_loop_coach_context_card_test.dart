import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/models/focus_forecast.dart';
import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/models/haven_loop_coach_context.dart';
import 'package:focushaven/models/haven_rhythm_insight.dart';
import 'package:focushaven/widgets/haven_loop_coach_context_card.dart';

void main() {
  const completion = (
    startedAtMicrosecondsSinceEpoch: 1,
    endedAtMicrosecondsSinceEpoch: 2,
    plannedDurationSeconds: 1500,
  );

  Widget app(
    HavenLoopCoachContext context, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: HavenLoopCoachContextCard(loopContext: context),
      ),
    ),
  );

  testWidgets('discloses only the exact text-free completion signals', (
    tester,
  ) async {
    const context = HavenLoopCoachContext(
      moment: HavenLoopCoachMoment.steadyNextSession,
      hasLinkedTask: false,
      completion: completion,
      sessionFit: FocusSessionFit.aboutRight,
      rhythmKind: HavenRhythmReflectionConnectionKind.reflectionPattern,
      forecastKind:
          FocusForecastReflectionConnectionKind.alignsWithPossibleWindow,
      journeyKind: HavenJourneyCompletionConnectionKind.placeHeld,
    );

    await tester.pumpWidget(app(context));

    expect(
      find.byKey(const ValueKey<String>('haven-loop-coach-context')),
      findsOneWidget,
    );
    expect(find.text('ONE CALM NEXT STEP'), findsOneWidget);
    expect(
      find.textContaining('last reflected session felt about right'),
      findsOneWidget,
    );
    expect(find.text('HAVEN RHYTHM · REFLECTION SAVED'), findsOneWidget);
    expect(find.text('FOCUS FORECAST · REFLECTION SAVED'), findsOneWidget);
    expect(find.text('HAVEN JOURNEY · COMPLETION KEPT'), findsOneWidget);
    expect(find.textContaining('text-free focus signals'), findsOneWidget);
    expect(
      find.textContaining('Nothing changed automatically'),
      findsOneWidget,
    );
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces the privacy and agency boundary as one container', (
    tester,
  ) async {
    const context = HavenLoopCoachContext(
      moment: HavenLoopCoachMoment.taskDecision,
      hasLinkedTask: true,
      completion: completion,
    );

    await tester.pumpWidget(app(context));

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('haven-loop-coach-context')),
    );
    expect(semantics.label, contains('queue task is finished'));
    expect(semantics.label, contains('text-free focus signals'));
    expect(semantics.label, contains('Nothing changed automatically'));
  });

  testWidgets('remains readable at narrow large-text settings', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const context = HavenLoopCoachContext(
      moment: HavenLoopCoachMoment.smartResetChoice,
      hasLinkedTask: true,
    );

    await tester.pumpWidget(app(context, textScale: 2));

    expect(find.text('ONE CALM NEXT STEP'), findsOneWidget);
    expect(find.textContaining('No task text is copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the selected reviewed catalog without new messages', (
    tester,
  ) async {
    const context = HavenLoopCoachContext(
      moment: HavenLoopCoachMoment.reflectionChoice,
      hasLinkedTask: false,
      completion: completion,
    );

    await tester.pumpWidget(app(context, locale: const Locale('ja')));

    expect(find.text('ONE CALM NEXT STEP'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('haven-loop-coach-context')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
