import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roadmap separates shipped foundations from future work', () {
    final roadmap = _read('docs/PRODUCT_ROADMAP.md');
    final readme = _normalize(_read('README.md'));

    for (final status in <String>[
      '**Shipped:**',
      '**Foundation shipped:**',
      '**Partial:**',
      '**Planned:**',
      '**Deferred:**',
      '**Replaced:**',
    ]) {
      expect(roadmap, contains(status));
    }

    for (final currentExperience in <String>[
      '| Focus Queue | Shipped |',
      '| Haven Action Engine | Shipped |',
      '| Living Lantern | Shipped |',
      '| Smart Reset | Shipped |',
      '| Haven Rhythm | Shipped |',
      '| Focus Forecast | Shipped |',
      '| Haven Journey and Focus Garden | Partial |',
      '| Haven Plan | Partial |',
      '| Haven Window | Foundation shipped |',
      '| Focus Shield | Foundation shipped |',
      '| Enhanced remote coach | Foundation shipped, disabled |',
    ]) {
      expect(
        roadmap,
        contains(currentExperience),
        reason: '$currentExperience must remain an honest current-state claim.',
      );
    }

    for (final futureExperience in <String>[
      '| Haven AI planner | Planned |',
      '| Voice-to-Coach | Planned |',
      '| Safe voice commands | Planned |',
      '| Siri, Shortcuts, and Android App Actions | Planned |',
      '| Soundscapes and focus environments | Planned |',
      '| Haven Rooms and body doubling | Deferred |',
      '| Focus Score | Replaced |',
      '**Haven Momentum**',
    ]) {
      expect(
        roadmap,
        contains(futureExperience),
        reason:
            '$futureExperience must not be confused with a shipped feature.',
      );
    }

    for (var phase = 209; phase <= 218; phase += 1) {
      expect(roadmap, contains('Phase $phase'));
    }

    expect(readme, contains('docs/PRODUCT_ROADMAP.md'));
    expect(readme, contains('docs/HAVEN_AI_ACTION_ARCHITECTURE.md'));
    expect(readme, contains('docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md'));
    expect(readme, contains('The current runtime remains microphone-free'));
    expect(readme, contains('typed Haven Action Engine'));
    expect(readme, contains('stores no raw command history'));
    expect(readme, contains('announced as one accessible summary'));
    expect(readme, contains('every consumed proposal disappears'));
  });

  test('Haven actions preserve proposal policy and service ownership', () {
    final architecture = _normalize(
      _read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md'),
    );

    for (final required in <String>[
      'Understand -> Propose -> Explain -> Confirm -> Execute',
      'Remote AI may help draft or interpret a proposal',
      'it cannot call a timer, queue, calendar, account,',
      'Existing FocusHaven services remain authoritative',
      'versioned HavenActionProposal',
      'current-state token or equivalent precondition',
      'whether the proposal ID was already accepted or rejected',
      'confirmation binds to the exact proposal ID',
      'typed input exercises the engine without a microphone or remote model',
      'all mutations route through existing services',
      'Phase 210 typed runtime implemented',
      'lib/services/haven_action_interpreter.dart',
      'lib/services/haven_action_policy.dart',
      'lib/services/haven_action_engine.dart',
      'exact confirmation step for saved queue edits',
      'accessible review announcement',
      'explicit **Change request** path',
      'every execution attempt settles the visible proposal',
    ]) {
      expect(architecture, contains(required));
    }

    for (final riskClass in <String>[
      '### Informational',
      '### Reversible control',
      '### Stateful edit',
      '### Destructive or sensitive',
      '### Operationally forbidden',
    ]) {
      expect(architecture, contains(riskClass));
    }

    for (final protectedAction in <String>[
      'delete an account',
      'purchase or restore a subscription',
      'grant a permission',
      'deploy a function or Hosting content',
      'enable App Check enforcement',
      'deliver a store build',
    ]) {
      expect(architecture, contains(protectedAction));
    }
  });

  test('voice policy preserves the current no-microphone runtime boundary', () {
    final policy = _normalize(
      _read('docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md'),
    );
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    for (final required in <String>[
      'voice is **not implemented** through Phase 210',
      'explicit **tap-to-talk**',
      'There is no always-listening mode',
      'keeps no raw-audio history',
      'editable transcript',
      'On-device recognition is preferred',
      'Choosing voice does not choose remote AI',
      'Voice receives no authority beyond typed input',
      'A spoken “yes” alone',
      'does not satisfy a destructive confirmation',
      'Voice may open the dedicated screen',
      'store privacy and data-safety answers updated',
      'That is input and confirmation hardening, not microphone or speech implementation',
    ]) {
      expect(policy, contains(required));
    }

    expect(
      androidManifest,
      isNot(contains('android.permission.RECORD_AUDIO')),
      reason: 'Phase 210 must not introduce Android microphone access.',
    );
    expect(
      iosInfo,
      isNot(contains('NSMicrophoneUsageDescription')),
      reason: 'Phase 210 must not introduce iOS microphone access.',
    );

    for (final speechDependency in <String>[
      'speech_to_text',
      'record',
      'flutter_sound',
      'audio_waveforms',
    ]) {
      expect(
        pubspec,
        isNot(matches(RegExp('^\\s*$speechDependency\\s*:', multiLine: true))),
        reason:
            '$speechDependency belongs to a separately reviewed voice phase.',
      );
    }
  });

  test('voice and AI contracts forbid protected operational actions', () {
    final architecture = _normalize(
      _read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md'),
    );
    final voice = _normalize(_read('docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md'));
    final combined = '$architecture\n$voice';

    for (final boundary in <String>[
      'modify Firebase',
      'App Check enforcement',
      'modify IAM',
      'providers, credentials, functions, Hosting',
      'remote-coaching enablement',
      'store delivery',
      'TestFlight',
      'review submission',
    ]) {
      expect(combined, contains(boundary));
    }

    for (final forbiddenSecret in <String>[
      'BEGIN PRIVATE KEY',
      'OPENAI_API_KEY=',
      'FIREBASE_TOKEN=',
      'refresh_token=',
      'authorization_code=',
    ]) {
      expect(combined, isNot(contains(forbiddenSecret)));
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
