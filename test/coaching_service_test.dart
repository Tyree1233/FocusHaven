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

  Future<CoachingService> createCoach({CoachingResponder? responder}) async {
    final coach = CoachingService(responder: responder);
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
