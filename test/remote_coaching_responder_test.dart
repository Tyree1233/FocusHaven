import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/services/coaching_service.dart';
import 'package:focushaven/services/remote_coaching_responder.dart';

void main() {
  test(
    'shares only the newest bounded conversation and coaching context',
    () async {
      final backend = _RecordingBackend({'text': '  Take one small step.  '});
      final responder = RemoteCoachingResponder(backend: backend);
      final conversation = List.generate(
        15,
        (index) => CoachingMessage(
          id: '$index',
          role: index.isEven
              ? CoachingMessageRole.user
              : CoachingMessageRole.coach,
          text: 'Message $index',
          createdAt: DateTime.utc(2026, 8, 15).add(Duration(minutes: index)),
        ),
      );

      final response = await responder.respond(
        message: 'Help me choose the next step.',
        context: const CoachingContext(
          focusTask: '  Draft launch notes  ',
          focusProfile: '  Deep worker ',
          todayFocusMinutes: 25,
          dailyGoalMinutes: 60,
          queueRemaining: 2,
          nextQueueTask: '  Review metrics ',
          recentMood: '  hopeful ',
          parkedThoughtCount: 3,
          isTimerRunning: true,
        ),
        conversation: conversation,
      );

      expect(response, 'Take one small step.');
      expect(backend.calls, 1);
      expect(backend.lastPayload.keys, {'message', 'context', 'conversation'});
      expect(backend.lastPayload['message'], 'Help me choose the next step.');
      expect(backend.lastPayload['context'], {
        'focusTask': 'Draft launch notes',
        'focusProfile': 'Deep worker',
        'todayFocusMinutes': 25,
        'dailyGoalMinutes': 60,
        'queueRemaining': 2,
        'nextQueueTask': 'Review metrics',
        'recentMood': 'hopeful',
        'parkedThoughtCount': 3,
        'isTimerRunning': true,
      });
      final sharedConversation =
          backend.lastPayload['conversation']! as List<dynamic>;
      expect(sharedConversation, hasLength(12));
      expect(sharedConversation.first, {'role': 'coach', 'text': 'Message 3'});
      expect(sharedConversation.last, {'role': 'user', 'text': 'Message 14'});
      expect(
        sharedConversation.every(
          (entry) => (entry as Map<Object?, Object?>).keys.toSet().containsAll({
            'role',
            'text',
          }),
        ),
        isTrue,
      );
    },
  );

  test('rejects malformed or empty function responses', () async {
    for (final response in <Object?>[
      null,
      'wrong shape',
      <String, Object?>{},
      <String, Object?>{'text': '   '},
    ]) {
      final responder = RemoteCoachingResponder(
        backend: _RecordingBackend(response),
      );

      await expectLater(
        responder.respond(
          message: 'Help me start.',
          context: const CoachingContext(),
          conversation: const [],
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

class _RecordingBackend implements CoachingFunctionBackend {
  _RecordingBackend(this.response);

  final Object? response;
  int calls = 0;
  Map<String, Object?> lastPayload = const {};

  @override
  Future<Object?> request(Map<String, Object?> payload) async {
    calls += 1;
    lastPayload = payload;
    return response;
  }
}
