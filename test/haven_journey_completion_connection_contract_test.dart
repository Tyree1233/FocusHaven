import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/services/haven_journey_service.dart',
  ).readAsStringSync();
  final model = File('lib/models/haven_journey_state.dart').readAsStringSync();
  final providers = File('lib/providers/app_providers.dart').readAsStringSync();
  final screen = File('lib/screens/timer_screen.dart').readAsStringSync();
  final card = File(
    'lib/widgets/haven_journey_completion_connection_card.dart',
  ).readAsStringSync();

  test('connection requires exact newest unique completion evidence', () {
    expect(service, contains('ordered.first.completionIdentity != completion'));
    expect(service, contains('matches.length != 1'));
    expect(service, contains('journey.supportingSessionCount < 1'));
    expect(service, contains('verifiedCurrent.place != journey.place'));
    expect(model, contains('final FocusCompletionIdentity completion'));
    expect(model, isNot(contains('taskTitle')));
    expect(model, isNot(contains('sessionFit')));
  });

  test('provider waits for exact completed Focus and settled loop state', () {
    expect(providers, contains('havenJourneyCompletionConnectionProvider'));
    expect(providers, contains('session.sessionType != SessionType.focus'));
    expect(providers, contains('!session.isComplete'));
    expect(providers, contains('!havenLoop.isInitialized'));
    expect(providers, contains('havenLoop.canResolveCompletion'));
    expect(providers, contains('completedFocusIdentity'));
  });

  test('timer renders Journey only after the task-decision boundary', () {
    expect(screen, contains('HavenLoopCompletionCard('));
    expect(screen, contains('HavenJourneyCompletionConnectionCard('));
    expect(
      screen.indexOf('HavenJourneyCompletionConnectionCard('),
      greaterThan(screen.indexOf('HavenLoopCompletionCard(')),
    );
  });

  test('advisory has no mutation, persistence, or external surface', () {
    for (final forbidden in <String>[
      'onPressed:',
      'onTap:',
      'TimerService',
      'FocusQueueService',
      'SharedPreferences',
      'http.',
      'Firebase',
      'CoachingService',
    ]) {
      expect(card, isNot(contains(forbidden)));
    }
    expect(card, contains('havenJourneyCompletionSemantics'));
    expect(card, contains('havenJourneyNoAutomaticChange'));
  });
}
