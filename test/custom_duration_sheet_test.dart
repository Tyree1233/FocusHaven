import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/custom_duration_sheet.dart';

Widget _launcher({required Future<void> Function(BuildContext) onOpen}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => onOpen(context),
          child: const Text('Open duration'),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(
  WidgetTester tester, {
  required ValueChanged<Duration?> onResult,
  Duration initialDuration = const Duration(minutes: 7, seconds: 5),
  int maximumMinutes = 180,
}) async {
  await tester.pumpWidget(
    _launcher(
      onOpen: (context) async {
        final result = await showModalBottomSheet<Duration>(
          context: context,
          isScrollControlled: true,
          builder: (_) => CustomDurationSheet(
            sessionLabel: 'Focus',
            sessionColor: const Color(0xFFEF65B7),
            initialDuration: initialDuration,
            maximumMinutes: maximumMinutes,
          ),
        );
        onResult(result);
      },
    ),
  );

  await tester.tap(find.text('Open duration'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('submitting preserves the initial minute and second values', (
    tester,
  ) async {
    Duration? result;

    await _openSheet(tester, onResult: (value) => result = value);

    expect(find.text('Focus duration'), findsOneWidget);
    expect(find.text('Set 07:05'), findsOneWidget);

    await tester.tap(find.text('Set 07:05'));
    await tester.pumpAndSettle();

    expect(result, const Duration(minutes: 7, seconds: 5));
    expect(find.text('Focus duration'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a favorite returns that duration', (tester) async {
    Duration? result;

    await _openSheet(
      tester,
      onResult: (value) => result = value,
      initialDuration: const Duration(minutes: 5, seconds: 30),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '25 min'));
    await tester.pumpAndSettle();

    expect(find.text('Set 25:00'), findsOneWidget);

    await tester.tap(find.text('Set 25:00'));
    await tester.pumpAndSettle();

    expect(result, const Duration(minutes: 25));
    expect(tester.takeException(), isNull);
  });

  testWidgets('maximum duration limits favorites and clamps initial values', (
    tester,
  ) async {
    Duration? result;

    await _openSheet(
      tester,
      onResult: (value) => result = value,
      initialDuration: const Duration(hours: 5),
      maximumMinutes: 20,
    );

    expect(find.widgetWithText(ChoiceChip, '5 min'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '10 min'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '15 min'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '25 min'), findsNothing);
    expect(find.text('Set 20:59'), findsOneWidget);

    await tester.tap(find.text('Set 20:59'));
    await tester.pumpAndSettle();

    expect(result, const Duration(minutes: 20, seconds: 59));
    expect(tester.takeException(), isNull);
  });
}
