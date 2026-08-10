import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/journal_entry_dialog.dart';

class _CountingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

Widget _launcher(
  _CountingNavigatorObserver observer,
  Future<void> Function(BuildContext context) onOpen,
) {
  return MaterialApp(
    navigatorObservers: [observer],
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => onOpen(context),
          child: const Text('Open guarded journal'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('returns the selected mood and multiline reflection', (
    tester,
  ) async {
    JournalEntryDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await JournalEntryDialog.show(
                  context,
                  initialMood: 'Calm',
                  initialReflection: '',
                  prompt: 'What supported your focus today?',
                  moods: const ['Calm', 'Focused', 'Grateful'],
                );
              },
              child: const Text('Open journal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();

    expect(find.text("Today's reflection"), findsOneWidget);
    expect(find.text('What supported your focus today?'), findsOneWidget);

    await tester.tap(find.text('Grateful'));
    await tester.enterText(find.byType(TextField), 'First line\nSecond line');
    await tester.tap(find.text('Save reflection'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.mood, 'Grateful');
    expect(result!.reflection, 'First line\nSecond line');
    expect(find.text("Today's reflection"), findsNothing);
  });

  testWidgets('cancel closes the dialog without returning a draft', (
    tester,
  ) async {
    JournalEntryDraft? result;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await JournalEntryDialog.show(
                  context,
                  initialMood: 'Focused',
                  initialReflection: 'Keep this unchanged.',
                  prompt: 'Reflect gently.',
                  moods: const ['Calm', 'Focused'],
                );
                completed = true;
              },
              child: const Text('Open journal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this unchanged.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text("Today's reflection"), findsNothing);
  });

  testWidgets('serializes overlapping save and cancel actions', (tester) async {
    final observer = _CountingNavigatorObserver();
    JournalEntryDraft? result;

    await tester.pumpWidget(
      _launcher(observer, (context) async {
        result = await JournalEntryDialog.show(
          context,
          initialMood: 'Calm',
          initialReflection: 'Original reflection',
          prompt: 'Reflect gently.',
          moods: const ['Calm', 'Focused'],
        );
      }),
    );

    await tester.tap(find.text('Open guarded journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focused'));
    await tester.enterText(find.byType(TextField), 'Saved reflection');
    final save = tester
        .widget<FilledButton>(
          find.byKey(const ValueKey<String>('journal-entry-submit')),
        )
        .onPressed!;
    final cancel = tester
        .widget<TextButton>(
          find.byKey(const ValueKey<String>('journal-entry-cancel')),
        )
        .onPressed!;

    save();
    cancel();
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.mood, 'Focused');
    expect(result!.reflection, 'Saved reflection');
    expect(observer.popCount, 1);
    expect(find.text("Today's reflection"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping cancel and save actions', (tester) async {
    final observer = _CountingNavigatorObserver();
    JournalEntryDraft? result;
    var completed = false;

    await tester.pumpWidget(
      _launcher(observer, (context) async {
        result = await JournalEntryDialog.show(
          context,
          initialMood: 'Calm',
          initialReflection: 'Do not save this',
          prompt: 'Reflect gently.',
          moods: const ['Calm', 'Focused'],
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open guarded journal'));
    await tester.pumpAndSettle();
    final cancel = tester
        .widget<TextButton>(
          find.byKey(const ValueKey<String>('journal-entry-cancel')),
        )
        .onPressed!;
    final save = tester
        .widget<FilledButton>(
          find.byKey(const ValueKey<String>('journal-entry-submit')),
        )
        .onPressed!;

    cancel();
    save();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(observer.popCount, 1);
    expect(find.text("Today's reflection"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
