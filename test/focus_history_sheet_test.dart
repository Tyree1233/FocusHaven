import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/focus_session.dart';
import 'package:focushaven/widgets/focus_history_sheet.dart';

Widget _app({
  required List<FocusSession> sessions,
  Future<void> Function()? onCopySummary,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: FocusHistorySheet(
        completedSessions: sessions.length,
        weeklyFocusSeconds: 185,
        weeklyFocusSessions: 2,
        lastSevenDaysFocusSeconds: const [0, 0, 0, 60, 0, 125, 0],
        sessions: sessions,
        onCopySummary: onCopySummary ?? () async {},
      ),
    ),
  );
}

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Finder _filterChip(String label) {
  return find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));
}

int _historyItemCount(WidgetTester tester) {
  final listView = tester.widget<ListView>(find.byType(ListView));
  final childCount = listView.childrenDelegate.estimatedChildCount ?? 0;
  return childCount == 0 ? 0 : (childCount + 1) ~/ 2;
}

void main() {
  testWidgets('renders summary and empty history state', (tester) async {
    await _useTallSurface(tester);
    var copyCount = 0;

    await tester.pumpWidget(
      _app(
        sessions: const [],
        onCopySummary: () async {
          copyCount++;
        },
      ),
    );

    expect(find.text('All focus sessions'), findsOneWidget);
    expect(find.text('0 completed sessions'), findsOneWidget);
    expect(find.text('3 minutes • 2 sessions'), findsOneWidget);
    expect(
      find.text('No focus sessions in this time range yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Copy full summary'));
    await tester.pumpAndSettle();

    expect(copyCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes summary copies and contains clipboard failures', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final pendingCopy = Completer<void>();
    var copyCount = 0;

    await tester.pumpWidget(
      _app(
        sessions: const [],
        onCopySummary: () {
          copyCount += 1;
          return pendingCopy.future;
        },
      ),
    );

    final copyAction = find.widgetWithText(TextButton, 'Copy full summary');
    final initialButton = tester.widget<TextButton>(copyAction);
    initialButton.onPressed!.call();
    initialButton.onPressed!.call();
    await tester.pump();

    expect(copyCount, 1);
    expect(tester.widget<TextButton>(copyAction).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingCopy.completeError(StateError('clipboard unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Focus summary could not be copied right now.'),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(copyAction).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders task names, duration labels, and relative dates', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final now = DateTime.now();
    final sessions = [
      FocusSession(
        completedAt: now,
        durationSeconds: 120,
        focusTask: 'Draft report',
      ),
      FocusSession(
        completedAt: now.subtract(const Duration(days: 1)),
        durationSeconds: 65,
      ),
      FocusSession(
        completedAt: now.subtract(const Duration(days: 10)),
        durationSeconds: 30,
        focusTask: 'Older planning',
      ),
    ];

    await tester.pumpWidget(_app(sessions: sessions));

    expect(find.text('Draft report'), findsOneWidget);
    expect(
      find.textContaining('2-minute focus session • Today at'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('1 min 5 sec focus session'),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('1 min 5 sec focus session'), findsOneWidget);
    expect(
      find.textContaining('1 min 5 sec focus session • Yesterday at'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Older planning'),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Older planning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders restored timestamps in the device local time', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final completedAt = DateTime.utc(2026, 1, 2, 2, 15);
    final localCompletedAt = completedAt.toLocal();

    await tester.pumpWidget(
      _app(
        sessions: [
          FocusSession(
            completedAt: completedAt,
            durationSeconds: 60,
            focusTask: 'Restored UTC session',
          ),
        ],
      ),
    );

    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(FocusHistorySheet)),
    );
    final expectedTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localCompletedAt),
    );
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final expectedDate =
        '${months[localCompletedAt.month - 1]} ${localCompletedAt.day}';

    expect(find.text('Restored UTC session'), findsOneWidget);
    expect(
      find.textContaining(
        '1-minute focus session • $expectedDate at $expectedTime',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today and This week filters include only matching sessions', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final now = DateTime.now();
    final sessions = [
      FocusSession(
        completedAt: now,
        durationSeconds: 60,
        focusTask: 'Today task',
      ),
      FocusSession(
        completedAt: now.subtract(const Duration(days: 2)),
        durationSeconds: 60,
        focusTask: 'Week task',
      ),
      FocusSession(
        completedAt: now.subtract(const Duration(days: 10)),
        durationSeconds: 60,
        focusTask: 'Old task',
      ),
    ];

    await tester.pumpWidget(_app(sessions: sessions));

    expect(_historyItemCount(tester), 3);
    expect(find.text('Today task'), findsOneWidget);

    await tester.tap(_filterChip('Today'));
    await tester.pump();

    expect(_historyItemCount(tester), 1);
    expect(find.text('Today task'), findsOneWidget);
    expect(find.text('Week task'), findsNothing);
    expect(find.text('Old task'), findsNothing);

    await tester.tap(_filterChip('This week'));
    await tester.pump();

    expect(_historyItemCount(tester), 2);
    expect(find.text('Today task'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Week task'),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Week task'), findsOneWidget);
    expect(find.text('Old task'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('This week includes the full oldest local calendar day', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final now = DateTime.now().toLocal();
    final oldestDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final sessions = [
      FocusSession(
        completedAt: oldestDay.add(const Duration(minutes: 1)),
        durationSeconds: 60,
        focusTask: 'Oldest included day',
      ),
      FocusSession(
        completedAt: oldestDay.subtract(const Duration(seconds: 1)),
        durationSeconds: 60,
        focusTask: 'Before calendar window',
      ),
    ];

    await tester.pumpWidget(_app(sessions: sessions));
    await tester.tap(_filterChip('This week'));
    await tester.pump();

    expect(_historyItemCount(tester), 1);
    expect(find.text('Oldest included day'), findsOneWidget);
    expect(find.text('Before calendar window'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
