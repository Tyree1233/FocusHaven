import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_interpreter.dart';
import 'package:focushaven/services/haven_planner_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/haven_planner_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<({TimerService timer, FocusQueueService queue})> services() async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    return (timer: timer, queue: queue);
  }

  Widget app(({TimerService timer, FocusQueueService queue}) owned) {
    final now = DateTime.utc(2026, 8, 30, 23);
    var actionId = 0;
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HavenPlannerSheet(
          timerService: owned.timer,
          focusQueueService: owned.queue,
          plannerService: HavenPlannerService(
            clock: () => now,
            idGenerator: () => 'draft-one',
          ),
          interpreter: HavenActionInterpreter(
            clock: () => now,
            idGenerator: () => 'reviewed-${actionId++}',
          ),
          actionClock: () => now,
        ),
      ),
    );
  }

  Future<void> createDraft(
    WidgetTester tester,
    ({TimerService timer, FocusQueueService queue}) owned,
  ) async {
    await tester.pumpWidget(app(owned));
    await tester.enterText(
      find.byKey(const ValueKey('havenPlannerGoal')),
      'Prepare the FocusHaven launch',
    );
    await tester.tap(find.byKey(const ValueKey('createHavenPlannerDraft')));
    await tester.pump();
  }

  testWidgets('draft is transparent and mutates nothing before review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final owned = await services();
    await createDraft(tester, owned);

    expect(
      find.text('Local planner foundation • no remote AI'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('havenPlannerProposalContext')),
      findsOneWidget,
    );
    expect(find.text('Assumptions'), findsOneWidget);
    expect(find.text('Uncertainty: medium'), findsOneWidget);
    expect(
      find.textContaining('Timer and calendar: no changes.'),
      findsOneWidget,
    );
    expect(owned.queue.items, isEmpty);
    expect(owned.timer.isRunning, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('applyHavenPlannerReview')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('accept edit and reject remain independent before exact apply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final owned = await services();
    await createDraft(tester, owned);

    final acceptFirst = find.byKey(
      const ValueKey('havenPlannerAccept-draft-one-task-1'),
    );
    await tester.ensureVisible(acceptFirst);
    await tester.tap(acceptFirst);
    final editSecond = find.byKey(
      const ValueKey('havenPlannerEditChoice-draft-one-task-2'),
    );
    await tester.ensureVisible(editSecond);
    await tester.tap(editSecond);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('havenPlannerEdit-draft-one-task-2')),
      'Review the exact launch checklist',
    );
    for (final key in const <String>[
      'havenPlannerReject-draft-one-task-3',
      'havenPlannerReject-draft-one-session',
      'havenPlannerAccept-draft-one-free-time',
    ]) {
      final choice = find.byKey(ValueKey(key));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
    }
    await tester.pump();

    expect(owned.queue.items, isEmpty);
    final apply = find.byKey(const ValueKey('applyHavenPlannerReview'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(find.text('Add reviewed tasks?'), findsOneWidget);
    final confirmationDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: confirmationDialog,
        matching: find.textContaining('Define done for Prepare'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmationDialog,
        matching: find.textContaining('Review the exact launch checklist'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmationDialog,
        matching: find.textContaining('The timer will not start or change'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirmation-confirm')),
    );
    await tester.pumpAndSettle();

    expect(owned.queue.items.map((item) => item.title), <String>[
      'Define done for Prepare the FocusHaven launch',
      'Review the exact launch checklist',
    ]);
    expect(owned.timer.isRunning, isFalse);
    expect(owned.timer.secondsRemaining, 1500);
    expect(find.textContaining('2 reviewed tasks were added'), findsOneWidget);
  });

  testWidgets('rejecting every item completes with no state change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final owned = await services();
    await createDraft(tester, owned);

    for (final id in const <String>[
      'draft-one-task-1',
      'draft-one-task-2',
      'draft-one-task-3',
      'draft-one-session',
      'draft-one-free-time',
    ]) {
      final reject = find.byKey(ValueKey('havenPlannerReject-$id'));
      await tester.ensureVisible(reject);
      await tester.tap(reject);
      await tester.pump();
    }
    final apply = find.byKey(const ValueKey('applyHavenPlannerReview'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pump();

    expect(find.text('Review complete. Nothing was changed.'), findsOneWidget);
    expect(owned.queue.items, isEmpty);
    expect(owned.timer.isRunning, isFalse);
  });
}
