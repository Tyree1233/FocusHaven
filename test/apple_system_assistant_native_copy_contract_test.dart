import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_apple_system_assistant_native_review.arb';

  Map<String, Object?> proposal() =>
      jsonDecode(File(proposalPath).readAsStringSync()) as Map<String, Object?>;

  test('Phase 217F locks twenty-eight complete English native messages', () {
    final arb = proposal();
    final messages = arb.entries
        .where((entry) => entry.key != '@@locale' && !entry.key.startsWith('@'))
        .toList(growable: false);
    final metadata = arb.entries
        .where((entry) => entry.key.startsWith('@appleSystemAssistantNative'))
        .toList(growable: false);

    expect(arb['@@locale'], 'en');
    expect(messages, hasLength(28));
    expect(metadata, hasLength(28));
    for (final message in messages) {
      expect(message.key, startsWith('appleSystemAssistantNative'));
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

  test('exactly five invocation phrases use only applicationName', () {
    final arb = proposal();
    final phrases = arb.entries
        .where(
          (entry) => !entry.key.startsWith('@') && entry.key.endsWith('Phrase'),
        )
        .toList(growable: false);

    expect(phrases, hasLength(5));
    for (final phrase in phrases) {
      final value = phrase.value! as String;
      final metadata = arb['@${phrase.key}']! as Map<String, Object?>;
      final placeholders = metadata['placeholders']! as Map<String, Object?>;
      expect(value, startsWith('Review'));
      expect(RegExp(r'\{applicationName\}').allMatches(value), hasLength(1));
      expect(RegExp(r'\{[^}]+\}').allMatches(value), hasLength(1));
      expect(placeholders.keys.toSet(), {'applicationName'});
      expect(placeholders['applicationName'], {
        'type': 'String',
        'example': 'FocusHaven',
      });
    }
  });

  test('titles and descriptions mirror exactly the five reviewed routes', () {
    final arb = proposal();
    const routeCopy = <String, (String, String)>{
      'ReadTimerStatus': (
        'Check Focus timer status',
        'Prepare a request to review the current Focus timer status in '
            'FocusHaven.',
      ),
      'StartFocusTimer': (
        'Start Focus timer',
        'Prepare a request to review starting the ready Focus session in '
            'FocusHaven.',
      ),
      'PauseTimer': (
        'Pause Focus timer',
        'Prepare a request to review pausing the current Focus timer in '
            'FocusHaven.',
      ),
      'ResumeTimer': (
        'Resume Focus timer',
        'Prepare a request to review resuming the paused Focus timer in '
            'FocusHaven.',
      ),
      'OpenFocusQueue': (
        'Open Focus Queue',
        'Prepare a request to review opening Focus Queue in FocusHaven.',
      ),
    };

    for (final entry in routeCopy.entries) {
      expect(
        arb['appleSystemAssistantNative${entry.key}Title'],
        entry.value.$1,
      );
      expect(
        arb['appleSystemAssistantNative${entry.key}Description'],
        entry.value.$2,
      );
      expect(arb, contains('appleSystemAssistantNative${entry.key}Phrase'));
    }
  });

  test('handoff and terminal outcomes never claim action success', () {
    final arb = proposal();

    expect(
      arb['appleSystemAssistantNativeReviewRequiredResult'],
      'Open FocusHaven to review this request. Nothing has happened yet.',
    );
    expect(
      arb['appleSystemAssistantNativePendingRequestResult'],
      contains('already has a request waiting'),
    );
    expect(
      arb['appleSystemAssistantNativeReviewRequiredAccessibilityLabel'],
      'FocusHaven request ready for review. No action has run.',
    );
    for (final key in <String>[
      'appleSystemAssistantNativeUnavailableResult',
      'appleSystemAssistantNativeCancelledResult',
      'appleSystemAssistantNativeExpiredResult',
      'appleSystemAssistantNativeRejectedResult',
    ]) {
      final value = arb[key]! as String;
      expect(
        value.contains('Nothing changed') ||
            value.contains('did not change your timer or queue'),
        isTrue,
        reason: key,
      );
    }
    final publicCopy = arb.entries
        .where((entry) => !entry.key.startsWith('@'))
        .map((entry) => entry.value)
        .whereType<String>()
        .join('\n');
    for (final forbidden in <String>[
      'Timer started',
      'Timer paused',
      'Timer resumed',
      'Queue opened',
      'Action completed',
      'I did it',
    ]) {
      expect(publicCopy, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('privacy and parameter boundaries stay explicit and complete', () {
    final arb = proposal();

    expect(
      arb['appleSystemAssistantNativePrivacySummary'],
      'Only the action type and a private request code enter FocusHaven. No '
      'transcript or private content is included.',
    );
    expect(
      arb['appleSystemAssistantNativeNoParametersSummary'],
      'No time, task, or queue details can be added to this request.',
    );
    expect(
      arb['appleSystemAssistantNativeReviewInstruction'],
      'Open FocusHaven, review the exact effect, then choose Confirm action or '
      'Dismiss request.',
    );
  });

  test('proposal remains absent from runtime and native registration', () {
    final arb = proposal();
    final sourceKeys = arb.keys
        .where((key) => key != '@@locale' && !key.startsWith('@'))
        .toSet();
    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);
    final runnerSource = Directory('ios/Runner')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.swift'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sourceKeys, hasLength(28));
    expect(catalogs, hasLength(17));
    for (final catalog in catalogs) {
      final runtime =
          jsonDecode(catalog.readAsStringSync()) as Map<String, Object?>;
      expect(
        runtime.keys.toSet().intersection(sourceKeys),
        isEmpty,
        reason: catalog.path,
      );
    }
    for (final key in sourceKeys) {
      expect(runnerSource, isNot(contains(key)), reason: key);
    }
    expect(runnerSource, isNot(contains('import AppIntents')));
    expect(runnerSource, isNot(contains(': AppIntent')));
    expect(runnerSource, isNot(contains('AppShortcutsProvider')));
  });
}
