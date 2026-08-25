import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification is optional and adds no privileged service', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('.SystemFocusOngoingNotificationReceiver'));
    expect(
      manifest,
      matches(
        RegExp(
          r'<receiver\s+android:name="\.SystemFocusOngoingNotificationReceiver"\s+'
          r'android:exported="false">',
        ),
      ),
    );
    for (final forbidden in <String>[
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.USE_EXACT_ALARM',
      'android.permission.POST_PROMOTED_NOTIFICATIONS',
      'SystemFocusOngoingNotificationService',
    ]) {
      expect(manifest, isNot(contains(forbidden)));
    }
  });

  test('notification mirrors only the validated private timer contract', () {
    final publisher = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'SystemFocusOngoingNotificationPublisher.kt',
    );
    final store = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'SystemFocusSnapshotStore.kt',
    );

    expect(
      store,
      contains(
        'SystemFocusOngoingNotificationPublisher.publish(context, snapshot)',
      ),
    );
    expect(
      publisher,
      contains('SystemFocusWidgetContent.fromSnapshot(snapshot)'),
    );
    expect(publisher, contains('Manifest.permission.POST_NOTIFICATIONS'));
    expect(publisher, contains('manager.areNotificationsEnabled()'));
    expect(publisher, contains('NotificationManager.IMPORTANCE_LOW'));
    expect(publisher, contains('Notification.VISIBILITY_PUBLIC'));
    expect(publisher, contains('.setLocalOnly(true)'));
    expect(publisher, contains('.setUsesChronometer(true)'));
    expect(publisher, contains('.setChronometerCountDown(true)'));
    expect(publisher, contains('.setTimeoutAfter('));
    expect(publisher, contains('.setAndAllowWhileIdle('));
    expect(publisher, isNot(contains('requestPermissions')));
    expect(publisher, isNot(contains('startForegroundService')));
    expect(publisher, isNot(contains('startService')));
    for (final privateContent in <String>[
      'task',
      'journal',
      'mood',
      'queue',
      'parkedThought',
      'coaching',
      'history',
      'account',
    ]) {
      expect(
        publisher,
        isNot(contains(privateContent)),
        reason: '$privateContent must never enter the notification.',
      );
    }
  });

  test('Lock Screen controls retain snapshot identity and phone authority', () {
    final publisher = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'SystemFocusOngoingNotificationPublisher.kt',
    );
    final policy = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'SystemFocusOngoingNotificationPolicy.kt',
    );

    expect(publisher, contains('FocusHavenWidgetCommandActivity::class.java'));
    expect(publisher, contains('notificationPendingIntentIdentity('));
    expect(publisher, contains('EXTRA_SNAPSHOT_GENERATED_AT'));
    expect(publisher, contains('PendingIntent.FLAG_IMMUTABLE'));
    expect(policy, contains('SystemFocusWidgetActivity.RUNNING'));
    expect(policy, contains('SystemFocusWidgetActivity.PAUSED'));
    expect(policy, contains('SystemFocusWidgetActivity.PENDING_RESUME'));
    expect(policy, contains('SystemFocusOngoingNotificationOperation.CANCEL'));
  });
}

String _read(String path) => File(path).readAsStringSync();
