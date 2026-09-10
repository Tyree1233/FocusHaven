import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple ingress mirrors exactly five text-free reviewed routes', () {
    final native = _read('ios/Runner/HavenSystemAssistantAppleIngress.swift');
    final bridge = _read(
      'lib/services/haven_system_assistant_apple_platform_bridge.dart',
    );
    const routes = <String>[
      'readTimerStatus',
      'startFocusTimer',
      'pauseTimer',
      'resumeTimer',
      'openFocusQueue',
    ];
    for (final route in routes) {
      expect(native, contains('case $route'));
      expect(bridge, contains("'$route'"));
    }
    expect(native, contains('CaseIterable'));
    expect(native, contains('maximumInvocationIDLength = 128'));
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
      'UserDefaults',
      'Keychain',
    ]) {
      expect(native, isNot(contains(forbidden)), reason: forbidden);
      expect(bridge, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('delivery is acknowledged before native memory can clear', () {
    final native = _read(
      'ios/Runner/HavenSystemAssistantApplePlatformAdapter.swift',
    );
    final ingress = _read('ios/Runner/HavenSystemAssistantAppleIngress.swift');
    final bridge = _read(
      'lib/services/haven_system_assistant_apple_platform_bridge.dart',
    );
    final inbox = _read('lib/services/haven_system_intent_inbox.dart');

    expect(native, contains('if result as? Bool == true'));
    expect(native, contains('clearIfMatches(invocationID:'));
    expect(ingress, contains('guard pendingRequest == nil'));
    expect(ingress, contains('pendingRequest?.invocationID == invocationID'));
    expect(bridge, contains('return _inbox.submit(_parseRequest(value))'));
    expect(inbox, contains('if (_pendingRequest != null) return false'));
  });

  test('public Apple and Android assistant registration stays closed', () {
    final runnerSources = Directory('ios/Runner')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');
    final iosInfo = _read('ios/Runner/Info.plist');
    final entitlements = _read('ios/Runner/Runner.entitlements');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final pubspec = _read('pubspec.yaml');
    final review = _normalize(
      _read('docs/APPLE_SYSTEM_ASSISTANT_INGRESS_REVIEW.md'),
    );

    expect(runnerSources, isNot(contains('import AppIntents')));
    expect(runnerSources, isNot(contains(': AppIntent')));
    expect(runnerSources, isNot(contains('AppShortcutsProvider')));
    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(entitlements, isNot(contains('com.apple.developer.siri')));
    expect(androidManifest, isNot(contains('actions.intent')));
    expect(pubspec, isNot(contains('app_intents')));
    expect(pubspec, isNot(contains('shortcuts')));
    expect(
      review,
      contains(
        'public Siri, App Intent, and App Shortcut registration disabled',
      ),
    );
    expect(review, contains('independent fifteen-language review'));
    expect(review, contains('twenty-eight complete messages'));
    expect(review, contains('not imported by Runner'));
    expect(review, contains('No provider draft, CSV, workbook'));
  });

  test('production wiring terminates at the existing review inbox', () {
    final app = _read('lib/main.dart');
    final providers = _read('lib/providers/app_providers.dart');
    final host = _read(
      'lib/widgets/haven_system_assistant_apple_platform_host.dart',
    );
    final appDelegate = _read('ios/Runner/AppDelegate.swift');

    expect(app, contains('HavenSystemAssistantApplePlatformHost'));
    expect(
      providers,
      contains('havenSystemAssistantApplePlatformControllerProvider'),
    );
    expect(host, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    expect(host, contains('AppLifecycleState.resumed'));
    expect(appDelegate, contains('HavenSystemAssistantApplePlatformAdapter'));
    expect(appDelegate, contains('deliverPendingRequest()'));
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
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
