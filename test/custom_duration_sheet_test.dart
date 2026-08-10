import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/widgets/custom_duration_sheet.dart';

class _CountingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

Widget _launcher({
  required Future<void> Function(BuildContext) onOpen,
  NavigatorObserver? observer,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    navigatorObservers: [?observer],
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
  NavigatorObserver? observer,
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
      observer: observer,
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

  testWidgets('serializes submission and locks duration input while closing', (
    tester,
  ) async {
    final observer = _CountingNavigatorObserver();
    Duration? result;
    await _openSheet(
      tester,
      onResult: (value) => result = value,
      observer: observer,
    );
    final submitFinder = find.byKey(
      const ValueKey<String>('custom-duration-submit'),
    );
    final favoriteFinder = find.byKey(
      const ValueKey<String>('custom-duration-favorite-25'),
    );
    final submit = tester.widget<FilledButton>(submitFinder).onPressed!;

    submit();
    submit();
    await tester.pump();

    expect(observer.popCount, 1);
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);
    expect(tester.widget<ChoiceChip>(favoriteFinder).onSelected, isNull);
    final pickers = tester
        .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
        .toList(growable: false);
    expect(pickers, hasLength(2));
    expect(
      pickers.every((picker) => picker.onSelectedItemChanged == null),
      isTrue,
    );

    await tester.pumpAndSettle();

    expect(result, const Duration(minutes: 7, seconds: 5));
    expect(find.text('Focus duration'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
