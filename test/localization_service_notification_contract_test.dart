import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B6A notification and bounded service copy has metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'notificationFocusChannelName',
      'notificationFocusChannelDescription',
      'notificationDailyChannelName',
      'notificationDailyChannelDescription',
      'notificationHavenWindowChannelName',
      'notificationHavenWindowChannelDescription',
      'notificationTestTitle',
      'notificationTestBody',
      'notificationDailyTitle',
      'notificationDailyBody',
      'notificationHavenWindowTitle',
      'notificationHavenWindowBody',
      'timerSessionFocusLabel',
      'timerSessionShortBreakLabel',
      'timerSessionLongBreakLabel',
      'timerSessionCompleteTitle',
      'timerFocusCompletionBody',
      'timerShortBreakCompletionBody',
      'timerLongBreakCompletionBody',
      'accountDeletionDeletedReceipt',
      'accountDeletionAppleRevocationReceipt',
      'accountDeletionNotSignedInReceipt',
      'accountDeletionCancelledReceipt',
      'accountDeletionReauthenticationReceipt',
      'accountDeletionUnsupportedProviderReceipt',
      'accountDeletionUnavailableReceipt',
    };

    for (final key in requiredKeys) {
      expect(catalog[key], isA<String>(), reason: 'missing message: $key');
      final metadata = catalog['@$key'];
      expect(metadata, isA<Map<String, dynamic>>(), reason: 'metadata: $key');
      expect(
        (metadata as Map<String, dynamic>)['description'],
        isNotEmpty,
        reason: 'description: $key',
      );
    }

    final titleMetadata =
        catalog['@timerSessionCompleteTitle'] as Map<String, dynamic>;
    final placeholders = titleMetadata['placeholders'] as Map<String, dynamic>;
    expect(placeholders.keys.toSet(), equals({'session'}));
  });

  test('B6A production notification paths use generated catalog values', () {
    final notification = _read('lib/services/notification_service.dart');
    final timer = _read('lib/services/timer_service.dart');

    for (final getter in <String>[
      'notificationFocusChannelName',
      'notificationDailyChannelName',
      'notificationHavenWindowChannelName',
      'notificationTestTitle',
      'notificationDailyTitle',
      'notificationHavenWindowTitle',
    ]) {
      expect(notification, contains(getter), reason: getter);
    }
    for (final getter in <String>[
      'timerSessionCompleteTitle',
      'timerSessionFocusLabel',
      'timerFocusCompletionBody',
      'timerShortBreakCompletionBody',
      'timerLongBreakCompletionBody',
    ]) {
      expect(timer, contains(getter), reason: getter);
    }

    for (final stale in <String>[
      "'FocusHaven notifications are ready'",
      "'Your scheduled focus time'",
      "'Your possible Haven Window is here'",
      "'Alerts when a FocusHaven timer finishes.'",
      "'You showed up for what matters. Let yourself take a real breath.'",
    ]) {
      expect('$notification\n$timer', isNot(contains(stale)), reason: stale);
    }
  });

  test(
    'B6A account deletion keeps stable outcomes and localizes presentation',
    () {
      final service = _read('lib/services/account_deletion_service.dart');
      final mapper = _read('lib/l10n/service_localizations.dart');
      final screen = _read('lib/screens/timer_screen.dart');

      for (final status in <String>[
        'deleted',
        'deletedAppleRevocationRequired',
        'notSignedIn',
        'reauthenticationCancelled',
        'reauthenticationUnavailable',
        'unsupportedProvider',
        'unavailable',
      ]) {
        expect(service, contains('AccountDeletionStatus.$status'));
        expect(mapper, contains('AccountDeletionStatus.$status'));
      }
      expect(service, isNot(contains('String get message')));
      expect(screen, contains('localizeAccountDeletionResult'));
    },
  );

  test('B6A scope remains partial and planned locales stay inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    expect(
      inventory,
      contains('B6A — Notifications and bounded service receipts'),
    );
    expect(inventory, contains('B6B1 — Generated Haven Planner guidance'));
    expect(
      inventory,
      contains('B6B2 — Restorative and optional-system guidance'),
    );
    expect(inventory, contains('B6C1 — Haven action service results'));
    expect(policy, contains('Phase 215G-B6A'));
    expect(policy, contains('Phase 215G-B is not complete'));
    expect(roadmap, contains('B1–B6C1 extraction shipped'));
    expect(readme, contains('Phase 215G-B6A'));
    expect(
      locales,
      contains("static const productionLocales = <Locale>[Locale('en')]"),
    );
    expect(
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .length,
      1,
    );
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
