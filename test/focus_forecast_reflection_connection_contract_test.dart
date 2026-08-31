import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/services/focus_forecast_service.dart',
  ).readAsStringSync();
  final providers = File('lib/providers/app_providers.dart').readAsStringSync();
  final screen = File('lib/screens/timer_screen.dart').readAsStringSync();
  final card = File(
    'lib/widgets/focus_forecast_reflection_connection_card.dart',
  ).readAsStringSync();

  test('connection requires the exact newest uniquely matched reflection', () {
    expect(service, contains('ordered.first.completionIdentity != completion'));
    expect(service, contains('matches.length != 1'));
    expect(service, contains('matches.single.sessionFit == null'));
    expect(service, contains('createForecast('));
  });

  test('provider exposes it only for one completed Focus reflection', () {
    expect(providers, contains('focusForecastReflectionConnectionProvider'));
    expect(providers, contains('session.sessionType != SessionType.focus'));
    expect(providers, contains('!session.isComplete'));
    expect(providers, contains('session.completedFocusSessionFit == null'));
    expect(providers, contains('completedFocusIdentity'));
  });

  test('timer screen renders Forecast after the saved reflection', () {
    expect(screen, contains('FocusSessionReflectionCard('));
    expect(screen, contains('FocusForecastReflectionConnectionCard('));
    expect(
      screen.indexOf('FocusForecastReflectionConnectionCard('),
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
    expect(card, contains('A possible window is not a rule'));
    expect(card, contains('your next session remains your choice'));
  });
}
