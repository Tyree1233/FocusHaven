import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/widgets/completed_tasks_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(FocusQueueService service) {
  return ProviderScope(
    overrides: [focusQueueServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: CompletedTasksSheet(
          dateLabel: (value) => value.day == 7 ? 'Aug 7' : 'Aug 6',
        ),
      ),
    ),
  );
}

Future<FocusQueueService> _pumpCompletedTasks(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'focusQueue': jsonEncode([
      {
        'id': 'older-task',
        'title': 'Review notes',
        'isComplete': true,
        'completedAt': '2026-08-06T12:00:00.000',
      },
      {
        'id': 'newer-task',
        'title': 'Plan tomorrow',
        'isComplete': true,
        'completedAt': '2026-08-07T18:30:00.000',
      },
    ]),
  });
  final service = FocusQueueService();
  await tester.pump();

  await tester.pumpWidget(_app(service));
  await tester.pump();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders completed tasks newest first with completion dates', (
    tester,
  ) async {
    final service = await _pumpCompletedTasks(tester);

    expect(find.text('Completed tasks'), findsOneWidget);
    expect(find.text('A quiet record of what you handled.'), findsOneWidget);
    expect(find.text('Plan tomorrow'), findsOneWidget);
    expect(find.text('Completed Aug 7'), findsOneWidget);
    expect(find.text('Review notes'), findsOneWidget);
    expect(find.text('Completed Aug 6'), findsOneWidget);
    expect(
      service.completedItems.map((item) => item.id),
      orderedEquals(['newer-task', 'older-task']),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo returns the selected task and no other task', (
    tester,
  ) async {
    final service = await _pumpCompletedTasks(tester);
    final selectedTile = find.ancestor(
      of: find.text('Plan tomorrow'),
      matching: find.byType(ListTile),
    );
    final selectedUndo = find.descendant(
      of: selectedTile,
      matching: find.byTooltip('Return to queue'),
    );

    expect(selectedUndo, findsOneWidget);
    await tester.tap(selectedUndo);
    await tester.pumpAndSettle();

    expect(service.items, hasLength(1));
    expect(service.items.single.id, 'newer-task');
    expect(service.items.single.title, 'Plan tomorrow');
    expect(service.completedItems, hasLength(1));
    expect(service.completedItems.single.id, 'older-task');
    expect(find.text('Plan tomorrow'), findsNothing);
    expect(find.text('Review notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
