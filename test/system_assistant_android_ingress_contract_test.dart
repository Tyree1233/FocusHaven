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
    'Android discovery stays detached from retained review-only ingress',
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
      expect(manifest, isNot(contains('@xml/shortcuts')));
      expect(manifest, isNot(contains('com.google.android.gms.actions')));
      expect(
        resources.where((path) => path.endsWith('/xml/shortcuts.xml')),
        hasLength(1),
      );
      expect(gradle, contains('androidx.core:core:1.17.0'));
      expect(review, contains('five text-free routes'));
      expect(review, contains('process memory'));
      expect(review, contains('shortcuts.xml'));
      expect(review, contains('Phase 217K'));
      expect(review, contains('twenty-eight complete messages'));
      expect(review, contains('outside every Flutter runtime catalog'));
      expect(review, contains('seventeen isolated Android resource files'));
      expect(review, contains('execution remain closed'));
    },
  );

  test(
    'Apple system-assistant registration and native copy stay unchanged',
    () {
      // These blob identities match the reviewed Phase 217K files. Inspect the
      // actual working files, not HEAD: whole-directory pins rejected unrelated
      // Phase 218 background audio and could not detect uncommitted changes.
      // Catalog preservation is checked separately by localization activation
      // tests and soundscape_localization_test's exact pre-delta/delta hashes.
      const unchangedFiles = <String, String>{
        'ios/Runner/AppleSystemAssistantNativeCopy.xcstrings':
            '13d580e2491217181816bc0414cc446cb15c08fb',
        'ios/Runner/HavenSystemAssistantAppleAppIntents.swift':
            '42c84b17e7e975956933e0b40ff797346ef2b72c',
        'ios/Runner/HavenSystemAssistantAppleIngress.swift':
            'addaf700a7967d9a39c218f73a8117abe63e7f82',
        'ios/Runner/HavenSystemAssistantAppleNativeCopy.swift':
            '2ceabdfe2ce84ef180e61b7a99af4e15293b12f4',
        'ios/Runner/HavenSystemAssistantApplePlatformAdapter.swift':
            '483427842f6008523fe66d3d15021072da96f39f',
      };

      for (final file in unchangedFiles.entries) {
        final status = Process.runSync('git', ['hash-object', '--', file.key]);
        expect(status.exitCode, 0, reason: (status.stderr as String).trim());
        expect((status.stdout as String).trim(), file.value, reason: file.key);
      }
    },
  );
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
