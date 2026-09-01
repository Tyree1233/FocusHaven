import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/services/voice_transcription_service.dart';
import 'package:focushaven/widgets/haven_action_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<
    ({
      TimerService timer,
      FocusQueueService queue,
      VoiceTranscriptionService voice,
      _HavenVoiceRecognitionAdapter adapter,
    })
  >
  services() async {
    final timer = TimerService();
    final queue = FocusQueueService();
    final adapter = _HavenVoiceRecognitionAdapter();
    final voice = VoiceTranscriptionService(adapter: adapter);
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    addTearDown(voice.dispose);
    return (timer: timer, queue: queue, voice: voice, adapter: adapter);
  }

  Widget app(
    ({
      TimerService timer,
      FocusQueueService queue,
      VoiceTranscriptionService voice,
      _HavenVoiceRecognitionAdapter adapter,
    })
    owned, {
    double textScale = 1,
    double width = 600,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
              voiceTranscriptionService: owned.voice,
              onOpenSurface: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the private input boundary and typed review step', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final owned = await services();
    await tester.pumpWidget(app(owned));

    expect(
      find.text('Typed or voice transcript • local review • no remote AI'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'add task: Review the launch checklist',
    );
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsOneWidget);
    expect(find.text('Typed request • reviewed locally'), findsOneWidget);
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
          'Reviewed Haven action. Typed request reviewed locally. '
          'Draft one Focus Queue item. '
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

    final execute = find.byKey(const ValueKey('executeHavenAction'));
    await tester.ensureVisible(execute);
    await tester.pumpAndSettle();
    await tester.tap(execute);
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
      find.text('Typed or voice transcript • local review • no remote AI'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reviewHavenAction')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voice stays dormant until the action disclosure is confirmed', (
    tester,
  ) async {
    final owned = await services();
    owned.voice.acknowledgeDisclosure();
    await tester.pumpWidget(app(owned));

    expect(find.byKey(const ValueKey('havenActionVoiceInput')), findsOneWidget);
    expect(owned.adapter.initializeCalls, 0);
    expect(owned.adapter.listenCalls, 0);

    await tester.tap(find.byKey(const ValueKey('havenActionVoiceInput')));
    await tester.pumpAndSettle();

    expect(find.text('Use voice for Haven actions?'), findsOneWidget);
    expect(find.textContaining('keeps no raw audio'), findsOneWidget);
    expect(find.textContaining('Nothing is reviewed or run'), findsOneWidget);
    expect(owned.adapter.initializeCalls, 0);

    await tester.tap(find.byKey(const ValueKey('confirmation-cancel')));
    await tester.pumpAndSettle();

    expect(owned.adapter.initializeCalls, 0);
    expect(owned.adapter.listenCalls, 0);
    expect(owned.timer.isRunning, isFalse);
  });

  testWidgets('voice creates only an editable draft before both action gates', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));

    await tester.tap(find.byKey(const ValueKey('havenActionVoiceInput')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmation-confirm')));
    await tester.pumpAndSettle();

    expect(owned.adapter.listenCalls, 1);
    expect(
      find.byKey(const ValueKey('havenActionVoiceListening')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(owned.timer.isRunning, isFalse);

    owned.adapter.emitResult('start focus');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('havenActionInput')))
          .controller!
          .text,
      'start focus',
    );
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(owned.timer.isRunning, isFalse);

    await tester.tap(find.byKey(const ValueKey('stopHavenActionVoice')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voice draft ready.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discardHavenActionVoice')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('havenActionInput')),
      'please start focus',
    );
    await tester.tap(find.byKey(const ValueKey('reviewHavenAction')));
    await tester.pump();

    expect(find.byKey(const ValueKey('havenActionProposal')), findsOneWidget);
    expect(find.text('Voice transcript • reviewed locally'), findsOneWidget);
    expect(owned.timer.isRunning, isFalse);

    final execute = find.byKey(const ValueKey('executeHavenAction'));
    await tester.ensureVisible(execute);
    await tester.pumpAndSettle();
    await tester.tap(execute);
    await tester.pumpAndSettle();

    expect(owned.timer.isRunning, isTrue);
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);

    owned.timer.pause();
    await tester.pump();
    expect(owned.timer.isRunning, isFalse);
  });

  testWidgets('discard restores the exact typed draft without a proposal', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));
    final input = find.byKey(const ValueKey('havenActionInput'));
    await tester.enterText(input, 'Keep this typed draft');

    await tester.tap(find.byKey(const ValueKey('havenActionVoiceInput')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmation-confirm')));
    await tester.pumpAndSettle();
    owned.adapter.emitResult('pause');
    await tester.pump();
    expect(
      tester.widget<TextField>(input).controller!.text,
      'Keep this typed draft pause',
    );

    await tester.tap(find.byKey(const ValueKey('discardHavenActionVoice')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(input).controller!.text,
      'Keep this typed draft',
    );
    expect(find.byKey(const ValueKey('havenActionProposal')), findsNothing);
    expect(owned.timer.isRunning, isFalse);
    expect(owned.adapter.cancelCalls, 1);
  });

  testWidgets('protected spoken words cannot create an execution control', (
    tester,
  ) async {
    final owned = await services();
    await tester.pumpWidget(app(owned));

    await tester.tap(find.byKey(const ValueKey('havenActionVoiceInput')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmation-confirm')));
    await tester.pumpAndSettle();
    owned.adapter.emitResult('delete my account');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stopHavenActionVoice')));
    await tester.pumpAndSettle();
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

class _HavenVoiceRecognitionAdapter implements VoiceRecognitionAdapter {
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool listening = false;
  VoiceRecognitionResultCallback? _onResult;

  @override
  bool get isListening => listening;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required VoiceRecognitionStatusCallback onStatus,
    required VoiceRecognitionErrorCallback onError,
  }) async {
    initializeCalls += 1;
    return true;
  }

  @override
  Future<void> listen({
    required VoiceRecognitionResultCallback onResult,
  }) async {
    listenCalls += 1;
    _onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    listening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    listening = false;
  }

  void emitResult(String transcript) {
    _onResult?.call(transcript, false);
  }
}
