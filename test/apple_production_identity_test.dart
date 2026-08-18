import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const teamId = 'J3QFMX6H2P';
  const appBundleId = 'com.focushaven.app';
  const widgetBundleId = 'com.focushaven.app.widget';
  const watchBundleId = 'com.focushaven.app.watchkitapp';
  const appGroupId = 'group.com.focushaven.app';

  test('every Apple target uses its registered production identity', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');

    expect(
      RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(appBundleId)};',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(widgetBundleId)};',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(watchBundleId)};',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.focushaven\.app\.RunnerTests;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp('DEVELOPMENT_TEAM = $teamId;').allMatches(project),
      hasLength(12),
    );
    expect(
      RegExp('DevelopmentTeam = $teamId;').allMatches(project),
      hasLength(4),
    );
    expect(project, isNot(contains('com.example.focushaven')));
  });

  test('app and widget share only the registered production group', () {
    final runnerEntitlements = _read('ios/Runner/Runner.entitlements');
    final widgetEntitlements = _read(
      'ios/FocusHavenWidget/FocusHavenWidget.entitlements',
    );
    final snapshotStore = _read('ios/Runner/SystemFocusSnapshotStore.swift');

    expect(runnerEntitlements, contains(appGroupId));
    expect(widgetEntitlements, contains(appGroupId));
    expect(snapshotStore, contains(appGroupId));
    expect(runnerEntitlements, contains('com.apple.developer.family-controls'));

    for (final source in <String>[
      runnerEntitlements,
      widgetEntitlements,
      snapshotStore,
    ]) {
      expect(source, isNot(contains('group.com.example.focushaven')));
    }
  });

  test('Firebase and native callback metadata match the production app', () {
    final firebasePlist = _read('ios/Runner/GoogleService-Info.plist');
    final runnerPlist = _read('ios/Runner/Info.plist');
    final watchPlist = _read('ios/FocusHavenWatch/Info.plist');
    final firebaseOptions = _read('lib/firebase_options.dart');

    final firebaseBundleId = _plistString(firebasePlist, 'BUNDLE_ID');
    final reversedClientId = _plistString(firebasePlist, 'REVERSED_CLIENT_ID');

    expect(firebaseBundleId, appBundleId);
    expect(firebaseOptions, contains("iosBundleId: '$appBundleId'"));
    expect(runnerPlist, contains('$appBundleId.system-focus'));
    expect(runnerPlist, contains(reversedClientId));
    expect(watchPlist, contains(appBundleId));
    expect(firebaseOptions, contains("static const FirebaseOptions ios"));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _plistString(String source, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(source);
  if (match == null) {
    fail('Missing string value for $key.');
  }
  return match.group(1)!;
}
