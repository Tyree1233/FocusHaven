import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const proposalPath =
      'localization/proposals/app_en_system_assistant_review.arb';

  Map<String, Object?> readArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  test('all seventeen catalogs contain one complete reviewed delta', () {
    final proposal = readArb(proposalPath);
    final messageKeys = proposal.keys
        .where((key) => key != '@@locale' && !key.startsWith('@'))
        .toSet();
    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);

    expect(messageKeys, hasLength(11));
    expect(catalogs, hasLength(17));
    for (final catalog in catalogs) {
      final arb = readArb(catalog.path);
      final runtimeKeys = arb.keys
          .where((key) => key.startsWith('systemAssistantReview'))
          .toSet();
      expect(runtimeKeys, messageKeys, reason: catalog.path);
      for (final key in messageKeys) {
        expect(arb[key], isA<String>(), reason: '${catalog.path}:$key');
        expect((arb[key]! as String).trim(), isNotEmpty);
        expect(
          arb['@$key'],
          proposal['@$key'],
          reason: '${catalog.path}:@$key',
        );
      }
    }

    final english = readArb('lib/l10n/app_en.arb');
    for (final key in messageKeys) {
      expect(english[key], proposal[key], reason: key);
    }
  });

  test(
    'base Portuguese is derived only from reviewed Brazilian Portuguese',
    () {
      final ptBr = readArb('lib/l10n/app_pt_BR.arb');
      final pt = readArb('lib/l10n/app_pt.arb');
      ptBr.remove('@@locale');
      pt.remove('@@locale');
      expect(pt, ptBr);
    },
  );

  test('production host retains the bounded review and engine path', () {
    final main = File('lib/main.dart').readAsStringSync();
    final providers = File(
      'lib/providers/app_providers.dart',
    ).readAsStringSync();
    final inbox = File(
      'lib/services/haven_system_intent_inbox.dart',
    ).readAsStringSync();
    final host = File(
      'lib/widgets/haven_system_intent_production_host.dart',
    ).readAsStringSync();

    expect(main, contains('HavenSystemIntentProductionHost'));
    expect(providers, contains('havenSystemIntentInboxProvider'));
    expect(inbox, contains('HavenSystemIntentRequest? _pendingRequest'));
    expect(inbox, contains('if (_pendingRequest != null) return false'));
    for (final required in <String>[
      'HavenSystemIntentService()',
      'HavenSystemIntentReviewService(',
      'HavenActionEngine(',
      'HavenSystemIntentReviewCard(',
      '_reviewService.isCurrent(',
      '_reviewService.dismiss(',
      '_reviewService.confirm(',
      'Timer(remaining, _invalidateReview)',
    ]) {
      expect(host, contains(required), reason: required);
    }
  });

  test('native registration, permissions, and dependencies stay closed', () {
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    final iosEntitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(iosInfo, isNot(contains('INIntentsSupported')));
    expect(iosInfo, isNot(contains('NSSiriUsageDescription')));
    expect(iosEntitlements, isNot(contains('com.apple.developer.siri')));
    expect(androidManifest, isNot(contains('actions.intent')));
    expect(pubspec, isNot(contains('app_intents')));
    expect(pubspec, isNot(contains('shortcuts')));
  });
}
