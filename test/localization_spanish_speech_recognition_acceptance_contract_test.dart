import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> qualification;

  setUpAll(() {
    qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  test('records exact anonymous Android and iOS recognition acceptance', () {
    expect(
      qualification['speechRecognitionPhysicalAcceptancePhase'],
      '215G-D2',
    );
    expect(
      qualification['speechRecognitionPhysicalAcceptanceStatus'],
      'accepted',
    );
    expect(
      qualification['speechRecognitionAcceptanceSourceCommit'],
      '6717cc350d170633d97280860bc63dc49759f727',
    );
    expect(qualification['speechRecognitionFixedPhraseCountPerPlatform'], 2);
    expect(qualification['speechRecognitionEditableDraftsPassed'], isTrue);
    expect(qualification['speechRecognitionDiscardPassed'], isTrue);
    expect(qualification['speechRecognitionBackgroundStopPassed'], isTrue);
    expect(
      qualification['speechRecognitionAutomaticSendOrActionObserved'],
      isFalse,
    );
    expect(
      qualification['speechRecognitionAcceptancePersonalDataIncluded'],
      isFalse,
    );

    expect(
      qualification['speechRecognitionAndroidDeviceClass'],
      'Moto g - 2025',
    );
    expect(
      qualification['speechRecognitionAndroidSpanishApkSha256'],
      '341c1fff9692fb2afeecbf25e42f4ad85c03fa0fa4c476bb432ca5939583376d',
    );
    expect(
      qualification['speechRecognitionAndroidEnglishApkSha256'],
      'db1fcd5c387da86ceabf3b8462b92ea9884236de24f56ce98261b19c98423676',
    );
    expect(qualification['speechRecognitionAndroidAccepted'], isTrue);
    expect(qualification['speechRecognitionAndroidEnglishRestored'], isTrue);

    expect(
      qualification['speechRecognitionIosDeviceIdentityRecorded'],
      isFalse,
    );
    expect(
      qualification['speechRecognitionIosSpanishAppManifestSha256'],
      '3a66da0df30689f7991089c7ebb87d7f5017b665fc56d58a68be368971b0b102',
    );
    expect(
      qualification['speechRecognitionIosSpanishAppArchiveSha256'],
      '826159ef162c3abcc84bc0be0a142ae229eb467f81fde92fb1b481c8058f573b',
    );
    expect(
      qualification['speechRecognitionIosEnglishAppManifestSha256'],
      'c09ebb1d543cb4c427f5443be5cafb6e25ae36bebcb4aa12ff0aa4f4502b254b',
    );
    expect(
      qualification['speechRecognitionIosEnglishAppArchiveSha256'],
      '31137d515e11ea41e75dcd4f26ebde20f639f9d74470731925ae5e7456d6a906',
    );
    expect(qualification['speechRecognitionIosAccepted'], isTrue);
    expect(qualification['speechRecognitionIosEnglishRestored'], isTrue);
    expect(qualification['speechRecognitionPhysicalAcceptancePassed'], isTrue);
  });

  test('keeps language behavior and production gates closed', () {
    final localePolicy = File(
      'lib/l10n/focus_haven_locales.dart',
    ).readAsStringSync();

    expect(qualification['spanishLocalCoachQualified'], isFalse);
    expect(qualification['spanishSafeVoiceCommandsQualified'], isFalse);
    expect(qualification['spanishEnhancedAiBehaviorQualified'], isFalse);
    expect(qualification['voiceAndCoachingQualified'], isFalse);
    expect(qualification['nativeAndStoreQualified'], isFalse);
    expect(qualification['runtimeActivated'], isTrue);
    expect(qualification['productionLocaleAllowed'], isTrue);
    expect(
      localePolicy,
      contains(
        "static const productionLocales = <Locale>[Locale('en'), Locale('es')];",
      ),
    );
  });

  test('documents physical recognition without a public support claim', () {
    final readme = File('README.md').readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md',
    ).readAsStringSync();
    final roadmap = File('docs/PRODUCT_ROADMAP.md').readAsStringSync();
    final voicePolicy = File(
      'docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md',
    ).readAsStringSync();
    final combined = '$readme\n$policy\n$roadmap\n$voicePolicy';

    expect(combined, contains('Phase 215G-D2'));
    expect(combined, contains('two fixed public'));
    expect(combined, contains('normal English artifacts were restored'));
    expect(combined, contains('no operator identity'));
    expect(combined, contains('production remains English-only'));
  });
}
