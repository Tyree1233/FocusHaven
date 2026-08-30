import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/haven_action_sheet.dart';
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

  Widget app(({TimerService timer, FocusQueueService queue}) owned) =>
      MaterialApp(
        home: Scaffold(
          body: HavenActionSheet(
            timerService: owned.timer,
            focusQueueService: owned.queue,
            onOpenSurface: (_) async {},
          ),
        ),
      );

  testWidgets('shows the typed-only privacy boundary and review step', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));

    expect(
      find.text('Typed locally • no microphone • no remote AI'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'add task: Review the launch checklist',
    );
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsOneWidget);
    expect(find.text('Confirm exact action'), findsOneWidget);
    expect(owned.queue.items, isEmpty);

    await tester.tap(find.byKey(const ValueKey('executeHavenAction')));
    await tester.pumpAndSettle();

    expect(owned.queue.items.single.title, 'Review the launch checklist');
    expect(
      find.text('The reviewed item was added to Focus Queue.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects protected commands without presenting execution', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));
    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'delete my account',
    );
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(find.byKey(const ValueKey('executeHavenAction')), findsNothing);
    expect(
      find.text(
        'That action stays in its protected screen and cannot be run here.',
      ),
      findsOneWidget,
    );
  });
}
