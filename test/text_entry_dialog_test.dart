import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/text_entry_dialog.dart';

class _CountingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

Widget _launcher(
  Future<void> Function(BuildContext) onOpen, {
  NavigatorObserver? observer,
}) {
  return MaterialApp(
    navigatorObservers: [?observer],
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => onOpen(context),
          child: const Text('Open dialog'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('submitting a single-line value with Enter returns the text', (
    tester,
  ) async {
    String? result;
    var completed = false;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Edit task',
          confirmLabel: 'Save',
          initialValue: 'Original task',
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated task');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, 'Updated task');
    expect(find.text('Edit task'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear returns an empty value without a lifecycle exception', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Park a thought',
          confirmLabel: 'Save thought',
          initialValue: 'Remember this',
          clearLabel: 'Clear',
        );
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(result, '');
    expect(find.text('Park a thought'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiline input keeps newlines until the save button is used', (
    tester,
  ) async {
    String? result;
    var completed = false;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Add notes',
          confirmLabel: 'Save notes',
          maxLines: 3,
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First line\nSecond line');

    expect(completed, isFalse);
    expect(find.text('Add notes'), findsOneWidget);

    await tester.tap(find.text('Save notes'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, 'First line\nSecond line');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel returns null', (tester) async {
    String? result = 'unchanged';
    var completed = false;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Set intention',
          confirmLabel: 'Save',
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping save and clear actions', (tester) async {
    final observer = _CountingNavigatorObserver();
    String? result;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Edit thought',
          confirmLabel: 'Save',
          initialValue: 'Original thought',
          clearLabel: 'Clear',
        );
      }, observer: observer),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated thought');
    final submit = tester
        .widget<FilledButton>(
          find.byKey(const ValueKey<String>('text-entry-submit')),
        )
        .onPressed!;
    final clear = tester
        .widget<TextButton>(
          find.byKey(const ValueKey<String>('text-entry-clear')),
        )
        .onPressed!;

    submit();
    clear();
    await tester.pumpAndSettle();

    expect(result, 'Updated thought');
    expect(observer.popCount, 1);
    expect(find.text('Edit thought'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping Enter and cancel actions', (
    tester,
  ) async {
    final observer = _CountingNavigatorObserver();
    String? result;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await TextEntryDialog.show(
          context,
          title: 'Set intention',
          confirmLabel: 'Save',
          initialValue: 'Original intention',
        );
      }, observer: observer),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'One intention');
    final submitWithEnter = tester.widget<TextField>(find.byType(TextField));
    final cancel = tester
        .widget<TextButton>(
          find.byKey(const ValueKey<String>('text-entry-cancel')),
        )
        .onPressed!;

    submitWithEnter.onSubmitted!.call('One intention');
    cancel();
    await tester.pumpAndSettle();

    expect(result, 'One intention');
    expect(observer.popCount, 1);
    expect(find.text('Set intention'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
