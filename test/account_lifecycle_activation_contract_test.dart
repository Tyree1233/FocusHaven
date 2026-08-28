import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protected Firebase initialization is independent of coaching', () {
    final appCheck = _read('lib/services/app_check_service.dart');
    final main = _read('lib/main.dart');
    final runnerEntitlements = _read('ios/Runner/Runner.entitlements');

    expect(appCheck, contains('initializeProtectedFirebaseAppCheck'));
    expect(appCheck, contains('ReCaptchaEnterpriseProvider'));
    expect(
      appCheck,
      isNot(
        contains(
          'ReCaptchaV3'
          'Provider',
        ),
      ),
    );
    expect(appCheck, isNot(contains('remoteCoachingEnabled')));
    expect(main, contains('await initializeProtectedFirebaseAppCheck()'));
    expect(
      runnerEntitlements,
      contains('com.apple.developer.devicecheck.appattest-environment'),
    );
    expect(runnerEntitlements, contains('<string>production</string>'));
    expect(
      main,
      contains('protectedFirebaseReady && FeatureFlags.remoteCoachingEnabled'),
    );
  });

  test('sensitive callables explicitly reject App Check replay', () {
    final functions = _read('functions/index.js');
    final policy = _read('functions/app_check_policy.js');

    expect(
      RegExp(r'consumeAppCheckToken:\s*true').allMatches(functions).length,
      2,
    );
    expect(
      RegExp(
        r'evaluateAppCheckReplay\(request\.app\)',
      ).allMatches(functions).length,
      2,
    );
    expect(policy, contains('appContext?.alreadyConsumed === true'));
    expect(policy, contains('failed-precondition'));
  });

  test('Apple revocation fallback cannot block verified deletion', () {
    final auth = _read('lib/services/auth_service.dart');
    final deletion = _read('lib/services/account_deletion_service.dart');
    final publicPage = _read('docs/ACCOUNT_DELETION.md');

    expect(auth, contains('requiresManualAppleRevocation: true'));
    expect(deletion, contains('deletedAppleRevocationRequired'));
    expect(deletion, contains('await _backend.deleteCurrentAccount()'));
    expect(publicPage, contains('does not block the verified account'));
    expect(publicPage, contains('Stop Using'));
  });

  test('production runbook pins scope and contains no secret values', () {
    final runbook = _read('docs/ACCOUNT_LIFECYCLE_PRODUCTION_ACTIVATION.md');

    for (final required in <String>[
      'focushaven-68c59',
      'deleteFocusHavenAccount',
      'us-central1',
      'J3QFMX6H2P',
      'com.focushaven.app',
      'functions:deleteFocusHavenAccount',
      '--project focushaven-68c59',
      'explicit approval',
      'Firebase App Check Token Verifier',
      'request.app.alreadyConsumed === true',
      'The repository pins the Firebase CLI default project alias',
      'operator-recorded console evidence',
      'App Check enforcement remains disabled',
      'Firebase Hosting remains undeployed',
      'Gate 3 deployment completed on August 28, 2026',
      'No App Store build was delivered',
      'App Attest entitlement is pinned to the production environment',
    ]) {
      expect(runbook, contains(required));
    }

    expect(
      RegExp(r'^firebase deploy\s*$', multiLine: true).hasMatch(runbook),
      isFalse,
      reason: 'An unscoped production deploy must never enter the runbook.',
    );
    expect(
      RegExp(
        r'^firebase deploy --only functions\s*$',
        multiLine: true,
      ).hasMatch(runbook),
      isFalse,
      reason: 'All-functions deployment is outside this activation scope.',
    );
    for (final forbidden in <String>[
      'BEGIN PRIVATE KEY',
      'OPENAI_API_KEY=',
      'FIREBASE_TOKEN=',
      'authorization_code=',
      'refresh_token=',
    ]) {
      expect(runbook, isNot(contains(forbidden)));
    }
  });

  test(
    'production runbook matches the committed Firebase activation boundary',
    () {
      final aliases = _read('.firebaserc');
      final runbook = _read('docs/ACCOUNT_LIFECYCLE_PRODUCTION_ACTIVATION.md');

      expect(aliases, contains('"default": "focushaven-68c59"'));
      expect(runbook, contains('`focushaven-68c59` through `.firebaserc`'));
      expect(
        runbook,
        isNot(contains('repository intentionally has no `.firebaserc`')),
      );

      for (final completedCheckpoint in <String>[
        'Firebase Authentication Apple provider is enabled',
        'Android App Check registration uses Play Integrity',
        'Apple App Check registration uses App Attest with DeviceCheck fallback',
        'Web App Check registration uses reCAPTCHA Enterprise',
        '`791775983697-compute@developer.gserviceaccount.com`',
        '`roles/firebaseappcheck.tokenVerifier`',
        'binding was independently',
        'verified in the project IAM principal and role views',
        '`focusCoach` as deployed',
        '`ACTIVE` in `us-central1`',
        '`REMOTE_COACHING_ENABLED=false`',
        '`deleteFocusHavenAccount` is `ACTIVE`',
        'second-generation Node.js 22',
        '`c70d264102396b9666f59b8db7459582964bc9dd`',
        '`maxInstances=10`',
        '`focusCoach` remained byte-for-byte identical',
      ]) {
        expect(runbook, contains(completedCheckpoint));
      }

      for (final pendingBoundary in <String>[
        'App Check enforcement remains disabled',
        'remote coaching remains disabled',
        'this activation runbook did not deploy,',
        'enable, invoke, or modify `focusCoach`',
        'production canaries have not run',
        'no callable invocation was performed',
        'no store release has occurred',
      ]) {
        expect(runbook, contains(pendingBoundary));
      }

      expect(
        runbook,
        isNot(
          contains(
            'remote coaching remains disabled and has not been deployed',
          ),
        ),
      );
      expect(runbook, isNot(contains('role has not been granted or')));
      expect(
        runbook,
        isNot(
          contains(
            '`deleteFocusHavenAccount` has not been deployed by this activation runbook',
          ),
        ),
      );
    },
  );
}

String _read(String path) => File(path).readAsStringSync();
