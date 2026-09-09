import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 217B stays behind one reviewed in-app engine bridge', () {
    final bridge = _read(
      'lib/services/haven_system_intent_review_service.dart',
    );
    final engine = _read('lib/services/haven_action_engine.dart');
    final policy = _read('lib/services/haven_action_policy.dart');

    expect(bridge, contains('required this._engine'));
    expect(bridge, contains('final HavenActionEngine _engine'));
    expect(bridge, contains('final state = _engine.snapshot()'));
    expect(bridge, contains('final decision = _engine.evaluate'));
    expect(bridge, contains('final result = await _engine.execute'));
    expect(bridge, contains('HavenActionConfirmation.forProposal'));
    expect(bridge, contains('HavenActionSource.systemIntent'));
    expect(bridge, contains('confirmationRequired: true'));
    expect(bridge, contains('safeUndoAvailable: true'));
    expect(engine, contains('HavenActionState snapshot()'));
    expect(policy, contains('_isExactReviewedSystemIntent(proposal)'));
    expect(
      policy,
      contains('systemIntentProposalLifetime = Duration(minutes: 2)'),
    );
  });

  test('bridge keeps text, capability, replay, and owner scope bounded', () {
    final bridge = _read(
      'lib/services/haven_system_intent_review_service.dart',
    );

    expect(bridge, contains('maxRememberedInvocationIds = 128'));
    expect(bridge, contains('final Set<String> _consumedInvocationIds'));
    expect(bridge, contains('final Set<String> _issuedProposalIds'));
    expect(bridge, contains('int? _activeGeneration'));
    expect(bridge, contains('_activeGeneration = null'));
    expect(bridge, contains('canExecuteWithoutConfirmation => false'));
    expect(bridge, isNot(contains('TimerService')));
    expect(bridge, isNot(contains('FocusQueueService')));
    expect(bridge, isNot(contains('SharedPreferences')));
    expect(bridge, isNot(contains('Firebase')));
    expect(bridge, isNot(contains('http.')));
    expect(bridge, isNot(contains('transcript')));
    expect(bridge, isNot(contains('taskTitle')));
    expect(bridge, isNot(contains('coachingHistory')));
    expect(bridge, isNot(contains('journal')));
    expect(bridge, isNot(contains('account')));
  });

  test('no production or native platform owner consumes Phase 217B', () {
    final providers = _read('lib/providers/app_providers.dart');
    final timerScreen = _read('lib/screens/timer_screen.dart');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    for (final production in <String>[providers, timerScreen]) {
      expect(production, isNot(contains('HavenSystemIntentReviewService')));
      expect(production, isNot(contains('HavenSystemIntentReview')));
    }
    expect(androidManifest, isNot(contains('actions.intent')));
    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(pubspec, isNot(contains('app_intents')));
    expect(pubspec, isNot(contains('shortcuts')));
  });
}

String _read(String path) => File(path).readAsStringSync();
