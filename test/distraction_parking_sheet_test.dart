import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/parked_thought.dart';
import 'package:focushaven/widgets/distraction_parking_sheet.dart';
import 'package:focushaven/widgets/text_entry_dialog.dart';

class _ThoughtHistoryStore {
  _ThoughtHistoryStore(Iterable<ParkedThought> initialThoughts)
    : thoughts = List<ParkedThought>.of(initialThoughts);

  final List<ParkedThought> thoughts;

  List<ParkedThought> readActive() =>
      List.unmodifiable(thoughts.where((thought) => !thought.isCompleted));

  List<ParkedThought> readCompleted() =>
      List.unmodifiable(thoughts.where((thought) => thought.isCompleted));

  void add(String text) {
    thoughts.add(
      ParkedThought(
        id: 'added-${thoughts.length}',
        text: text,
        createdAt: DateTime.utc(2026, 8, 8, 12),
      ),
    );
  }

  void rename(String id, String text) {
    final index = thoughts.indexWhere((thought) => thought.id == id);
    thoughts[index] = thoughts[index].rename(text);
  }

  void complete(String id) {
    final index = thoughts.indexWhere((thought) => thought.id == id);
    thoughts[index] = thoughts[index].complete(DateTime.utc(2026, 8, 8, 13));
  }

  void reopen(String id) {
    final index = thoughts.indexWhere((thought) => thought.id == id);
    thoughts[index] = thoughts[index].reopen();
  }

  void remove(String id) {
    thoughts.removeWhere((thought) => thought.id == id);
  }

  void clearActive() {
    thoughts.removeWhere((thought) => !thought.isCompleted);
  }

  void clearCompleted() {
    thoughts.removeWhere((thought) => thought.isCompleted);
  }
}

Widget _historyApp(
  _ThoughtHistoryStore store, {
  ParkedThoughtAdder? addThought,
  ParkedThoughtIdUpdater? renameThought,
  ParkedThoughtIdAction? completeThought,
  ParkedThoughtIdAction? reopenThought,
  ParkedThoughtIdAction? removeThoughtById,
  ParkedThoughtClearAction? clearThoughts,
  ParkedThoughtClearAction? clearCompletedThoughts,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => DistractionParkingSheet.withHistory(
              readActiveThoughts: store.readActive,
              readCompletedThoughts: store.readCompleted,
              addThought: addThought ?? store.add,
              renameThought: renameThought ?? store.rename,
              completeThought: completeThought ?? store.complete,
              reopenThought: reopenThought ?? store.reopen,
              removeThoughtById: removeThoughtById ?? store.remove,
              clearThoughts: clearThoughts ?? store.clearActive,
              clearCompletedThoughts:
                  clearCompletedThoughts ?? store.clearCompleted,
            ),
          ),
          child: const Text('Open thought history'),
        ),
      ),
    ),
  );
}

Future<void> _openHistorySheet(
  WidgetTester tester,
  _ThoughtHistoryStore store, {
  ParkedThoughtAdder? addThought,
  ParkedThoughtIdUpdater? renameThought,
  ParkedThoughtIdAction? completeThought,
  ParkedThoughtIdAction? reopenThought,
  ParkedThoughtIdAction? removeThoughtById,
  ParkedThoughtClearAction? clearThoughts,
  ParkedThoughtClearAction? clearCompletedThoughts,
}) async {
  await tester.pumpWidget(
    _historyApp(
      store,
      addThought: addThought,
      renameThought: renameThought,
      completeThought: completeThought,
      reopenThought: reopenThought,
      removeThoughtById: removeThoughtById,
      clearThoughts: clearThoughts,
      clearCompletedThoughts: clearCompletedThoughts,
    ),
  );
  await tester.tap(find.text('Open thought history'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds a parked thought with Enter and preserves cleaned text', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([]);
    await _openHistorySheet(tester, store);

    expect(
      find.text('Nothing parked yet. Keep your attention where you want it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add a thought'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Reply to Jordan after this session',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      store.readActive().single.text,
      'Reply to Jordan after this session',
    );
    expect(find.text('Reply to Jordan after this session'), findsOneWidget);
    expect(find.text('Clear parked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing and removing affect only the selected thought', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'top',
        text: 'Top thought',
        createdAt: DateTime.utc(2026, 8, 8, 9),
      ),
      ParkedThought(
        id: 'middle',
        text: 'Middle thought',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'bottom',
        text: 'Bottom thought',
        createdAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(tester, store);

    await tester.tap(find.byTooltip('Edit thought').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Edit parked thought'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated middle thought');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.readActive().map((thought) => thought.text), [
      'Top thought',
      'Updated middle thought',
      'Bottom thought',
    ]);
    expect(find.text('Middle thought'), findsNothing);
    expect(find.text('Updated middle thought'), findsOneWidget);

    final removeBottomThought = find.byTooltip('Remove thought').at(2);
    await tester.ensureVisible(removeBottomThought);
    await tester.pumpAndSettle();
    await tester.tap(removeBottomThought);
    await tester.pumpAndSettle();

    expect(store.readActive().map((thought) => thought.text), [
      'Top thought',
      'Updated middle thought',
    ]);
    expect(find.text('Top thought'), findsOneWidget);
    expect(find.text('Updated middle thought'), findsOneWidget);
    expect(find.text('Bottom thought'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing parked thoughts keeps the empty sheet available', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'first',
        text: 'First thought',
        createdAt: DateTime.utc(2026, 8, 8, 9),
      ),
      ParkedThought(
        id: 'second',
        text: 'Second thought',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
    ]);
    await _openHistorySheet(tester, store);

    await tester.tap(find.text('Clear parked'));
    await tester.pumpAndSettle();

    expect(store.thoughts, isEmpty);
    expect(find.text('Distraction parking lot'), findsOneWidget);
    expect(
      find.text('Nothing parked yet. Keep your attention where you want it.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('completing and reopening preserve the selected thought', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'first',
        text: 'Call the dentist',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'second',
        text: 'Reply to Jordan',
        createdAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(tester, store);

    expect(find.text('Parked (2)'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark thought complete').first);
    await tester.pumpAndSettle();

    expect(store.readActive().single.id, 'second');
    expect(store.readCompleted().single.id, 'first');
    expect(find.text('Parked (1)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);

    final reopenThought = find.byTooltip('Return thought to parking lot');
    await tester.ensureVisible(reopenThought);
    await tester.pumpAndSettle();
    await tester.tap(reopenThought);
    await tester.pumpAndSettle();

    expect(store.readActive().map((thought) => thought.id), [
      'first',
      'second',
    ]);
    expect(store.readCompleted(), isEmpty);
    expect(find.text('Parked (2)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsNothing);
  });

  testWidgets('history edit and remove actions use stable thought IDs', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'active',
        text: 'Original active thought',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'completed',
        text: 'Completed thought',
        createdAt: DateTime.utc(2026, 8, 8, 9),
        completedAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(tester, store);

    await tester.tap(find.byTooltip('Edit thought'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated active thought');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.thoughts.first.id, 'active');
    expect(store.thoughts.first.text, 'Updated active thought');
    expect(store.thoughts.last.id, 'completed');

    final removeCompleted = find.byTooltip('Remove completed thought');
    await tester.ensureVisible(removeCompleted);
    await tester.pumpAndSettle();
    await tester.tap(removeCompleted);
    await tester.pumpAndSettle();

    expect(store.thoughts.map((thought) => thought.id), ['active']);
    expect(find.text('Updated active thought'), findsOneWidget);
    expect(find.text('Completed thought'), findsNothing);
  });

  testWidgets('clearing completed history keeps active thoughts', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'active',
        text: 'Still parked',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'completed',
        text: 'Already handled',
        createdAt: DateTime.utc(2026, 8, 8, 9),
        completedAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(tester, store);

    final clearCompleted = find.text('Clear completed');
    await tester.ensureVisible(clearCompleted);
    await tester.tap(clearCompleted);
    await tester.pumpAndSettle();

    expect(store.thoughts.single.id, 'active');
    expect(find.text('Still parked'), findsOneWidget);
    expect(find.text('Already handled'), findsNothing);
  });

  testWidgets('blocks duplicate parked-thought editors', (tester) async {
    final store = _ThoughtHistoryStore([]);
    await _openHistorySheet(tester, store);
    final addAction = find.byKey(const ValueKey<String>('add-parked-thought'));
    final addButton = tester.widget<FilledButton>(addAction);

    addButton.onPressed!.call();
    addButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Add a parked thought'), findsOneWidget);
    expect(find.byType(TextEntryDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(addAction).onPressed, isNotNull);
    expect(store.thoughts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains add failures and restores the pending editor', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([]);
    await _openHistorySheet(
      tester,
      store,
      addThought: (_) async => throw StateError('timer storage unavailable'),
    );
    final addAction = find.byKey(const ValueKey<String>('add-parked-thought'));

    await tester.tap(addAction);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reply after focusing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.text('Thought could not be added. Please try again.'),
      findsOneWidget,
    );
    expect(store.thoughts, isEmpty);
    expect(tester.widget<FilledButton>(addAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains edit failures and preserves the parked thought', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'thought',
        text: 'Keep this thought unchanged',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
    ]);
    await _openHistorySheet(
      tester,
      store,
      renameThought: (_, _) async =>
          throw StateError('timer storage unavailable'),
    );
    final editAction = find.byKey(
      const ValueKey<String>('edit-parked-thought-thought'),
    );

    await tester.tap(editAction);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed thought');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.text('Thought could not be updated. Please try again.'),
      findsOneWidget,
    );
    expect(store.thoughts, hasLength(1));
    expect(store.thoughts.single.id, 'thought');
    expect(store.thoughts.single.text, 'Keep this thought unchanged');
    expect(tester.widget<IconButton>(editAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes history actions per parked thought', (tester) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'thought',
        text: 'Complete this once',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
    ]);
    final completion = Completer<void>();
    var calls = 0;
    await _openHistorySheet(
      tester,
      store,
      completeThought: (id) async {
        calls += 1;
        await completion.future;
        store.complete(id);
      },
    );
    final action = find.byKey(
      const ValueKey<String>('complete-parked-thought-thought'),
    );
    final onPressed = tester.widget<IconButton>(action).onPressed!;

    onPressed();
    onPressed();
    await tester.pump();

    expect(calls, 1);
    expect(tester.widget<IconButton>(action).onPressed, isNull);
    expect(store.readActive().single.id, 'thought');

    completion.complete();
    await tester.pumpAndSettle();

    expect(store.readActive(), isEmpty);
    expect(store.readCompleted().single.id, 'thought');
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains history action failures and restores controls', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'active',
        text: 'Still active',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'completed',
        text: 'Still completed',
        createdAt: DateTime.utc(2026, 8, 8, 9),
        completedAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(
      tester,
      store,
      completeThought: (_) async => throw StateError('complete failed'),
      reopenThought: (_) async => throw StateError('reopen failed'),
      removeThoughtById: (_) async => throw StateError('remove failed'),
    );
    final completeAction = find.byKey(
      const ValueKey<String>('complete-parked-thought-active'),
    );
    final reopenAction = find.byKey(
      const ValueKey<String>('reopen-parked-thought-completed'),
    );
    final removeAction = find.byKey(
      const ValueKey<String>('remove-parked-thought-active'),
    );

    await tester.tap(completeAction);
    await tester.pumpAndSettle();

    expect(
      find.text('Thought could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(store.readActive().single.id, 'active');
    expect(tester.widget<IconButton>(completeAction).onPressed, isNotNull);

    tester.widget<IconButton>(reopenAction).onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Thought could not be returned to the parking lot. Please try again.',
      ),
      findsOneWidget,
    );
    expect(store.readCompleted().single.id, 'completed');
    expect(tester.widget<IconButton>(reopenAction).onPressed, isNotNull);

    tester.widget<IconButton>(removeAction).onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Thought could not be removed. Please try again.'),
      findsOneWidget,
    );
    expect(store.thoughts.map((thought) => thought.id), [
      'active',
      'completed',
    ]);
    expect(tester.widget<IconButton>(removeAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes clear actions per history section', (tester) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'active',
        text: 'Clear this once',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
    ]);
    final completion = Completer<void>();
    var calls = 0;
    await _openHistorySheet(
      tester,
      store,
      clearThoughts: () async {
        calls += 1;
        await completion.future;
        store.clearActive();
      },
    );
    final action = find.byKey(const ValueKey<String>('clear-parked-thoughts'));
    final onPressed = tester.widget<TextButton>(action).onPressed!;

    onPressed();
    onPressed();
    await tester.pump();

    expect(calls, 1);
    expect(tester.widget<TextButton>(action).onPressed, isNull);
    expect(store.readActive().single.id, 'active');

    completion.complete();
    await tester.pumpAndSettle();

    expect(store.thoughts, isEmpty);
    expect(
      find.text('Nothing parked yet. Keep your attention where you want it.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains clear failures and restores history controls', (
    tester,
  ) async {
    final store = _ThoughtHistoryStore([
      ParkedThought(
        id: 'active',
        text: 'Keep active',
        createdAt: DateTime.utc(2026, 8, 8, 10),
      ),
      ParkedThought(
        id: 'completed',
        text: 'Keep completed',
        createdAt: DateTime.utc(2026, 8, 8, 9),
        completedAt: DateTime.utc(2026, 8, 8, 11),
      ),
    ]);
    await _openHistorySheet(
      tester,
      store,
      clearThoughts: () async => throw StateError('clear active failed'),
      clearCompletedThoughts: () async =>
          throw StateError('clear completed failed'),
    );
    final clearActive = find.byKey(
      const ValueKey<String>('clear-parked-thoughts'),
    );
    final clearCompleted = find.byKey(
      const ValueKey<String>('clear-completed-thoughts'),
    );

    await tester.ensureVisible(clearActive);
    await tester.tap(clearActive);
    await tester.pumpAndSettle();

    expect(
      find.text('Parked thoughts could not be cleared. Please try again.'),
      findsOneWidget,
    );
    expect(store.readActive().single.id, 'active');
    expect(tester.widget<TextButton>(clearActive).onPressed, isNotNull);

    await tester.ensureVisible(clearCompleted);
    await tester.tap(clearCompleted);
    await tester.pumpAndSettle();

    expect(
      find.text('Completed thoughts could not be cleared. Please try again.'),
      findsOneWidget,
    );
    expect(store.readCompleted().single.id, 'completed');
    expect(tester.widget<TextButton>(clearCompleted).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
