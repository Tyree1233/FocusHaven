import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/voice_transcription_service.dart';

void main() {
  test('speech recognition admits only the explicitly prepared locales', () {
    expect(VoiceTranscriptionService.supportedLocaleIds, const <String>{
      'en',
      'es',
    });
  });

  test('both voice surfaces pass the active catalog locale', () {
    final coach = File('lib/widgets/coaching_sheet.dart').readAsStringSync();
    final actions = File(
      'lib/widgets/haven_action_sheet.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/voice_transcription_service.dart',
    ).readAsStringSync();

    expect(coach, contains('localeId: context.l10n.localeName'));
    expect(actions, contains('localeId: context.l10n.localeName'));
    expect(service, contains('localeId: supportedLocaleId'));
    expect(service, contains('localeId: localeId'));
    expect(
      service,
      contains('VoiceTranscriptionNotice.recognitionLocaleUnsupported'),
    );
  });

  test('D1 remains preparation rather than voice or production approval', () {
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final registry = File(
      'lib/l10n/focus_haven_locales.dart',
    ).readAsStringSync();

    expect(qualification['voiceAndCoachingPhase'], '215G-D1');
    expect(
      qualification['voiceAndCoachingStatus'],
      'explicit_speech_locale_verified_pending_device_and_language_behavior',
    );
    expect(qualification['speechRecognitionSupportedLocaleIds'], <String>[
      'en',
      'es',
    ]);
    expect(qualification['speechRecognitionLocaleExplicit'], isTrue);
    expect(
      qualification['speechRecognitionUnsupportedLocaleFailsClosed'],
      isTrue,
    );
    expect(
      qualification['speechRecognitionLocaleAutomatedVerificationPassed'],
      isTrue,
    );
    expect(qualification['speechRecognitionPhysicalAcceptancePassed'], isFalse);
    expect(qualification['spanishLocalCoachQualified'], isFalse);
    expect(qualification['spanishSafeVoiceCommandsQualified'], isFalse);
    expect(qualification['spanishEnhancedAiBehaviorQualified'], isFalse);
    expect(qualification['voiceAndCoachingQualified'], isFalse);
    expect(qualification['runtimeActivated'], isFalse);
    expect(qualification['productionLocaleAllowed'], isFalse);
    expect(
      registry,
      contains("static const productionLocales = <Locale>[Locale('en')]"),
    );
  });
}
