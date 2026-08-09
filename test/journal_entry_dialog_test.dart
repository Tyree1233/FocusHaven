import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/journal_entry_dialog.dart';

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
}
