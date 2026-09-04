import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'records exact anonymous Android TalkBack acceptance without activation',
    () {
      final qualification =
          jsonDecode(
                File(
                  'localization/reviews/es/qualification.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(qualification['talkBackPhysicalAcceptancePhase'], '215G-C3F');
      expect(qualification['talkBackPhysicalAcceptanceStatus'], 'accepted');
      expect(
        qualification['deviceIntegrationPreparationStatus'],
        'debug_target_verified_screen_readers_accepted',
      );
      expect(
        qualification['talkBackPhysicalAcceptanceDevice'],
        'Moto g - 2025',
      );
      expect(
        qualification['talkBackAcceptanceSourceCommit'],
        'f8f2994a9da8e88450ea1aaa3ffbaf70e8fa8245',
      );
      expect(
        qualification['talkBackSpanishApkSha256'],
        'a7202ed540adb8ba82926453b407930b391df1187191a278e5c30e3b1fa28297',
      );
      expect(
        qualification['talkBackEnglishApkSha256'],
        '4ef39c6b87e06da47a56f793e9fc0103b3ab012e9b071ae66b198940863475f3',
      );
      expect(qualification['talkBackCorrectedSpanishChecklistCount'], 10);
      expect(qualification['talkBackCorrectedSpanishChecklistPassed'], isTrue);
      expect(qualification['talkBackCorrectedEnglishClearancePassed'], isTrue);
      expect(qualification['talkBackAcceptanceRecorded'], isTrue);
      expect(qualification['talkBackAcceptancePersonalDataIncluded'], isFalse);
      expect(qualification['androidTalkBackPhysicalAcceptancePassed'], isTrue);
    },
  );

  test(
    'keeps production release gates closed after screen-reader acceptance',
    () {
      final qualification =
          jsonDecode(
                File(
                  'localization/reviews/es/qualification.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final localePolicy = File(
        'lib/l10n/focus_haven_locales.dart',
      ).readAsStringSync();

      expect(qualification['screenReaderPhysicalAcceptancePassed'], isTrue);
      expect(qualification['screenReaderQualified'], isTrue);
      expect(qualification['runtimeActivated'], isTrue);
      expect(qualification['voiceAndCoachingQualified'], isFalse);
      expect(qualification['nativeAndStoreQualified'], isFalse);
      expect(localePolicy, contains("languageCode: 'es'"));
    },
  );
}
