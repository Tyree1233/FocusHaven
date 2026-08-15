import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/coaching_service.dart';
import 'package:focushaven/widgets/coaching_sheet.dart';

Widget _app(CoachingService coach, {CoachingContext? coachingContext}) {
  return ProviderScope(
    overrides: [coachingServiceProvider.overrideWith((ref) => coach)],
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF16FBA),
          surface: Color(0xFF352260),
        ),
      ),
      home: Scaffold(
        body: CoachingSheet(
          contextBuilder: () => coachingContext ?? const CoachingContext(),
        ),
      ),
    ),
  );
}

Future<CoachingService> _createCoach({
  CoachingResponder? responder,
  CoachingResponder? enhancedResponder,
}) async {
  final coach = CoachingService(
    responder: responder,
    enhancedResponder: enhancedResponder,
  );
  await coach.initialized;
  return coach;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders a private empty coaching experience', (tester) async {
    final coach = await _createCoach();

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();

    expect(find.text('Focus Coach'), findsOneWidget);
    expect(find.text('Private guidance saved on this device'), findsOneWidget);
    expect(
      find.text('You don’t have to figure out the next step alone.'),
      findsOneWidget,
    );
    expect(find.textContaining('listening without fixing'), findsOneWidget);
    expect(find.text('I’m stuck—help me start'), findsOneWidget);
    expect(find.text('I’m feeling overwhelmed'), findsOneWidget);
    expect(find.text('What should I do next?'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-message-input')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends a typed message with the current FocusHaven context', (
    tester,
  ) async {
    final responder = _RecordingResponder('Let’s make the first step smaller.');
    final coach = await _createCoach(responder: responder);
    const coachingContext = CoachingContext(
      focusTask: 'Draft the launch plan',
      focusProfile: 'Deep worker',
      todayFocusMinutes: 25,
      dailyGoalMinutes: 60,
      queueRemaining: 2,
      nextQueueTask: 'Review launch metrics',
      recentMood: 'Focused',
      parkedThoughtCount: 1,
      isTimerRunning: true,
    );

    await tester.pumpWidget(_app(coach, coachingContext: coachingContext));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I need a smaller first step.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(responder.calls, 1);
    expect(responder.lastMessage, 'I need a smaller first step.');
    expect(responder.lastContext, same(coachingContext));
    expect(responder.lastConversation, hasLength(1));
    expect(responder.lastConversation!.single.role, CoachingMessageRole.user);
    expect(find.text('I need a smaller first step.'), findsOneWidget);
    expect(find.text('Let’s make the first step smaller.'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Focus Coach'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starter prompts produce contextual local coaching', (
    tester,
  ) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Prepare the presentation',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I’m feeling overwhelmed'));
    await tester.pumpAndSettle();

    expect(find.text('I’m feeling overwhelmed'), findsOneWidget);
    expect(find.textContaining('a lot to hold at once'), findsOneWidget);
    expect(find.textContaining('Prepare the presentation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a one-tap listening mode', (tester) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Finish the presentation',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final prompt = find.text('Please just listen');
    expect(prompt, findsOneWidget);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('Please just listen'), findsOneWidget);
    expect(
      find.textContaining('do not have to turn this into a plan'),
      findsOneWidget,
    );
    expect(
      find.textContaining('listen without trying to fix it'),
      findsOneWidget,
    );
    expect(find.textContaining('Finish the presentation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers one-tap direct accountability', (tester) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Write the release notes',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    final prompt = find.text('Hold me accountable');
    expect(prompt, findsOneWidget);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('Hold me accountable'), findsOneWidget);
    expect(
      find.textContaining('Direct version, without shame'),
      findsOneWidget,
    );
    expect(find.textContaining('Write the release notes'), findsOneWidget);
    expect(find.textContaining('ten-minute focus round'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enables enhanced coaching only after informed confirmation', (
    tester,
  ) async {
    final coach = await _createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
    );

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('coach-enhanced-ai-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('Off · coaching stays on this device.'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Use enhanced AI coaching?'), findsOneWidget);
    expect(
      find.textContaining('up to 12 recent coaching messages'),
      findsOneWidget,
    );
    expect(
      find.textContaining('sent securely through Firebase'),
      findsOneWidget,
    );
    expect(find.textContaining('up to 30 days by default'), findsOneWidget);
    expect(coach.enhancedCoachingEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey<String>('confirmation-cancel')));
    await tester.pumpAndSettle();

    expect(coach.enhancedCoachingEnabled, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey<String>('confirmation-confirm')),
    );
    await tester.pumpAndSettle();

    expect(coach.enhancedCoachingEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(
      find.text('Enhanced AI · conversation saved on this device'),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('Use enhanced AI coaching?'), findsNothing);
    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping prompt submissions while thinking', (
    tester,
  ) async {
    final responder = _PendingResponder();
    final coach = await _createCoach(responder: responder);

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    final promptFinder = find.widgetWithText(
      ActionChip,
      'I’m stuck—help me start',
    );
    final prompt = tester.widget<ActionChip>(promptFinder);

    prompt.onPressed!.call();
    prompt.onPressed!.call();
    await tester.pump();
    await responder.invoked.future;
    await tester.pump();

    expect(responder.calls, 1);
    expect(find.text('Thinking…'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('coach-message-input')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNull,
    );

    responder.response.complete('Choose one action that takes two minutes.');
    await tester.pumpAndSettle();

    expect(find.text('Thinking…'), findsNothing);
    expect(
      find.text('Choose one action that takes two minutes.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows contained coach failures without losing the message', (
    tester,
  ) async {
    final coach = await _createCoach(responder: const _FailingResponder());

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'Please help me plan.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.text('Please help me plan.'), findsOneWidget);
    expect(
      find.text('Your coach could not respond right now. Please retry.'),
      findsOneWidget,
    );
    expect(coach.messages, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears a saved conversation only after confirmation', (
    tester,
  ) async {
    final coach = await _createCoach(
      responder: _RecordingResponder('One small step is enough.'),
    );
    await coach.send('Help me begin.', const CoachingContext());

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear coaching conversation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Clear coaching conversation?'), findsOneWidget);
    expect(coach.messages, hasLength(2));

    await tester.tap(
      find.byKey(const ValueKey<String>('confirmation-confirm')),
    );
    await tester.pumpAndSettle();

    expect(coach.messages, isEmpty);
    expect(find.text('I’m stuck—help me start'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingResponder implements CoachingResponder {
  _RecordingResponder(this.response);

  final String response;
  int calls = 0;
  String? lastMessage;
  CoachingContext? lastContext;
  List<CoachingMessage>? lastConversation;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    lastMessage = message;
    lastContext = context;
    lastConversation = conversation;
    return response;
  }
}

class _PendingResponder implements CoachingResponder {
  final invoked = Completer<void>();
  final response = Completer<String>();
  int calls = 0;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    if (!invoked.isCompleted) invoked.complete();
    return response.future;
  }
}

class _FailingResponder implements CoachingResponder {
  const _FailingResponder();

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) => Future.error(StateError('coach unavailable'));
}
