import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android ingress mirrors exactly five text-free reviewed routes', () {
    final native = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'HavenSystemAssistantAndroidIngress.kt',
    );
    final bridge = _read(
      'lib/services/haven_system_assistant_android_platform_bridge.dart',
    );
    const routes = <String>[
      'readTimerStatus',
      'startFocusTimer',
      'pauseTimer',
      'resumeTimer',
      'openFocusQueue',
    ];
    for (final route in routes) {
      expect(native, contains('"$route"'));
      expect(bridge, contains("'$route'"));
    }
    expect(native, contains('MAXIMUM_INVOCATION_ID_LENGTH = 128'));
    for (final key in ['schemaVersion', 'invocationId', 'kind']) {
      expect(native, contains('"$key"'));
    }
    expect(bridge, contains("{'schemaVersion', 'invocationId', 'kind'}"));
    for (final forbidden in <String>[
      'String transcript',
      'String utterance',
      'String task',
      'durationSeconds',
      'queueTitle',
      'SharedPreferences',
      'RoomDatabase',
    ]) {
      expect(native, isNot(contains(forbidden)), reason: forbidden);
      expect(bridge, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('delivery is acknowledged before Android memory can clear', () {
    final adapter = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'HavenSystemAssistantAndroidPlatformAdapter.kt',
    );
    final ingress = _read(
      'android/app/src/main/kotlin/com/focushaven/app/'
      'HavenSystemAssistantAndroidIngress.kt',
    );
    final bridge = _read(
      'lib/services/haven_system_assistant_android_platform_bridge.dart',
    );
    final inbox = _read('lib/services/haven_system_intent_inbox.dart');

    expect(adapter, contains('if (result == true)'));
    expect(adapter, contains('store.clearIfMatches(request.invocationId)'));
    expect(ingress, contains('if (pendingRequest != null) return false'));
    expect(ingress, contains('pendingRequest?.invocationId != invocationId'));
    expect(bridge, contains('return _inbox.submit(_parseRequest(value))'));
    expect(inbox, contains('if (_pendingRequest != null) return false'));
  });

  test('production wiring terminates at the existing review inbox', () {
    final app = _read('lib/main.dart');
    final providers = _read('lib/providers/app_providers.dart');
    final host = _read(
      'lib/widgets/haven_system_assistant_android_platform_host.dart',
    );
    final activity = _read(
      'android/app/src/main/kotlin/com/focushaven/app/MainActivity.kt',
    );

    expect(app, contains('HavenSystemAssistantAndroidPlatformHost'));
    expect(
      providers,
      contains('havenSystemAssistantAndroidPlatformControllerProvider'),
    );
    expect(host, contains('TargetPlatform.android'));
    expect(host, contains('AppLifecycleState.resumed'));
    expect(activity, contains('HavenSystemAssistantAndroidPlatformAdapter'));
    expect(activity, contains('deliverPendingRequest()'));
    for (final forbidden in <String>[
      'HavenActionEngine',
      'TimerService',
      'FocusQueueService',
      'confirm(',
      'execute(',
    ]) {
      expect(host, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'public Android Assistant registration and new authority stay closed',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final gradle = _read('android/app/build.gradle.kts');
      final resources = Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      final review = _normalize(
        _read('docs/ANDROID_SYSTEM_ASSISTANT_INGRESS_REVIEW.md'),
      );

      expect(manifest, isNot(contains('android.app.shortcuts')));
      expect(manifest, isNot(contains('actions.intent')));
      expect(manifest, isNot(contains('com.google.android.gms.actions')));
      expect(
        resources.where((path) => path.endsWith('/xml/shortcuts.xml')),
        isEmpty,
      );
      expect(gradle, isNot(contains('androidx.core:core')));
      expect(review, contains('five text-free routes'));
      expect(review, contains('process memory'));
      expect(review, contains('shortcuts.xml'));
      expect(review, contains('remain closed'));
    },
  );

  test('Apple registration and all localization catalogs stay unchanged', () {
    const unchangedSubtrees = <String, String>{
      'ios': 'f7e23f4aa168c7ed57b3ba7198fe963abd37c064',
      'lib/l10n': 'aa4f2428f72e9a226290de58fd9df89f651a0ba5',
      'localization': 'ce1465a8184e13b5bbcaf4a38e3e678de2be7413',
    };

    for (final subtree in unchangedSubtrees.entries) {
      final status = Process.runSync('git', [
        'rev-parse',
        'HEAD:${subtree.key}',
      ]);
      expect(status.exitCode, 0, reason: (status.stderr as String).trim());
      expect((status.stdout as String).trim(), subtree.value);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
