import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/confirmation_dialog.dart';

Widget _launcher(Future<void> Function(BuildContext) onOpen) {
  return MaterialApp(
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
  testWidgets('cancel returns false and cannot approve the action', (
    tester,
  ) async {
    bool? result;
    var completed = false;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await ConfirmationDialog.show(
          context,
          title: 'Delete local data?',
          message: 'This removes data stored on this device.',
          cancelLabel: 'Keep my data',
          confirmLabel: 'Delete data',
          isDestructive: true,
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep my data'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isFalse);
    expect(find.text('Delete local data?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm returns true only after explicit approval', (
    tester,
  ) async {
    bool? result;
    var completed = false;

    await tester.pumpWidget(
      _launcher((context) async {
        result = await ConfirmationDialog.show(
          context,
          title: 'Delete cloud backup?',
          message: 'This cannot be undone.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Delete backup',
          isDestructive: true,
        );
        completed = true;
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(completed, isFalse);
    expect(result, isNull);

    await tester.tap(find.text('Delete backup'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isTrue);
    expect(find.text('Delete cloud backup?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destructive confirmation uses the destructive color treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      _launcher((context) async {
        await ConfirmationDialog.show(
          context,
          title: 'Clear parking lot?',
          message: 'All parked thoughts will be removed.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Clear all',
          isDestructive: true,
        );
      }),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear all'),
    );
    final backgroundColor = confirmButton.style?.backgroundColor?.resolve(
      const <WidgetState>{},
    );
    final foregroundColor = confirmButton.style?.foregroundColor?.resolve(
      const <WidgetState>{},
    );

    expect(backgroundColor, const Color(0xFFB3261E));
    expect(foregroundColor, Colors.white);
    expect(tester.takeException(), isNull);
  });
}
