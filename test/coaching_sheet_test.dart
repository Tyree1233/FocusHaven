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
  CoachingConversationSave? saveConversation,
  CoachingEnhancedPreferenceSave? saveEnhancedPreference,
}) async {
  final coach = CoachingService(
    responder: responder,
    enhancedResponder: enhancedResponder,
    saveConversation: saveConversation,
    saveEnhancedPreference: saveEnhancedPreference,
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

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('coach-prompt-Be gentle with me')),
      findsOneWidget,
    );
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

  testWidgets('contextual quick replies continue through the send path', (
    tester,
  ) async {
    final responder = _RecordingResponder('Choose one clear next action.');
    final coach = await _createCoach(responder: responder);

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'Help me make a plan.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coach-quick-replies')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Break it down')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-I’m still stuck')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Please just listen')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('coach-quick-reply-Break it down')),
    );
    await tester.pumpAndSettle();

    expect(responder.calls, 2);
    expect(responder.lastMessage, 'Break it down');
    expect(responder.lastConversation, hasLength(3));
    expect(coach.messages[2].text, 'Break it down');
    expect(tester.takeException(), isNull);
  });

  testWidgets('break coaching offers a one-tap gentle return', (tester) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Review the launch notes',
          isTimerRunning: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I need a break.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.textContaining('real five-minute break'), findsOneWidget);
    final returnReply = find.byKey(
      const ValueKey('coach-quick-reply-I’m back after a break'),
    );
    expect(returnReply, findsOneWidget);

    await tester.tap(returnReply);
    await tester.pumpAndSettle();

    expect(find.text('I’m back after a break'), findsOneWidget);
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-I did the first step')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('safety coaching never offers routine quick replies', (
    tester,
  ) async {
    final coach = await _createCoach();

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I want to kill myself.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your safety matters'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives space without prompts until the user returns', (
    tester,
  ) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Finish the launch plan',
          isTimerRunning: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I need space.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.textContaining('I’ll stop here'), findsOneWidget);
    expect(find.textContaining('nothing to prove'), findsOneWidget);
    expect(find.textContaining('Finish the launch plan'), findsNothing);
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I’m back.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.text('I’m back.'), findsOneWidget);
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-I did the first step')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('repairs a mismatch with one-tap recalibration choices', (
    tester,
  ) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Finish the launch plan',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'That’s not what I meant.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(find.textContaining('I misunderstood'), findsOneWidget);
    expect(find.textContaining('I’m sorry'), findsOneWidget);
    expect(
      find.textContaining('without making you repeat everything'),
      findsOneWidget,
    );
    expect(find.textContaining('Finish the launch plan'), findsNothing);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Please just listen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Be gentle with me')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Hold me accountable')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('coach-quick-reply-Please just listen')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Please just listen'), findsOneWidget);
    expect(
      find.textContaining('listen without trying to fix it'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a quiet one-question reflection mode', (tester) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Choose the next project',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final prompt = find.byKey(
      const ValueKey('coach-prompt-Help me think this through'),
    );
    expect(prompt, findsOneWidget);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('Help me think this through'), findsOneWidget);
    expect(find.textContaining('Let’s slow this down'), findsOneWidget);
    expect(
      find.textContaining('most important to understand first'),
      findsOneWidget,
    );
    expect(find.textContaining('Choose the next project'), findsNothing);
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'I am afraid I will disappoint everyone.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(
      find.text('I am afraid I will disappoint everyone.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('fear sounds like it is carrying'),
      findsOneWidget,
    );
    expect(find.textContaining('trying to protect you from'), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers one-tap gentle support with matching follow-ups', (
    tester,
  ) async {
    final coach = await _createCoach();

    await tester.pumpWidget(
      _app(
        coach,
        coachingContext: const CoachingContext(
          focusTask: 'Send the difficult message',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    final prompt = find.byKey(const ValueKey('coach-prompt-Be gentle with me'));
    expect(prompt, findsOneWidget);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(find.text('Be gentle with me'), findsOneWidget);
    expect(find.textContaining('I’ll keep this gentle'), findsOneWidget);
    expect(find.textContaining('Send the difficult message'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Break it down')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Please just listen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-I need a break')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Be gentle with me')),
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

    final gentleReply = find.byKey(
      const ValueKey('coach-quick-reply-Be gentle with me'),
    );
    expect(gentleReply, findsOneWidget);
    tester.widget<ActionChip>(gentleReply).onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Be gentle with me'), findsOneWidget);
    expect(find.textContaining('I’ll keep this gentle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Break it down')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-quick-reply-Hold me accountable')),
      findsNothing,
    );
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

  testWidgets('disables controls during an external private storage action', (
    tester,
  ) async {
    final saveStarted = Completer<void>();
    final allowSave = Completer<void>();
    final coach = await _createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      saveEnhancedPreference: (preferences, enabled) async {
        saveStarted.complete();
        await allowSave.future;
        return preferences.setBool('enhancedCoachingEnabled', enabled);
      },
    );

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'Keep this draft private.',
    );
    await tester.pump();

    final enabling = coach.setEnhancedCoachingEnabled(true);
    await saveStarted.future;
    await tester.pump();

    expect(coach.isManagingPrivateData, isTrue);
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
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('coach-enhanced-ai-toggle')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<ActionChip>(
            find.byKey(const ValueKey('coach-prompt-I’m stuck—help me start')),
          )
          .onPressed,
      isNull,
    );

    allowSave.complete();
    expect(await enabling, isTrue);
    await tester.pumpAndSettle();

    expect(coach.isManagingPrivateData, isFalse);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('coach-message-input')))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('coach-enhanced-ai-toggle')),
          )
          .value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains an enhanced allowance handoff to local coaching', (
    tester,
  ) async {
    final localResponder = _RecordingResponder('Private local guidance.');
    final coach = await _createCoach(
      responder: localResponder,
      enhancedResponder: ResilientCoachingResponder(
        primary: const _FallbackResponder(
          CoachingFallbackReason.allowanceReached,
        ),
        fallback: localResponder,
      ),
    );
    await coach.setEnhancedCoachingEnabled(true);

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('coach-message-input')),
      'Help me plan today.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(coach.messages.map((message) => message.text), [
      'Help me plan today.',
      'Private local guidance.',
    ]);
    expect(find.byKey(const ValueKey('coach-fallback-notice')), findsOneWidget);
    expect(
      find.text(
        'Your enhanced AI allowance has been reached for this month. '
        'Your private local coach answered instead.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('could not respond right now'), findsNothing);
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);
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
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows contained coach failures without losing the message', (
    tester,
  ) async {
    final responder = _RetryResponder('Use one small planning step.');
    final coach = await _createCoach(responder: responder);

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
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('coach-message-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byKey(const ValueKey('coach-quick-replies')), findsNothing);
    final retry = find.byKey(const ValueKey('coach-retry-response'));
    expect(retry, findsOneWidget);

    const nextDraft = 'Please help with the next step too.';
    final input = find.byKey(const ValueKey('coach-message-input'));
    await tester.enterText(input, nextDraft);
    await tester.pump();
    expect(tester.widget<TextField>(input).enabled, isTrue);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNull,
    );

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(responder.calls, 2);
    expect(coach.messages.map((entry) => entry.text), [
      'Please help me plan.',
      'Use one small planning step.',
    ]);
    expect(retry, findsNothing);
    expect(
      find.text('Your coach could not respond right now. Please retry.'),
      findsNothing,
    );
    expect(tester.widget<TextField>(input).controller!.text, nextDraft);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores a draft that private storage never committed', (
    tester,
  ) async {
    final coach = await _createCoach(saveConversation: (_, _) async => false);

    await tester.pumpWidget(_app(coach));
    await tester.pumpAndSettle();
    const draft = 'Please keep this draft available.';
    final input = find.byKey(const ValueKey('coach-message-input'));
    await tester.enterText(input, draft);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coach-send-message')));
    await tester.pumpAndSettle();

    expect(coach.messages, isEmpty);
    expect(tester.widget<TextField>(input).controller!.text, draft);
    expect(
      find.text('Your coach could not respond right now. Please retry.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('coach-send-message')))
          .onPressed,
      isNotNull,
    );
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

class _RetryResponder implements CoachingResponder {
  _RetryResponder(this.response);

  final String response;
  int calls = 0;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    if (calls == 1) throw StateError('coach unavailable');
    return response;
  }
}

class _FallbackResponder implements CoachingResponder {
  const _FallbackResponder(this.reason);

  final CoachingFallbackReason reason;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) => Future.error(CoachingFallbackException(reason));
}
