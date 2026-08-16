import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/focus_event.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/widgets/haven_plan_sheet.dart';

Widget _app({
  List<FocusQueueItem> queue = const [],
  List<FocusEvent> events = const [],
}) => ProviderScope(
  overrides: [
    focusQueueStateProvider.overrideWithValue((
      activeItems: queue,
      completedItems: const [],
      completedToday: 0,
    )),
    timerFocusEventsProvider.overrideWithValue(events),
  ],
  child: MaterialApp(
    theme: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF16FBA),
        surface: Color(0xFF352260),
      ),
    ),
    home: const Scaffold(body: HavenPlanSheet()),
  ),
);

void main() {
  testWidgets('previews a transparent private plan from the focus queue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        queue: const [
          FocusQueueItem(id: 'task-1', title: 'Finish the presentation'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Plan a gentle start'), findsOneWidget);
    expect(find.text('Finish the presentation'), findsOneWidget);
    expect(find.text('25 min focus'), findsOneWidget);
    expect(find.text('5 min break'), findsOneWidget);
    expect(
      find.textContaining('FocusHaven learns your rhythm'),
      findsOneWidget,
    );
    expect(find.textContaining('Private and temporary'), findsOneWidget);
    expect(find.text('Start 25-minute focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('energy and available time visibly recompute the local plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        queue: const [
          FocusQueueItem(id: 'task-1', title: 'Draft the first section'),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Low'));
    await tester.pump();

    expect(find.text('10 min focus'), findsOneWidget);
    expect(find.text('2 min break'), findsOneWidget);
    expect(find.textContaining('gentler place to begin'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Strong'));
    await tester.tap(find.widgetWithText(ChoiceChip, '60 min'));
    await tester.pump();

    expect(find.text('45 min focus'), findsOneWidget);
    expect(find.text('10 min break'), findsOneWidget);
    expect(find.text('Start 45-minute focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty queue keeps the next step explicitly user controlled', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Choose one small next step'), findsOneWidget);
    expect(find.textContaining('Name one visible action'), findsOneWidget);
    expect(find.text('Start 25-minute focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
