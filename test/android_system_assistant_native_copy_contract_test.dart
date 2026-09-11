import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_android_system_assistant_native_review.arb';

  Map<String, Object?> proposal() =>
      jsonDecode(File(proposalPath).readAsStringSync()) as Map<String, Object?>;

  test('Phase 217I locks twenty-eight complete English native messages', () {
    final arb = proposal();
    final messages = arb.entries
        .where((entry) => entry.key != '@@locale' && !entry.key.startsWith('@'))
        .toList(growable: false);
    final metadata = arb.entries
        .where((entry) => entry.key.startsWith('@androidSystemAssistantNative'))
        .toList(growable: false);

    expect(arb['@@locale'], 'en');
    expect(messages, hasLength(28));
    expect(metadata, hasLength(28));
    for (final message in messages) {
      expect(message.key, startsWith('androidSystemAssistantNative'));
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

  test('five invocation examples are parameter-free review requests', () {
    final arb = proposal();
    final examples = arb.entries
        .where(
          (entry) =>
              !entry.key.startsWith('@') &&
              entry.key.endsWith('InvocationExample'),
        )
        .toList(growable: false);

    expect(examples, hasLength(5));
    for (final example in examples) {
      final value = example.value! as String;
      expect(value, startsWith('Review'));
      expect(value, isNot(contains('{')));
      expect(value, isNot(contains(r'$')));
    }
    final publicCopy = arb.entries
        .where((entry) => !entry.key.startsWith('@'))
        .map((entry) => entry.value)
        .whereType<String>()
        .join('\n');
    expect(RegExp(r'\{[^}]+\}').allMatches(publicCopy), isEmpty);
  });

  test('short and long labels mirror exactly five reviewed routes', () {
    final arb = proposal();
    const routeCopy = <String, (String, String, String)>{
      'ReadTimerStatus': (
        'Check Focus timer',
        'Review current Focus timer status',
        'Review my Focus timer status',
      ),
      'StartFocusTimer': (
        'Start Focus timer',
        'Review starting the ready Focus session',
        'Review starting a Focus timer',
      ),
      'PauseTimer': (
        'Pause Focus timer',
        'Review pausing the current Focus timer',
        'Review pausing my Focus timer',
      ),
      'ResumeTimer': (
        'Resume Focus timer',
        'Review resuming the paused Focus timer',
        'Review resuming my Focus timer',
      ),
      'OpenFocusQueue': (
        'Open Focus Queue',
        'Review opening Focus Queue',
        'Review opening Focus Queue',
      ),
    };

    for (final entry in routeCopy.entries) {
      expect(
        arb['androidSystemAssistantNative${entry.key}ShortLabel'],
        entry.value.$1,
      );
      expect(
        arb['androidSystemAssistantNative${entry.key}LongLabel'],
        entry.value.$2,
      );
      expect(
        arb['androidSystemAssistantNative${entry.key}InvocationExample'],
        entry.value.$3,
      );
    }
  });

  test('handoff and terminal outcomes never claim action success', () {
    final arb = proposal();

    expect(
      arb['androidSystemAssistantNativeReviewRequiredResult'],
      'Open FocusHaven to review this request. Nothing has happened yet.',
    );
    expect(
      arb['androidSystemAssistantNativePendingRequestResult'],
      contains('already has a request waiting'),
    );
    expect(
      arb['androidSystemAssistantNativeReviewRequiredAccessibilityLabel'],
      'FocusHaven request ready for review. No action has run.',
    );
    for (final key in <String>[
      'androidSystemAssistantNativeUnavailableResult',
      'androidSystemAssistantNativeCancelledResult',
      'androidSystemAssistantNativeExpiredResult',
      'androidSystemAssistantNativeRejectedResult',
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
      arb['androidSystemAssistantNativePrivacySummary'],
      'Only the action type and a private request code enter FocusHaven. No '
      'transcript or private content is included.',
    );
    expect(
      arb['androidSystemAssistantNativeNoParametersSummary'],
      'No time, task, or queue details can be added to this request.',
    );
    expect(
      arb['androidSystemAssistantNativeReviewInstruction'],
      'Open FocusHaven, review the exact effect, then choose Confirm action or '
      'Dismiss request.',
    );
  });

  test('copy stays outside Flutter and Android runtime resources', () {
    final arb = proposal();
    final sourceKeys = arb.keys
        .where((key) => key != '@@locale' && !key.startsWith('@'))
        .toSet();
    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);
    final resources = Directory(
      'android/app/src/main/res',
    ).listSync(recursive: true).whereType<File>().toList(growable: false);

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
    final androidResources = resources
        .where((file) => file.path.endsWith('.xml'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final key in sourceKeys) {
      expect(androidResources, isNot(contains(key)), reason: key);
    }
    expect(
      resources.where((file) => file.path.endsWith('/xml/shortcuts.xml')),
      isEmpty,
    );
  });
}
