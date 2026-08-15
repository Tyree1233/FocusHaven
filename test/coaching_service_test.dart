import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/services/coaching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CoachingService> createCoach({
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

  test('shares only normalized coaching context', () {
    const context = CoachingContext(
      focusTask: '  Write launch plan  ',
      focusProfile: '  Deep worker ',
      todayFocusMinutes: 35,
      dailyGoalMinutes: 60,
      queueRemaining: 2,
      nextQueueTask: '  Review metrics ',
      recentMood: '  hopeful ',
      parkedThoughtCount: 3,
      isTimerRunning: true,
    );

    expect(context.toPromptData(), {
      'focusTask': 'Write launch plan',
      'focusProfile': 'Deep worker',
      'todayFocusMinutes': 35,
      'dailyGoalMinutes': 60,
      'queueRemaining': 2,
      'nextQueueTask': 'Review metrics',
      'recentMood': 'hopeful',
      'parkedThoughtCount': 3,
      'isTimerRunning': true,
    });
    expect(
      const CoachingContext().toPromptData(),
      isNot(contains('focusTask')),
    );
  });

  test('responds to overwhelm with empathy and a concrete next step', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I feel overwhelmed and cannot start.',
      context: const CoachingContext(focusTask: 'Write launch plan'),
      conversation: const [],
    );

    expect(response, contains('a lot to hold'));
    expect(response, contains('Write launch plan'));
    expect(response, contains('two minutes'));
    expect(response, contains('three tiny steps'));
  });

  test('puts immediate safety ahead of productivity coaching', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I want to kill myself.',
      context: const CoachingContext(focusTask: 'Finish the report'),
      conversation: const [],
    );

    expect(response, contains('Your safety matters'));
    expect(response, contains('emergency services'));
    expect(response, contains('someone you trust'));
    expect(response, contains('not a substitute for crisis care'));
    expect(response, isNot(contains('Finish the report')));
  });

  test('recognizes broader immediate safety language locally', () async {
    const responder = LocalCoachingResponder();

    for (final message in const [
      'I wish I were dead.',
      'There is no reason to live.',
      'I am thinking about taking my life.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: const CoachingContext(focusTask: 'Keep working'),
        conversation: const [],
      );

      expect(response, contains('Your safety matters'));
      expect(response, contains('someone you trust'));
      expect(response, isNot(contains('Keep working')));
    }
  });

  test('responds to setbacks without turning them into identity', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I tried, but I am still stuck.',
      context: const CoachingContext(focusTask: 'Outline the proposal'),
      conversation: const [],
    );

    expect(response, contains('already made an effort'));
    expect(response, contains('information, not proof that you failed'));
    expect(response, contains('Outline the proposal'));
    expect(response, contains('one reset'));
  });

  test(
    'meets self-criticism and perfectionism with specific reframes',
    () async {
      const responder = LocalCoachingResponder();

      final selfCriticism = await responder.respond(
        message: 'I am lazy. What is wrong with me?',
        context: const CoachingContext(focusTask: 'Write the introduction'),
        conversation: const [],
      );
      final perfectionism = await responder.respond(
        message: 'I am afraid it will be bad and not good enough.',
        context: const CoachingContext(focusTask: 'Design the first screen'),
        conversation: const [],
      );

      expect(selfCriticism, contains('not your identity'));
      expect(selfCriticism, contains('clarity, energy, or fear'));
      expect(perfectionism, contains('rough version'));
      expect(perfectionism, contains('Design the first screen'));
      expect(perfectionism, contains('good enough for this session'));
    },
  );

  test('turns indecision and deadline pressure into bounded choices', () async {
    const responder = LocalCoachingResponder();

    final decision = await responder.respond(
      message: 'I cannot decide. There are too many options.',
      context: const CoachingContext(
        focusTask: 'Prepare the launch email',
        queueRemaining: 4,
      ),
      conversation: const [],
    );
    final deadline = await responder.respond(
      message: 'I am running out of time before the deadline.',
      context: const CoachingContext(focusTask: 'Submit the application'),
      conversation: const [],
    );

    expect(decision, contains('4 items waiting'));
    expect(decision, contains('one short trial round'));
    expect(deadline, contains('smallest acceptable outcome'));
    expect(deadline, contains('Submit the application'));
    expect(deadline, contains('What can safely be left out?'));
  });

  test('continues a coaching thread with concrete smaller steps', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'coach-1',
        role: CoachingMessageRole.coach,
        text: 'Want to break it into smaller steps?',
        createdAt: DateTime.utc(2026, 8, 15),
      ),
    ];

    final response = await responder.respond(
      message: 'Yes please, break it down.',
      context: const CoachingContext(focusTask: 'Plan the workshop'),
      conversation: conversation,
    );

    expect(response, contains('step we were discussing'));
    expect(response, contains('Plan the workshop'));
    expect(response, contains('rough pass for five minutes'));
    expect(response, contains('Do only the first step right now'));
  });

  test('encourages recovery after the daily focus goal is met', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I am exhausted and have no energy.',
      context: const CoachingContext(
        todayFocusMinutes: 75,
        dailyGoalMinutes: 60,
      ),
      conversation: const [],
    );

    expect(response, contains('already met today’s focus goal'));
    expect(response, contains('Rest is not falling behind'));
  });

  test('falls back locally when a primary coach fails or is empty', () async {
    const context = CoachingContext(focusTask: 'Draft release notes');
    final failureFallback = ResilientCoachingResponder(
      primary: _CallbackResponder((_) => throw StateError('offline')),
      fallback: const LocalCoachingResponder(),
    );
    final emptyFallback = ResilientCoachingResponder(
      primary: _CallbackResponder((_) async => '   '),
      fallback: const LocalCoachingResponder(),
    );

    final failedResponse = await failureFallback.respond(
      message: 'I am stuck.',
      context: context,
      conversation: const [],
    );
    final emptyResponse = await emptyFallback.respond(
      message: 'What should I do next?',
      context: context,
      conversation: const [],
    );

    expect(failedResponse, contains('Draft release notes'));
    expect(failedResponse, contains('five minutes'));
    expect(emptyResponse, contains('Start with'));
    expect(emptyResponse, contains('Draft release notes'));
  });

  test('enhanced coaching requires opt-in and persists the choice', () async {
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
    );

    expect(coach.enhancedCoachingAvailable, isTrue);
    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(await coach.send('Help me begin.', const CoachingContext()), isTrue);
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 0);

    expect(await coach.setEnhancedCoachingEnabled(true), isTrue);
    expect(coach.enhancedCoachingEnabled, isTrue);
    expect(
      await coach.send('Help me continue.', const CoachingContext()),
      isTrue,
    );
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 1);
    coach.dispose();

    final restoredEnhancedResponder = _RecordingResponder(
      'Restored enhanced guidance.',
    );
    final restoredCoach = await createCoach(
      enhancedResponder: restoredEnhancedResponder,
    );
    addTearDown(restoredCoach.dispose);

    expect(restoredCoach.enhancedCoachingEnabled, isTrue);
    expect(
      await restoredCoach.send('Help me finish.', const CoachingContext()),
      isTrue,
    );
    expect(restoredEnhancedResponder.calls, 1);
  });

  test('keeps immediate safety concerns on the local responder', () async {
    final enhancedResponder = _RecordingResponder(
      'This remote response must not be used.',
    );
    final coach = await createCoach(enhancedResponder: enhancedResponder);
    addTearDown(coach.dispose);
    await coach.setEnhancedCoachingEnabled(true);

    expect(
      await coach.send(
        'I want to kill myself.',
        const CoachingContext(focusTask: 'Finish the report'),
      ),
      isTrue,
    );

    expect(enhancedResponder.calls, 0);
    expect(coach.messages.last.text, contains('Your safety matters'));
    expect(coach.messages.last.text, contains('emergency services'));
    expect(coach.messages.last.text, isNot(contains('Finish the report')));
  });

  test(
    'conversation clearing preserves consent until all local data clears',
    () async {
      final coach = await createCoach(
        enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      );
      addTearDown(coach.dispose);
      await coach.setEnhancedCoachingEnabled(true);
      await coach.send('Help me start.', const CoachingContext());

      await coach.clearConversation();

      expect(coach.messages, isEmpty);
      expect(coach.enhancedCoachingEnabled, isTrue);
      var preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);

      await coach.clearLocalData();

      expect(coach.enhancedCoachingEnabled, isFalse);
      preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);
    },
  );

  test('serializes overlapping coaching requests', () async {
    final responder = _PendingResponder();
    final coach = await createCoach(responder: responder);
    addTearDown(coach.dispose);
    var notifications = 0;
    coach.addListener(() => notifications += 1);

    final firstSend = coach.send(
      '  Help   me start  ',
      const CoachingContext(focusTask: 'Plan the week'),
    );
    await responder.invoked.future;

    expect(coach.isResponding, isTrue);
    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.text, 'Help me start');
    expect(
      await coach.send('Send this twice', const CoachingContext()),
      isFalse,
    );
    expect(responder.calls, 1);

    responder.response.complete('Start with one small step.');

    expect(await firstSend, isTrue);
    expect(coach.isResponding, isFalse);
    expect(coach.messages, hasLength(2));
    expect(coach.messages.last.role, CoachingMessageRole.coach);
    expect(coach.messages.last.text, 'Start with one small step.');
    expect(notifications, 2);
  });

  test('persists and clears a private local conversation', () async {
    final firstCoach = await createCoach(
      responder: _CallbackResponder((_) async => 'Try the first paragraph.'),
    );
    expect(
      await firstCoach.send(
        'I am stuck on the introduction.',
        const CoachingContext(),
      ),
      isTrue,
    );
    firstCoach.dispose();

    final restoredCoach = await createCoach();
    addTearDown(restoredCoach.dispose);

    expect(restoredCoach.messages, hasLength(2));
    expect(restoredCoach.messages.first.role, CoachingMessageRole.user);
    expect(restoredCoach.messages.last.role, CoachingMessageRole.coach);

    await restoredCoach.clearLocalData();

    expect(restoredCoach.messages, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isFalse);
  });

  test('repairs damaged saved messages without losing valid history', () async {
    final validMessage = CoachingMessage(
      id: 'valid-1',
      role: CoachingMessageRole.user,
      text: '  Keep this message.  ',
      createdAt: DateTime.utc(2026, 8, 10),
    ).toJson();
    SharedPreferences.setMockInitialValues({
      'coachingConversation': jsonEncode([
        validMessage,
        validMessage,
        {'id': 'bad-role', 'role': 'system', 'text': 'No', 'createdAt': 'now'},
        'wrong shape',
      ]),
    });

    final coach = await createCoach();
    addTearDown(coach.dispose);

    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.id, 'valid-1');
    expect(coach.messages.single.text, 'Keep this message.');

    final preferences = await SharedPreferences.getInstance();
    final repaired =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(repaired, hasLength(1));
  });

  test('keeps only the newest forty saved messages', () async {
    final savedMessages = List.generate(
      45,
      (index) => CoachingMessage(
        id: '$index',
        role: index.isEven
            ? CoachingMessageRole.user
            : CoachingMessageRole.coach,
        text: 'Message $index',
        createdAt: DateTime.utc(2026, 8, 10).add(Duration(minutes: index)),
      ).toJson(),
    );
    SharedPreferences.setMockInitialValues({
      'coachingConversation': jsonEncode(savedMessages),
    });

    final coach = await createCoach();
    addTearDown(coach.dispose);

    expect(coach.messages, hasLength(40));
    expect(coach.messages.first.id, '5');
    expect(coach.messages.last.id, '44');
  });

  test('initialization and sends are safe after disposal', () async {
    final coach = CoachingService();

    coach.dispose();

    await expectLater(coach.initialized, completes);
    expect(
      await coach.send('Do not send this.', const CoachingContext()),
      isFalse,
    );
  });
}

class _CallbackResponder implements CoachingResponder {
  const _CallbackResponder(this.callback);

  final Future<String> Function(String message) callback;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) => callback(message);
}

class _RecordingResponder implements CoachingResponder {
  _RecordingResponder(this.response);

  final String response;
  int calls = 0;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
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
