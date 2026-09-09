import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_system_assistant_review.arb';

  Map<String, Object?> proposal() =>
      jsonDecode(File(proposalPath).readAsStringSync()) as Map<String, Object?>;

  test('Phase 217D locks eleven complete English proposal messages', () {
    final arb = proposal();
    final messages = arb.entries
        .where((entry) => entry.key != '@@locale' && !entry.key.startsWith('@'))
        .toList(growable: false);
    final metadata = arb.entries
        .where((entry) => entry.key.startsWith('@systemAssistantReview'))
        .toList(growable: false);

    expect(arb['@@locale'], 'en');
    expect(messages, hasLength(11));
    expect(metadata, hasLength(11));
    for (final message in messages) {
      expect(message.key, startsWith('systemAssistantReview'));
      expect(message.value, isA<String>());
      expect((message.value! as String).trim(), isNotEmpty);
      final messageMetadata = arb['@${message.key}'];
      expect(messageMetadata, isA<Map<String, Object?>>());
      expect(
        (messageMetadata! as Map<String, Object?>)['description'],
        isA<String>(),
      );
    }
  });

  test('semantic summary locks three complete string placeholders', () {
    final arb = proposal();
    final summary = arb['systemAssistantReviewSummary']! as String;
    final metadata =
        arb['@systemAssistantReviewSummary']! as Map<String, Object?>;
    final placeholders = metadata['placeholders']! as Map<String, Object?>;

    expect(placeholders.keys.toSet(), {'interpretation', 'effect', 'risk'});
    for (final placeholder in placeholders.entries) {
      expect(summary, contains('{${placeholder.key}}'));
      final definition = placeholder.value! as Map<String, Object?>;
      expect(definition['type'], 'String');
      expect(definition['example'], isA<String>());
      expect((definition['example']! as String).trim(), isNotEmpty);
    }
    expect(RegExp(r'\{[^}]+\}').allMatches(summary), hasLength(3));
  });

  test('copy states exact source, privacy, freshness, and choice truth', () {
    final arb = proposal();

    expect(
      arb['systemAssistantReviewSource'],
      'A supported system assistant prepared this request. FocusHaven has not '
      'acted on it.',
    );
    expect(
      arb['systemAssistantReviewPrivacy'],
      'Only the action type and a private request code enter FocusHaven. No '
      'transcript, task, journal, coaching, or account text is included.',
    );
    expect(
      arb['systemAssistantReviewFreshness'],
      'This review expires after two minutes. If the timer or queue changes '
      'first, the request will be rejected.',
    );
    expect(
      arb['systemAssistantReviewConfirmation'],
      'Nothing happens unless you choose Confirm action in FocusHaven.',
    );
    expect(arb['systemAssistantReviewDismiss'], 'Dismiss request');
    expect(arb['systemAssistantReviewConfirm'], 'Confirm action');
    expect(
      arb['systemAssistantReviewInformationalRisk'],
      contains('cannot change your timer or queue'),
    );
    expect(
      arb['systemAssistantReviewReversibleRisk'],
      contains('safely change it again in FocusHaven'),
    );
  });

  test('proposal remains absent from all seventeen runtime catalogs', () {
    final sourceKeys = proposal().keys
        .where((key) => key.startsWith('systemAssistantReview'))
        .toSet();
    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);

    expect(sourceKeys, hasLength(11));
    expect(catalogs, hasLength(17));
    for (final catalog in catalogs) {
      final arb =
          jsonDecode(catalog.readAsStringSync()) as Map<String, Object?>;
      for (final key in sourceKeys) {
        expect(arb, isNot(contains(key)), reason: '${catalog.path}:$key');
        expect(arb, isNot(contains('@$key')), reason: '${catalog.path}:@$key');
      }
    }
  });

  test('Phase 217D keeps production placement and native authority closed', () {
    final policy = File(
      'docs/SYSTEM_ASSISTANT_PRODUCTION_REVIEW.md',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
    final providers = File(
      'lib/providers/app_providers.dart',
    ).readAsStringSync();
    final timerScreen = File(
      'lib/screens/timer_screen.dart',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final required in <String>[
      'eleven public interface messages',
      'fifteen non-English production languages',
      'Derive base `pt` only',
      'must not assemble a sentence from translated fragments',
      'does not choose or implement a production host',
      'Review Apple and Android native adapters separately',
      'grants no timer, queue, navigation, persistence, provider, network, AI',
    ]) {
      expect(policy, contains(required), reason: required);
    }
    expect(providers, isNot(contains('HavenSystemIntentReviewCard')));
    expect(timerScreen, isNot(contains('HavenSystemIntentReviewCard')));
    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(androidManifest, isNot(contains('actions.intent')));
  });
}
