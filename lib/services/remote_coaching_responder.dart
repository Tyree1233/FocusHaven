import 'package:cloud_functions/cloud_functions.dart';

import '../models/coaching_message.dart';
import 'coaching_service.dart';

abstract interface class CoachingFunctionBackend {
  Future<Object?> request(Map<String, Object?> payload);
}

final class FirebaseCoachingFunctionBackend implements CoachingFunctionBackend {
  FirebaseCoachingFunctionBackend({
    FirebaseFunctions? functions,
    this.functionName = 'focusCoach',
    this.timeout = const Duration(seconds: 30),
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;
  final String functionName;
  final Duration timeout;

  @override
  Future<Object?> request(Map<String, Object?> payload) async {
    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call(payload);
    return result.data;
  }
}

final class RemoteCoachingResponder implements CoachingResponder {
  RemoteCoachingResponder({CoachingFunctionBackend? backend})
    : _backend = backend ?? FirebaseCoachingFunctionBackend();

  static const _maximumSharedMessages = 12;

  final CoachingFunctionBackend _backend;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    final firstSharedIndex = conversation.length > _maximumSharedMessages
        ? conversation.length - _maximumSharedMessages
        : 0;
    final sharedConversation = conversation
        .skip(firstSharedIndex)
        .map(
          (entry) => <String, Object?>{
            'role': entry.role.name,
            'text': entry.text,
          },
        )
        .toList(growable: false);
    final response = await _backend.request({
      'message': message,
      'context': context.toPromptData(),
      'conversation': sharedConversation,
    });
    if (response is! Map) {
      throw const FormatException('Invalid Focus Coach response.');
    }
    final text = response['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Invalid Focus Coach response.');
    }
    return text.trim();
  }
}

CoachingResponder createEnhancedCoachingResponder() {
  const localResponder = LocalCoachingResponder();
  return ResilientCoachingResponder(
    primary: RemoteCoachingResponder(),
    fallback: localResponder,
  );
}
