import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/services/haven_rhythm_service.dart',
  ).readAsStringSync();
  final providers = File('lib/providers/app_providers.dart').readAsStringSync();
  final screen = File('lib/screens/timer_screen.dart').readAsStringSync();
  final card = File(
    'lib/widgets/haven_rhythm_reflection_connection_card.dart',
  ).readAsStringSync();

  test('connection requires the exact newest uniquely matched reflection', () {
    expect(service, contains('ordered.first.completionIdentity != completion'));
    expect(service, contains('matches.length != 1'));
    expect(service, contains('matches.single.sessionFit == null'));
    expect(
      service,
      contains('HavenRhythmReflectionConnectionKind.recoveryLeads'),
    );
  });

  test(
    'provider exposes the connection only for a completed Focus session',
    () {
      expect(providers, contains('havenRhythmReflectionConnectionProvider'));
      expect(providers, contains('session.sessionType != SessionType.focus'));
      expect(providers, contains('!session.isComplete'));
      expect(providers, contains('session.completedFocusSessionFit == null'));
      expect(providers, contains('completedFocusIdentity'));
    },
  );

  test('timer screen renders the advisory directly after reflection', () {
    expect(screen, contains('FocusSessionReflectionCard('));
    expect(screen, contains('HavenRhythmReflectionConnectionCard('));
    expect(
      screen.indexOf('HavenRhythmReflectionConnectionCard('),
      greaterThan(screen.indexOf('FocusSessionReflectionCard(')),
    );
  });

  test('advisory card has no execution or external-service surface', () {
    for (final forbidden in <String>[
      'onPressed:',
      'onTap:',
      'TimerService',
      'SharedPreferences',
      'http.',
      'Firebase',
      'CoachingService',
    ]) {
      expect(card, isNot(contains(forbidden)));
    }
    expect(card, contains('Nothing changed automatically'));
    expect(card, contains('Your next session remains your choice'));
  });
}
