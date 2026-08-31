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
      '| Haven AI planner | Foundation shipped |',
      '| Unified Haven Loop | Foundation shipped |',
      '| Voice-to-Coach | Shipped |',
      '| Safe voice commands | Shipped |',
    ]) {
      expect(
        roadmap,
        contains(currentExperience),
        reason: '$currentExperience must remain an honest current-state claim.',
      );
    }

    for (final futureExperience in <String>[
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

    for (var phase = 209; phase <= 219; phase += 1) {
      expect(roadmap, contains('Phase $phase'));
    }

    expect(readme, contains('docs/PRODUCT_ROADMAP.md'));
    expect(readme, contains('docs/HAVEN_AI_ACTION_ARCHITECTURE.md'));
    expect(readme, contains('docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md'));
    expect(readme, contains('explicit tap-to-talk Voice-to-Coach'));
    expect(readme, contains('typed Haven Action Engine'));
    expect(readme, contains('stores no raw command history'));
    expect(readme, contains('announced as one accessible summary'));
    expect(readme, contains('every consumed proposal disappears'));
    expect(readme, contains('Safe Voice Commands'));
    expect(readme, contains('Review action'));
    expect(readme, contains('Run reviewed action'));
    expect(readme, contains('local Haven planner foundation'));
    expect(readme, contains('Plan a goal'));
    expect(readme, contains('Accept'));
    expect(readme, contains('Edit'));
    expect(readme, contains('Reject'));
    expect(readme, contains('local Plan-to-Focus loop'));
    expect(readme, contains('Mark task complete'));
    expect(readme, contains('Keep for later'));
    expect(readme, contains('task-decision-to-reflection'));
    expect(readme, contains('take the break without answering'));
    expect(readme, contains('stale callbacks'));
    expect(readme, contains('reflection-to-Rhythm'));
    expect(readme, contains('nothing changed automatically'));
    expect(readme, contains('Unanswered, stale, duplicate, or mismatched'));
    expect(readme, contains('reflection-to-Forecast'));
    expect(readme, contains('does not change'));
    expect(readme, contains('possible window is not a rule'));
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
      'Phase 210 typed runtime and Phase 213 safe voice runtime implemented',
      'lib/services/haven_action_interpreter.dart',
      'lib/services/haven_action_policy.dart',
      'lib/services/haven_action_engine.dart',
      'exact confirmation step for saved queue edits',
      'accessible review announcement',
      'explicit **Change request** path',
      'every execution attempt settles the visible proposal',
      'Phase 213 safe voice runtime implemented',
      '`typed` and `voiceTranscript` sources',
      '`localCoach` and `systemIntent`',
      'tap **Review action**, inspect the proposal',
      'Phase 214A local planner foundation',
      'HavenPlannerService',
      'HavenPlannerSheet',
      'HavenPlannerActionService',
      'one fresh `HavenActionProposal` per reviewed task',
      'The planner never writes queue storage directly',
      'no timer, calendar, account, purchase, permission, deployment, or store authority',
      'Phase 215A local Plan-to-Focus loop',
      'persists only `havenLoopSelectedQueueItemId`',
      'Task text, ordering, and completion remain owned by `FocusQueueService`',
      'session type, intention, countdown, and completion remain owned by `TimerService`',
      'A completed linked Focus session is not proof that the task itself is done',
      '**Mark task complete**',
      '**Keep for later**',
      'Restoration also fails closed',
      'a cold-start race cannot bypass a pending task decision',
      'adds no network call, remote AI, permission, account requirement, backend, or deployment',
      'Phase 215B task-decision-to-reflection connection',
      'the next-session control remains withheld',
      'explicit skip stores no reflection value',
      '`TimerService` remains the sole owner of focus-event history',
      '`HavenLoopService` never receives or stores reflection state',
      '`FocusCompletionIdentity`',
      'stale callback, replay after the next session',
      'fails closed instead of rewriting later history',
      'copies no task text or reflection content',
      'Phase 215C reflection-to-Rhythm connection',
      '`HavenRhythmService` accepts the exact current `FocusCompletionIdentity`',
      'belongs to the newest event, appears exactly once',
      '`HavenRhythmReflectionConnection` is ephemeral',
      'one reflection is not yet a pattern',
      'recent recovery signals still carry more weight',
      'The connection persists no second reflection, task text, derived insight',
      'It has no button and no execution authority',
      'Nothing changed automatically',
      'Forecast, Smart Reset, Journey, and coaching remain separate',
      'Phase 215D reflection-to-Forecast connection',
      '`FocusForecastService`',
      '`FocusForecastReflectionConnection`',
      'one reflection cannot create a timing pattern',
      'inside a possible window',
      'outside that possible window',
      'timing remains flexible',
      'never treated as proof that a time is good, bad, productive, or guaranteed',
      'cannot change Forecast\'s minimum evidence or dominance rules',
      'rank a best time',
      'A possible window is not a rule',
      'current energy, recovery needs, and real-life availability continue to lead',
      'Smart Reset, Journey, and coaching remain separate',
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

  test('voice policy preserves the explicit transcript-only runtime boundary', () {
    final policy = _normalize(
      _read('docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md'),
    );
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    for (final required in <String>[
      'Voice-to-Coach is implemented in Phase 212',
      'Safe Voice Commands is implemented in Phase 213 source',
      'explicit **tap-to-talk**',
      'There is no always-listening mode',
      'keeps no raw-audio history',
      'editable transcript',
      'installed recognition services',
      'does not claim recognition is always local',
      'Choosing voice does not choose remote AI',
      'Voice receives no authority beyond typed input',
      'A spoken “yes” alone',
      'does not satisfy a destructive confirmation',
      'open an allowlisted FocusHaven surface',
      'updated store privacy and data-safety working answers',
      'Nothing is sent to Focus Coach until the user taps **Send**',
      'Nothing is proposed to the Haven Action Engine until the user taps **Review action**',
      'Nothing executes until the user taps the separate visual **Run reviewed action**',
      'Only `typed` and `voiceTranscript` are accepted proposal sources',
      '`localCoach` and `systemIntent` are rejected',
    ]) {
      expect(policy, contains(required));
    }

    expect(
      androidManifest,
      contains('android.permission.RECORD_AUDIO'),
      reason: 'Phase 212 requires scoped Android microphone access.',
    );
    expect(
      iosInfo,
      contains('NSMicrophoneUsageDescription'),
      reason: 'Phase 212 requires an honest iOS microphone purpose.',
    );
    expect(iosInfo, contains('NSSpeechRecognitionUsageDescription'));
    expect(
      pubspec,
      matches(RegExp(r'^\s*speech_to_text\s*:', multiLine: true)),
    );

    for (final speechDependency in <String>[
      'record',
      'flutter_sound',
      'audio_waveforms',
    ]) {
      expect(
        pubspec,
        isNot(matches(RegExp('^\\s*$speechDependency\\s*:', multiLine: true))),
        reason: '$speechDependency would add an unnecessary raw-audio path.',
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
