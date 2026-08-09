import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/distraction_parking_sheet.dart';

class _ThoughtStore {
  _ThoughtStore([Iterable<String> initialThoughts = const []])
    : thoughts = List<String>.of(initialThoughts);

  final List<String> thoughts;
  var clearCalls = 0;

  List<String> read() => List<String>.unmodifiable(thoughts);

  void add(String thought) {
    thoughts.add(thought);
  }

  void update(int index, String thought) {
    thoughts[index] = thought;
  }

  void remove(int index) {
    thoughts.removeAt(index);
  }

  void clear() {
    clearCalls += 1;
    thoughts.clear();
  }
}

Widget _app(_ThoughtStore store) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => DistractionParkingSheet(
              readThoughts: store.read,
              addThought: store.add,
              updateThought: store.update,
              removeThought: store.remove,
              clearThoughts: store.clear,
            ),
          ),
          child: const Text('Open parking lot'),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, _ThoughtStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.tap(find.text('Open parking lot'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds a parked thought with Enter and preserves cleaned text', (
    tester,
  ) async {
    final store = _ThoughtStore();
    await _openSheet(tester, store);

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

    expect(store.thoughts, ['Reply to Jordan after this session']);
    expect(find.text('Reply to Jordan after this session'), findsOneWidget);
    expect(find.text('Clear parking lot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing and removing affect only the selected thought', (
    tester,
  ) async {
    final store = _ThoughtStore([
      'Top thought',
      'Middle thought',
      'Bottom thought',
    ]);
    await _openSheet(tester, store);

    await tester.tap(find.byTooltip('Edit thought').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Edit parked thought'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated middle thought');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.thoughts, [
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

    expect(store.thoughts, ['Top thought', 'Updated middle thought']);
    expect(find.text('Top thought'), findsOneWidget);
    expect(find.text('Updated middle thought'), findsOneWidget);
    expect(find.text('Bottom thought'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing removes every thought and closes the sheet', (
    tester,
  ) async {
    final store = _ThoughtStore(['First thought', 'Second thought']);
    await _openSheet(tester, store);

    await tester.tap(find.text('Clear parking lot'));
    await tester.pumpAndSettle();

    expect(store.clearCalls, 1);
    expect(store.thoughts, isEmpty);
    expect(find.text('Distraction parking lot'), findsNothing);
    expect(find.text('Open parking lot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
