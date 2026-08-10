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
              completeThought: store.complete,
              reopenThought: store.reopen,
              removeThoughtById: store.remove,
              clearThoughts: store.clearActive,
              clearCompletedThoughts: store.clearCompleted,
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
}) async {
  await tester.pumpWidget(
    _historyApp(store, addThought: addThought, renameThought: renameThought),
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
}
