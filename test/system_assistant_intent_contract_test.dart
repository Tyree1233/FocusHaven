import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 217A draft remains text-free, bounded, and non-executable', () {
    final model = _read('lib/models/haven_system_intent.dart');
    final service = _read('lib/services/haven_system_intent_service.dart');
    final policy = _read('lib/services/haven_action_policy.dart');

    for (final intent in <String>[
      'readTimerStatus',
      'startFocusTimer',
      'pauseTimer',
      'resumeTimer',
      'openFocusQueue',
    ]) {
      expect(model, contains(intent));
    }
    expect(model, isNot(contains('String transcript')));
    expect(model, isNot(contains('String utterance')));
    expect(model, isNot(contains('String task')));
    expect(model, contains('bool get requiresInAppReview => true'));
    expect(model, contains('bool get canExecute => false'));
    expect(model, contains('deliberately not a [HavenActionProposal]'));

    expect(service, contains('maxRememberedInvocationIds = 128'));
    expect(service, contains('_consumedInvocationIds'));
    expect(service, contains('duplicateInvocation'));
    expect(model, contains('HavenActionKind.readTimerStatus'));
    expect(model, contains('HavenActionKind.startTimer'));
    expect(model, contains('HavenActionKind.pauseTimer'));
    expect(model, contains('HavenActionKind.resumeTimer'));
    expect(model, contains('HavenActionKind.openSurface'));

    for (final forbidden in <String>[
      "import 'haven_action_engine.dart'",
      "import 'timer_service.dart'",
      "import 'focus_queue_service.dart'",
      "import 'package:shared_preferences/shared_preferences.dart'",
      "import 'package:cloud_functions/cloud_functions.dart'",
      "import 'package:http/http.dart'",
      "import 'dart:io'",
    ]) {
      expect(service, isNot(contains(forbidden)));
    }

    expect(policy, contains('proposal.source == HavenActionSource.typed'));
    expect(
      policy,
      contains('proposal.source == HavenActionSource.voiceTranscript'),
    );
    expect(policy, contains('_isExactReviewedSystemIntent(proposal)'));
    expect(
      policy,
      contains('proposal.source != HavenActionSource.systemIntent'),
    );
    expect(policy, contains('proposal.confirmationRequired'));
    expect(policy, contains('systemIntentProposalLifetime'));
  });

  test('Phase 217C changes no platform registration or production owner', () {
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final architecture = _normalize(
      _read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md'),
    );
    final readme = _normalize(_read('README.md'));
    final iosInfo = _read('ios/Runner/Info.plist');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final pubspec = _read('pubspec.yaml');

    expect(
      roadmap,
      contains(
        'Phase 217C isolated review presentation foundation implemented',
      ),
    );
    expect(
      architecture,
      contains('Phase 217A closed system-intent preparation'),
    );
    expect(readme, contains('system-assistant intent contract foundation'));
    expect(readme, contains('cannot execute a timer or queue action'));
    expect(readme, contains('system-assistant in-app review bridge'));
    expect(readme, contains('system-assistant review presentation foundation'));
    expect(
      architecture,
      contains('Phase 217B reviewed system-intent proposal bridge'),
    );
    expect(
      architecture,
      contains('Phase 217C isolated system-intent review presentation'),
    );

    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(androidManifest, isNot(contains('actions.intent')));
    expect(pubspec, isNot(contains('app_intents')));
    expect(pubspec, isNot(contains('flutter_shortcuts')));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
