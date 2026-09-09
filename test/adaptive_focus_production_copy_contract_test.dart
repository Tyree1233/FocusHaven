import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_adaptive_focus_review.arb';

  Map<String, Object?> proposal() =>
      jsonDecode(File(proposalPath).readAsStringSync()) as Map<String, Object?>;

  test('Phase 216D locks seventeen complete English proposal messages', () {
    final arb = proposal();
    final messages = arb.entries
        .where((entry) => entry.key != '@@locale' && !entry.key.startsWith('@'))
        .toList(growable: false);
    final metadata = arb.entries
        .where((entry) => entry.key.startsWith('@adaptiveFocus'))
        .toList(growable: false);

    expect(arb['@@locale'], 'en');
    expect(messages, hasLength(17));
    expect(metadata, hasLength(17));
    for (final message in messages) {
      expect(message.key, startsWith('adaptiveFocus'));
      expect(message.value, isA<String>());
      expect((message.value! as String).trim(), isNotEmpty);
      expect(arb['@${message.key}'], isA<Map<String, Object?>>());
    }
  });

  test('Phase 216D proposal keeps exact placeholder metadata', () {
    final arb = proposal();

    void expectPlaceholders(String key, Set<String> expected) {
      final message = arb[key]! as String;
      final metadata = arb['@$key']! as Map<String, Object?>;
      final placeholders = metadata['placeholders']! as Map<String, Object?>;
      expect(placeholders.keys.toSet(), expected, reason: key);
      for (final placeholder in expected) {
        expect(
          message,
          contains('{$placeholder}'),
          reason: '$key:$placeholder',
        );
        final definition = placeholders[placeholder]! as Map<String, Object?>;
        expect(definition['type'], anyOf('int', 'String'));
        expect(definition['example'], isA<String>());
      }
    }

    expectPlaceholders('adaptiveFocusCurrentPlan', {
      'focusMinutes',
      'breakMinutes',
    });
    expectPlaceholders('adaptiveFocusSuggestedPlan', {
      'focusMinutes',
      'breakMinutes',
    });
    expectPlaceholders('adaptiveFocusReviewSummary', {
      'currentFocusMinutes',
      'currentBreakMinutes',
      'suggestedFocusMinutes',
      'suggestedBreakMinutes',
      'reason',
    });
    expectPlaceholders('adaptiveFocusApplied', {
      'focusMinutes',
      'breakMinutes',
    });
  });

  test(
    'Phase 216D proposal states the choice, privacy, and no-start truth',
    () {
      final arb = proposal();

      expect(
        arb['adaptiveFocusPrivacy'],
        'Built on this device from text-free focus signals. No task, journal, '
        'coaching, transcript, or account text is used.',
      );
      expect(
        arb['adaptiveFocusNoAutomaticChange'],
        'Nothing changes unless you choose Use suggestion. The timer will stay '
        'stopped.',
      );
      expect(arb['adaptiveFocusKeepCurrent'], 'Keep current settings');
      expect(arb['adaptiveFocusUseSuggestion'], 'Use suggestion');
      expect(arb['adaptiveFocusApplied'], contains('No session was started.'));
      expect(
        arb['adaptiveFocusChanged'],
        'The timer changed, so this suggestion was not applied.',
      );
    },
  );

  test('Phase 216D reviewed delta is complete in every runtime catalog', () {
    final source = proposal();
    final sourceKeys = source.keys
        .where((key) => key != '@@locale' && !key.startsWith('@'))
        .toSet();
    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);

    expect(catalogs, hasLength(17));
    for (final catalog in catalogs) {
      final arb =
          jsonDecode(catalog.readAsStringSync()) as Map<String, Object?>;
      final keys = arb.keys
          .where((key) => key.startsWith('adaptiveFocus'))
          .toSet();
      expect(keys, sourceKeys, reason: catalog.path);
      for (final key in sourceKeys) {
        expect(arb[key], isA<String>(), reason: '${catalog.path}:$key');
        expect((arb[key]! as String).trim(), isNotEmpty);
        expect(arb['@$key'], source['@$key'], reason: '${catalog.path}:@$key');
      }
    }

    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, Object?>;
    for (final key in sourceKeys) {
      expect(english[key], source[key], reason: key);
    }

    final ptBr =
        jsonDecode(File('lib/l10n/app_pt_BR.arb').readAsStringSync())
            as Map<String, Object?>;
    final pt =
        jsonDecode(File('lib/l10n/app_pt.arb').readAsStringSync())
            as Map<String, Object?>;
    ptBr.remove('@@locale');
    pt.remove('@@locale');
    expect(pt, ptBr);
  });

  test('Phase 216D opens only the reviewed owner-bounded placement', () {
    final timerScreen = File(
      'lib/screens/timer_screen.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/providers/app_providers.dart',
    ).readAsStringSync();
    final policy = File(
      'docs/ADAPTIVE_FOCUS_PRODUCTION_REVIEW.md',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    final forecast = timerScreen.indexOf('FocusForecastCard(');
    final adaptive = timerScreen.indexOf('AdaptiveFocusProductionReview(');
    final window = timerScreen.indexOf('HavenWindowCard(');
    expect(forecast, greaterThanOrEqualTo(0));
    expect(adaptive, greaterThan(forecast));
    expect(window, greaterThan(adaptive));
    expect(providers, contains('adaptiveFocusDelegationServiceProvider'));
    expect(providers, contains('adaptiveFocusOwnerStateProvider'));
    for (final required in <String>[
      'production presentation is open',
      'immediately after Focus Forecast',
      'fresh, stopped, incomplete Focus session',
      'The card must disappear',
      'fifteen independently reviewed languages',
      'mechanical base `pt` fallback',
      'must not assemble a production sentence from translated fragments',
      'grants no timer-start, queue, calendar, Haven Action, local-AI, '
          'remote-AI, network, deployment, or publication authority',
    ]) {
      expect(policy, contains(required), reason: required);
    }
  });
}
