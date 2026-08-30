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

  Widget app(
    ({TimerService timer, FocusQueueService queue}) owned, {
    double textScale = 1,
    double width = 600,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: HavenActionSheet(
              timerService: owned.timer,
              focusQueueService: owned.queue,
              onOpenSurface: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the typed-only privacy boundary and review step', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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

    final execute = find.byKey(const ValueKey('executeHavenAction'));
    await tester.ensureVisible(execute);
    await tester.pumpAndSettle();
    await tester.tap(execute);
    await tester.pumpAndSettle();

    expect(owned.queue.items.single.title, 'Review the launch checklist');
    expect(
      find.text('The reviewed item was added to Focus Queue.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(find.byKey(const ValueKey('executeHavenAction')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('havenActionInput')))
          .controller
          ?.text,
      isEmpty,
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

  testWidgets('announces the exact reviewed action and available choices', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final owned = await services();
      await tester.pumpWidget(app(owned));

      await tester.enterText(
        find.byKey(const ValueKey('havenActionInput')),
        'add task: Review notes',
      );
      await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          'Reviewed Haven action. Draft one Focus Queue item. '
          'Add “Review notes” to the private Focus Queue after confirmation. '
          'Saved local edit • confirmation required. Confirmation is required. '
          'Choose Confirm exact action to continue, or Change request to edit.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('changeHavenAction')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('change request preserves text and restores input focus', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));
    final input = find.byKey(const ValueKey('havenActionInput'));

    await tester.enterText(input, 'add task: Edit this first');
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('changeHavenAction')));
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(owned.queue.items, isEmpty);
    final textField = tester.widget<TextField>(input);
    expect(textField.controller?.text, 'add task: Edit this first');
    expect(textField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('consumed stale proposals cannot be executed twice', (
    tester,
  ) async {
    final owned = await services();
    owned.timer.start();
    await tester.pumpWidget(app(owned));

    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'add 5 minutes',
    );
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();
    owned.timer.pause();
    await tester.tap(find.byKey(const ValueKey('executeHavenAction')));
    await tester.pumpAndSettle();

    expect(
      find.text('The timer or queue changed. Review a fresh proposal.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(find.byKey(const ValueKey('executeHavenAction')), findsNothing);
    expect(owned.timer.totalSessionSeconds, 1500);
  });

  testWidgets('keyboard submission opens the same review boundary', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));

    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'add task: Keyboard review',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsOneWidget);
    expect(find.text('Confirm exact action'), findsOneWidget);
    expect(owned.queue.items, isEmpty);
  });

  testWidgets('remains usable at large text on a narrow surface', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned, textScale: 2, width: 280));

    expect(find.text('Haven actions'), findsOneWidget);
    expect(
      find.text('Typed locally • no microphone • no remote AI'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reviewHavenAction')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
