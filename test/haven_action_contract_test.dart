import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed action runtime keeps a versioned, bounded allowlist', () {
    final model = _read('lib/models/haven_action.dart');
    final interpreter = _read('lib/services/haven_action_interpreter.dart');
    final policy = _read('lib/services/haven_action_policy.dart');

    for (final source in <String>[
      'typed',
      'voiceTranscript',
      'localCoach',
      'systemIntent',
    ]) {
      expect(model, contains(source));
    }
    for (final action in <String>[
      'readTimerStatus',
      'startTimer',
      'pauseTimer',
      'resumeTimer',
      'addTime',
      'openSurface',
      'draftQueueItem',
    ]) {
      expect(model, contains(action));
    }

    expect(interpreter, contains('maxInputLength = 240'));
    expect(interpreter, contains('maxQueueTitleLength = 100'));
    expect(interpreter, contains('maxAddedMinutes = 60'));
    expect(interpreter, contains('proposalLifetime = Duration(minutes: 2)'));
    expect(policy, contains('proposal.source != HavenActionSource.typed'));
    expect(policy, contains('maxSessionSeconds = 24 * 60 * 60'));
  });

  test('execution stays inside existing FocusHaven service ownership', () {
    final engine = _read('lib/services/haven_action_engine.dart');
    final timer = _read('lib/services/timer_service.dart');
    final screen = _read('lib/screens/timer_screen.dart');

    expect(engine, contains("import 'focus_queue_service.dart';"));
    expect(engine, contains("import 'timer_service.dart';"));
    expect(engine, contains('timer.addTime'));
    expect(engine, contains('focusQueue.add'));
    expect(engine, contains('_consumedProposalIds'));
    expect(timer, contains('bool addTime(Duration duration)'));
    expect(screen, contains("ValueKey('openHavenActions')"));
    expect(screen, contains('HavenActionSheet('));

    for (final forbidden in <String>[
      'cloud_functions',
      'firebase_auth',
      'firebase_app_check',
      'FirebaseFunctions',
      'SharedPreferences',
      'http.',
    ]) {
      expect(engine, isNot(contains(forbidden)));
    }
  });

  test('Voice-to-Coach stays outside Haven action authority', () {
    final sheet = _read('lib/widgets/haven_action_sheet.dart');
    final coachingSheet = _read('lib/widgets/coaching_sheet.dart');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    expect(sheet, contains('Typed locally • no microphone • no remote AI'));
    expect(sheet, isNot(contains('SharedPreferences')));
    expect(sheet, isNot(contains('VoiceTranscriptionService')));
    expect(coachingSheet, contains('VoiceTranscriptionService'));
    expect(coachingSheet, isNot(contains('HavenActionEngine')));
    expect(androidManifest, contains('android.permission.RECORD_AUDIO'));
    expect(androidManifest, contains('android.speech.RecognitionService'));
    expect(iosInfo, contains('NSMicrophoneUsageDescription'));
    expect(iosInfo, contains('NSSpeechRecognitionUsageDescription'));
    expect(
      pubspec,
      matches(RegExp(r'^\s*speech_to_text\s*:', multiLine: true)),
    );
    for (final dependency in <String>[
      'record',
      'flutter_sound',
      'audio_waveforms',
    ]) {
      expect(
        pubspec,
        isNot(matches(RegExp('^\\s*$dependency\\s*:', multiLine: true))),
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
