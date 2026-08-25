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
      'android.permission.RECEIVE_BOOT_COMPLETED',
    ]) {
      expect(androidManifest, contains(permission));
    }

    for (final forbidden in <String>[
      'ACCESS_FINE_LOCATION',
      'ACCESS_COARSE_LOCATION',
      'READ_CONTACTS',
      'CAMERA',
      'RECORD_AUDIO',
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
    expect(
      iosInfo,
      contains('reads only event time boundaries'),
      reason: 'The calendar purpose must describe the bounded read-only use.',
    );
    for (final forbidden in <String>[
      'NSUserTrackingUsageDescription',
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
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
    ]) {
      expect(policy, contains(statement));
    }

    expect(matrix, contains('not yet ready for public store submission'));
    expect(matrix, contains('Equivalent Apple login'));
    expect(matrix, contains('Complete account deletion'));
    expect(matrix, contains('Family Controls distribution approval'));
    expect(matrix, contains('does not yet qualify'));

    final accountSheet = _read('lib/widgets/account_sheet.dart');
    expect(accountSheet, contains('Sign in with Google'));
    expect(accountSheet, contains('Delete cloud backup'));
    expect(accountSheet, isNot(contains("Text('Delete account')")));
  });
}

String _read(String path) => File(path).readAsStringSync();
