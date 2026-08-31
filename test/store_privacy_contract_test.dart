import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source manifests keep the audited permission boundary', () {
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final iosEntitlements = _read('ios/Runner/Runner.entitlements');

    for (final permission in <String>[
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.READ_CALENDAR',
      'android.permission.RECORD_AUDIO',
      'android.permission.RECEIVE_BOOT_COMPLETED',
    ]) {
      expect(androidManifest, contains(permission));
    }

    for (final forbidden in <String>[
      'ACCESS_FINE_LOCATION',
      'ACCESS_COARSE_LOCATION',
      'READ_CONTACTS',
      'CAMERA',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_SMS',
      'READ_CALL_LOG',
      'ACTIVITY_RECOGNITION',
      'BODY_SENSORS',
    ]) {
      expect(
        androidManifest,
        isNot(contains('android.permission.$forbidden')),
        reason: '$forbidden requires a new privacy and store review.',
      );
    }

    expect(iosInfo, contains('NSCalendarsFullAccessUsageDescription'));
    expect(iosInfo, contains('NSMicrophoneUsageDescription'));
    expect(iosInfo, contains('NSSpeechRecognitionUsageDescription'));
    expect(iosInfo, contains('does not store raw audio'));
    expect(iosInfo, contains('until you tap Send'));
    expect(
      iosInfo,
      contains('reads only event time boundaries'),
      reason: 'The calendar purpose must describe the bounded read-only use.',
    );
    for (final forbidden in <String>[
      'NSUserTrackingUsageDescription',
      'NSCameraUsageDescription',
      'NSContactsUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSLocationWhenInUseUsageDescription',
      'NSHealthShareUsageDescription',
    ]) {
      expect(
        iosInfo,
        isNot(contains(forbidden)),
        reason: '$forbidden requires a new privacy and store review.',
      );
    }

    expect(iosEntitlements, contains('com.apple.developer.family-controls'));
    expect(iosEntitlements, contains('group.com.focushaven.app'));
    expect(iosEntitlements, contains('com.apple.developer.applesignin'));
  });

  test('dependencies keep analytics advertising and crash SDKs out', () {
    final pubspec = _read('pubspec.yaml');
    for (final package in <String>[
      'firebase_analytics',
      'firebase_crashlytics',
      'facebook_app_events',
      'appsflyer_sdk',
      'adjust_sdk',
      'sentry_flutter',
      'bugsnag_flutter',
    ]) {
      expect(
        pubspec,
        isNot(matches(RegExp('^\\s*$package\\s*:', multiLine: true))),
        reason: '$package requires a new privacy and store disclosure review.',
      );
    }
  });

  test('cloud backup stays limited to the disclosed focus fields', () {
    final timerService = _read('lib/services/timer_service.dart');
    const getterStart = 'Map<String, dynamic> get cloudBackup => {';
    final start = timerService.indexOf(getterStart);
    final end = start < 0 ? -1 : timerService.indexOf('\n  };', start);
    final backupGetter = start < 0 || end < 0
        ? null
        : timerService.substring(start, end);

    expect(backupGetter, isNotNull);
    for (final key in <String>[
      'focusSeconds',
      'shortBreakSeconds',
      'longBreakSeconds',
      'completedFocusSessions',
      'focusTask',
      'dailyGoalMinutes',
      'focusHistory',
      '_focusEventsKey',
    ]) {
      expect(backupGetter, contains(key));
    }
    for (final privateField in <String>[
      'journal',
      'mood',
      'queue',
      'parkedThought',
      'coaching',
      'focusProfile',
      'theme',
      'calendar',
      'focusShield',
    ]) {
      expect(
        backupGetter,
        isNot(contains(privateField)),
        reason: '$privateField is not disclosed as cloud-backup content.',
      );
    }
  });

  test('public policy and store matrix describe the current truth', () {
    final policy = _read('docs/PRIVACY_POLICY.md');
    final matrix = _read('docs/STORE_PRIVACY_DISCLOSURE_MATRIX.md');

    for (final statement in <String>[
      'anonymous Firebase Authentication identity',
      'Delete cloud backup',
      'Deleting a cloud backup is not the same as deleting',
      'Firebase App Check',
      'reads only busy event start and end times',
      'opaque system tokens',
      'Continue with Apple',
      'Delete account',
      'account-deletion page',
      'Voice-to-Coach',
      'does not retain raw audio',
      'on-device or over a network',
      'until you tap Send',
    ]) {
      expect(policy, contains(statement));
    }

    expect(matrix, contains('not yet ready for public store submission'));
    expect(matrix, contains('Apple login activation'));
    expect(matrix, contains('Account-deletion deployment'));
    expect(matrix, contains('Family Controls distribution approval'));
    expect(matrix, contains('deleteFocusHavenAccount'));
    expect(matrix, contains('production-project validation'));

    final accountSheet = _read('lib/widgets/account_sheet.dart');
    expect(accountSheet, contains('Sign in with Google'));
    expect(accountSheet, contains('Continue with Apple'));
    expect(accountSheet, contains('Delete cloud backup'));
    expect(accountSheet, contains("Text('Delete account')"));

    final deletionPage = _read('docs/ACCOUNT_DELETION.md');
    expect(deletionPage, contains('Delete your account in the app'));
    expect(deletionPage, contains('Request deletion without the app'));
    expect(deletionPage, contains('Never send a password'));
    expect(deletionPage, contains('does not block the verified account'));
    expect(deletionPage, contains('Stop Using'));

    final activationRunbook = _read(
      'docs/ACCOUNT_LIFECYCLE_PRODUCTION_ACTIVATION.md',
    );
    expect(activationRunbook, contains('functions:deleteFocusHavenAccount'));
    expect(activationRunbook, contains('--project focushaven-68c59'));
    expect(matrix, contains('account-lifecycle production activation runbook'));

    for (final archiveCheckedDisclosure in <String>[
      'Archive-checked Apple App Privacy answers',
      'd37f57281159ff7e8b0d80e970d243fc2ae3c04d',
      '32d98bfe74fd1947c6b53a1b7d534fde3fe5ba0b7e090c5afd7866e0654600dd',
      'Contact Info — Phone Number',
      'Location — Coarse Location',
      'Usage Data — Other Usage Data',
      'Diagnostics — Crash Data',
      'Diagnostics — Performance Data',
      'Diagnostics — Other Diagnostic Data',
      'does not include Firebase Analytics',
      'sets its tracking value to false',
    ]) {
      expect(
        matrix,
        contains(archiveCheckedDisclosure),
        reason:
            '$archiveCheckedDisclosure is required by the exact candidate audit.',
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
