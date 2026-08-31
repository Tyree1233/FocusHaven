import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/widgets/focus_queue_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  FocusQueueService service, {
  FocusQueueTaskEditor? onEditTask,
  FocusQueueTitleAction? addTask,
  FocusQueueItemAction? completeTask,
  FocusQueueItemAction? removeTask,
}) {
  return ProviderScope(
    overrides: [focusQueueServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: FocusQueueSheet(
          onTaskSelected: (_) async => true,
          onEditTask: onEditTask ?? (_) async {},
          onShowCompleted: () {},
          addTask: addTask,
          completeTask: completeTask,
          removeTask: removeTask,
        ),
      ),
    ),
  );
}

Future<FocusQueueService> _pumpQueue(
  WidgetTester tester, {
  List<Map<String, Object?>> items = const [],
  FocusQueueTaskEditor? onEditTask,
  FocusQueueTitleAction? addTask,
  FocusQueueItemAction? completeTask,
  FocusQueueItemAction? removeTask,
}) async {
  SharedPreferences.setMockInitialValues({'focusQueue': jsonEncode(items)});
  final service = FocusQueueService();
  await tester.pump();

  await tester.pumpWidget(
    _app(
      service,
      onEditTask: onEditTask,
      addTask: addTask,
      completeTask: completeTask,
      removeTask: removeTask,
    ),
  );
  await tester.pump();
  return service;
}

Map<String, Object?> _item(String id, String title) {
  return {'id': id, 'title': title, 'isComplete': false};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('submitting with Enter adds one cleaned task and clears input', (
    tester,
  ) async {
    final service = await _pumpQueue(tester);

    await tester.enterText(find.byType(TextField), '  Review   notes  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(service.items, hasLength(1));
    expect(service.items.single.title, 'Review notes');
    expect(find.text('Review notes'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing renames the selected task without creating a duplicate',
    (tester) async {
      late FocusQueueService service;
      service = await _pumpQueue(
        tester,
        items: [
          _item('first', 'Review notes'),
          _item('second', 'Plan tomorrow'),
        ],
        onEditTask: (item) => service.rename(item.id, 'Updated notes'),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('focus-queue-edit-first')),
      );
      await tester.pumpAndSettle();

      expect(service.items, hasLength(2));
      expect(
        service.items.map((item) => item.id),
        orderedEquals(['first', 'second']),
      );
      expect(service.items.first.title, 'Updated notes');
      expect(find.text('Review notes'), findsNothing);
      expect(find.text('Updated notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('complete and remove actions affect only the selected tasks', (
    tester,
  ) async {
    final service = await _pumpQueue(
      tester,
      items: [
        _item('top', 'Top task'),
        _item('middle', 'Middle task'),
        _item('bottom', 'Bottom task'),
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('focus-queue-checkbox-middle')),
    );
    await tester.pumpAndSettle();

    expect(
      service.items.map((item) => item.id),
      orderedEquals(['top', 'bottom']),
    );
    expect(service.completedItems, hasLength(1));
    expect(service.completedItems.single.id, 'middle');
    expect(find.text('Completed (1)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('focus-queue-remove-bottom')),
    );
    await tester.pumpAndSettle();

    expect(service.items.map((item) => item.id), orderedEquals(['top']));
    expect(service.completedItems.single.id, 'middle');
    expect(find.text('Top task'), findsOneWidget);
    expect(find.text('Bottom task'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains add failures and preserves the pending title', (
    tester,
  ) async {
    final service = await _pumpQueue(
      tester,
      addTask: (_) async => throw StateError('queue storage unavailable'),
    );
    final addAction = find.byKey(
      const ValueKey<String>('focus-queue-add-task'),
    );

    await tester.enterText(find.byType(TextField), 'Plan tomorrow');
    await tester.tap(addAction);
    await tester.pumpAndSettle();

    expect(
      find.text('Task could not be added. Please try again.'),
      findsOneWidget,
    );
    expect(service.items, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Plan tomorrow',
    );
    expect(tester.widget<IconButton>(addAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains item action failures and restores controls', (
    tester,
  ) async {
    final service = await _pumpQueue(
      tester,
      items: [_item('task', 'Review notes')],
      onEditTask: (_) async => throw StateError('edit unavailable'),
      completeTask: (_) async => throw StateError('complete unavailable'),
      removeTask: (_) async => throw StateError('remove unavailable'),
    );
    final checkbox = find.byKey(
      const ValueKey<String>('focus-queue-checkbox-task'),
    );
    final editAction = find.byKey(
      const ValueKey<String>('focus-queue-edit-task'),
    );
    final removeAction = find.byKey(
      const ValueKey<String>('focus-queue-remove-task'),
    );

    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(
      find.text('Task could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(tester.widget<Checkbox>(checkbox).onChanged, isNotNull);

    await tester.tap(editAction);
    await tester.pumpAndSettle();

    expect(
      find.text('Task could not be updated. Please try again.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(editAction).onPressed, isNotNull);

    await tester.tap(removeAction);
    await tester.pumpAndSettle();

    expect(
      find.text('Task could not be removed. Please try again.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(removeAction).onPressed, isNotNull);
    expect(service.items, hasLength(1));
    expect(service.items.single.id, 'task');
    expect(service.items.single.title, 'Review notes');
    expect(service.completedItems, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
