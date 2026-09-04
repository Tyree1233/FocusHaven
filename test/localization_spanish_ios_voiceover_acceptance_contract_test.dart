import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records exact anonymous corrected iOS VoiceOver acceptance', () {
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(qualification['voiceOverPhysicalAcceptancePhase'], '215G-C3G');
    expect(qualification['voiceOverPhysicalAcceptanceStatus'], 'accepted');
    expect(
      qualification['voiceOverAcceptanceSourceCommit'],
      'bf15dc0385dcb1ef29ca4de168fb8b7c9850fde5',
    );
    expect(
      qualification['voiceOverSpanishAppManifestSha256'],
      '504d9680cae622580f73ee6eedc94de29841c1c5f7eaa3cb3de084bdc07ff55d',
    );
    expect(
      qualification['voiceOverSpanishAppArchiveSha256'],
      'e1e8d8d4c22f52f5e392b0a38e9c17f7752f0de73b9aef1ef3839f0735dc1997',
    );
    expect(
      qualification['voiceOverEnglishAppManifestSha256'],
      '2c362ee2be30673a6f70807888dc1fc9e09e1b2ccab408b7333d10569347df87',
    );
    expect(
      qualification['voiceOverEnglishAppArchiveSha256'],
      '73788b55038ec7587fbbb91bfecad6c40ce27e58368b78206dbec61901a98240',
    );
    expect(
      qualification['voiceOverObservedFailure'],
      'local_coach_control_overlapped_cloud_restore',
    );
    expect(
      qualification['voiceOverObservedFailureAlsoReproducedInEnglish'],
      isTrue,
    );
    expect(
      qualification['voiceOverObservedFailurePrivateDataIncluded'],
      isFalse,
    );
    expect(qualification['voiceOverSpanishChecklistCount'], 10);
    expect(qualification['voiceOverSpanishChecklistPassedBeforeBlocker'], 9);
    expect(qualification['voiceOverCorrectedSpanishChecklistCount'], 5);
    expect(qualification['voiceOverCorrectedSpanishChecklistPassed'], isTrue);
    expect(qualification['voiceOverCorrectedEnglishClearancePassed'], isTrue);
    expect(qualification['voiceOverAcceptanceRecorded'], isTrue);
    expect(qualification['voiceOverAcceptancePersonalDataIncluded'], isFalse);
    expect(qualification['iosVoiceOverPhysicalAcceptancePassed'], isTrue);
  });

  test('closes screen-reader gates without activating Spanish', () {
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

    expect(qualification['androidTalkBackPhysicalAcceptancePassed'], isTrue);
    expect(qualification['iosVoiceOverPhysicalAcceptancePassed'], isTrue);
    expect(qualification['screenReaderPhysicalAcceptancePassed'], isTrue);
    expect(qualification['screenReaderQualified'], isTrue);
    expect(qualification['productionLocaleAllowed'], isTrue);
    expect(qualification['runtimeActivated'], isTrue);
    expect(qualification['voiceAndCoachingQualified'], isFalse);
    expect(qualification['nativeAndStoreQualified'], isFalse);
    expect(localePolicy, contains("languageCode: 'es'"));
  });
}
