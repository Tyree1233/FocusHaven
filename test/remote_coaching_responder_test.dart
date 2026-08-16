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

  test('recognizes only the explicit monthly allowance failure', () async {
    final quotaResponder = RemoteCoachingResponder(
      backend: const _FailingBackend(
        CoachingFunctionException(
          code: 'resource-exhausted',
          details: {'reason': 'monthly-quota-exhausted'},
        ),
      ),
    );
    final providerResponder = RemoteCoachingResponder(
      backend: const _FailingBackend(
        CoachingFunctionException(
          code: 'resource-exhausted',
          details: {'reason': 'provider-unavailable'},
        ),
      ),
    );

    await expectLater(
      quotaResponder.respond(
        message: 'Help me start.',
        context: const CoachingContext(),
        conversation: const [],
      ),
      throwsA(
        isA<CoachingFallbackException>().having(
          (error) => error.reason,
          'reason',
          CoachingFallbackReason.allowanceReached,
        ),
      ),
    );
    await expectLater(
      providerResponder.respond(
        message: 'Help me start.',
        context: const CoachingContext(),
        conversation: const [],
      ),
      throwsA(
        isA<CoachingFallbackException>().having(
          (error) => error.reason,
          'reason',
          CoachingFallbackReason.serviceUnavailable,
        ),
      ),
    );
  });

  test('contains remote access failures behind one safe reason', () async {
    for (final code in <String>[
      'unauthenticated',
      'permission-denied',
      'failed-precondition',
    ]) {
      final responder = RemoteCoachingResponder(
        backend: _FailingBackend(CoachingFunctionException(code: code)),
      );

      await expectLater(
        responder.respond(
          message: 'Help me start.',
          context: const CoachingContext(),
          conversation: const [],
        ),
        throwsA(
          isA<CoachingFallbackException>().having(
            (error) => error.reason,
            'reason',
            CoachingFallbackReason.accessUnavailable,
          ),
        ),
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

class _FailingBackend implements CoachingFunctionBackend {
  const _FailingBackend(this.error);

  final Object error;

  @override
  Future<Object?> request(Map<String, Object?> payload) => Future.error(error);
}
