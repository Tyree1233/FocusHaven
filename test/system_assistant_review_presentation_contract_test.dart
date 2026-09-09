import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 217C presentation consumes only one opaque review', () {
    final widget = _read('lib/widgets/haven_system_intent_review_card.dart');

    for (final required in <String>[
      'final HavenSystemIntentReview review',
      'final HavenSystemIntentReviewCopy copy',
      'final HavenSystemIntentReviewCallback onDismiss',
      'final HavenSystemIntentReviewCallback onConfirm',
      'if (_settled) return',
      'setState(() => _settled = true)',
      "'system-intent-dismiss-review'",
      "'system-intent-confirm-review'",
      'label: copy.summarySemantics',
      'liveRegion: true',
    ]) {
      expect(widget, contains(required), reason: required);
    }
    expect(widget, contains('review.interpretation'));
    expect(widget, contains('review.effect'));
    expect(widget, isNot(contains('HavenActionProposal')));
  });

  test('copy and capability owners remain outside presentation', () {
    final widget = _read('lib/widgets/haven_system_intent_review_card.dart');

    for (final forbidden in <String>[
      'AppLocalizations',
      'context.l10n',
      'HavenActionEngine',
      'HavenSystemIntentReviewService(',
      'HavenSystemIntentService',
      'TimerService',
      'FocusQueueService',
      'SharedPreferences',
      'Firebase',
      'http.',
      'MethodChannel',
      'EventChannel',
      'invokeMethod',
      'confirm(',
      'dismiss(',
    ]) {
      expect(widget, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(widget, contains('performs no localization, interpolation, or'));
    expect(widget, contains('sentence assembly'));
  });

  test('production and native adapters remain closed in Phase 217C', () {
    final providers = _read('lib/providers/app_providers.dart');
    final timerScreen = _read('lib/screens/timer_screen.dart');
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    for (final production in <String>[providers, timerScreen]) {
      expect(production, isNot(contains('HavenSystemIntentReviewCard')));
      expect(production, isNot(contains('HavenSystemIntentReviewService')));
    }
    expect(androidManifest, isNot(contains('actions.intent')));
    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(pubspec, isNot(contains('app_intents')));
    expect(pubspec, isNot(contains('shortcuts')));
  });
}

String _read(String path) => File(path).readAsStringSync();
