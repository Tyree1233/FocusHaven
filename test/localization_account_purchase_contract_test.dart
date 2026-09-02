import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B5 account and private-record messages have complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'accountTitle',
      'accountSignedInAs',
      'accountContinueWithApple',
      'accountSignInWithGoogle',
      'accountDeleteCloudBackup',
      'accountDeleteLocalData',
      'accountDeleteAccount',
      'cloudBackupSucceeded',
      'cloudRestoreInvalid',
      'deleteCloudBackupMessage',
      'deleteLocalDataMessage',
      'deleteAccountMessage',
      'proTitle',
      'proSubscriptionDescription',
      'proUnlockForPrice',
      'proRestorePurchases',
      'journalTitle',
      'journalPrivacy',
      'journalTodayPrompt',
      'journalMostCommonMood',
      'journalMoodCount',
      'journalMoodCalm',
      'journalMoodFocusedSentence',
      'profileQuestionNaturalTime',
      'profileChoiceBuildMomentum',
      'profileTypeGentleFlow',
      'profileTipNightOwl',
      'profileQuestionProgress',
      'profileCurrentDescription',
      'reminderTitle',
      'reminderScheduledReceipt',
      'reminderTimeAndDays',
      'weekdayMondayShort',
      'weekdaySundayShort',
      'milestonesTitle',
      'milestonesUnlocked',
      'milestoneGoalGetterDetail',
      'focusHistoryTitle',
      'focusHistoryCompleted',
      'focusHistorySessionSeconds',
      'focusHistorySessionMinutes',
      'focusHistorySessionMetadata',
      'privacyPolicyOpenFailed',
      'accountDashboardTooltip',
      'accountSignInDashboardTooltip',
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

    const placeholderKeys = <String, Set<String>>{
      'accountSignedInAs': {'name'},
      'proUnlockForPrice': {'price'},
      'journalTodayPrompt': {'prompt'},
      'journalMostCommonMood': {'mood'},
      'journalMoodCount': {'mood', 'count'},
      'profileQuestionProgress': {'current', 'total'},
      'profileCurrentDescription': {'profile'},
      'reminderScheduledReceipt': {'time'},
      'reminderTimeAndDays': {'time', 'days'},
      'milestonesUnlocked': {'unlocked', 'total'},
      'focusHistoryCompleted': {'count'},
      'focusHistorySessionSeconds': {'count'},
      'focusHistorySessionMinutes': {'count'},
      'focusHistorySessionMetadata': {'duration', 'date', 'time'},
    };
    for (final entry in placeholderKeys.entries) {
      final metadata = catalog['@${entry.key}'] as Map<String, dynamic>;
      final placeholders = metadata['placeholders'] as Map<String, dynamic>;
      expect(placeholders.keys.toSet(), equals(entry.value), reason: entry.key);
    }
  });

  test('B5 production presentation uses generated localization access', () {
    final sources = <String>[
      'lib/widgets/account_sheet.dart',
      'lib/widgets/cloud_backup_actions.dart',
      'lib/widgets/pro_sheet.dart',
      'lib/widgets/reflection_journal_sheet.dart',
      'lib/widgets/journal_entry_dialog.dart',
      'lib/widgets/focus_profile_sheet.dart',
      'lib/widgets/reminder_sheet.dart',
      'lib/widgets/focus_milestones_sheet.dart',
      'lib/widgets/focus_history_sheet.dart',
      'lib/screens/timer_screen.dart',
    ].map(_read).join('\n');

    for (final getter in <String>[
      'accountSignedInAs',
      'cloudBackupSucceeded',
      'deleteAccountMessage',
      'proUnlockForPrice',
      'journalTodayPrompt',
      'profileQuestionNaturalTime',
      'reminderTimeAndDays',
      'milestonesUnlocked',
      'focusHistorySessionMetadata',
      'privacyPolicyOpenFailed',
    ]) {
      expect(sources, contains(getter), reason: getter);
    }

    for (final stale in <String>[
      "'Account settings'",
      "'Delete FocusHaven account?'",
      "'FocusHaven Pro'",
      "'Reflection journal'",
      "'Find your focus profile'",
      "'Scheduled focus time'",
      "'Focus milestones'",
      "'All focus sessions'",
      "'Unable to open the privacy policy right now.'",
    ]) {
      expect(sources, isNot(contains(stale)), reason: 'stale literal: $stale');
    }
  });

  test('B5 preserves private values and stable stored identifiers', () {
    final journalMapper = _read('lib/l10n/journal_localizations.dart');
    final journalSheet = _read('lib/widgets/reflection_journal_sheet.dart');
    final profileSheet = _read('lib/widgets/focus_profile_sheet.dart');
    final profileService = _read('lib/services/focus_profile_service.dart');

    for (final stableMood in <String>[
      "'Calm'",
      "'Focused'",
      "'Tired'",
      "'Stressed'",
      "'Grateful'",
    ]) {
      expect(journalMapper, contains(stableMood), reason: stableMood);
    }
    expect(journalSheet, contains('entry.reflection'));
    expect(journalSheet, contains('.dailyPromptFor(context.l10n)'));
    expect(journalSheet, contains('localizeJournalMood'));

    for (final stableProfile in <String>[
      "'Clear Starter'",
      "'Momentum Builder'",
      "'Deep Diver'",
      "'Gentle Flow'",
      "'Night Owl'",
    ]) {
      expect(profileSheet, contains(stableProfile), reason: stableProfile);
    }
    expect(profileService, contains("'focusProfile'"));
    expect(profileService, isNot(contains('context.l10n')));
  });

  test('B5 leaves service-generated text with B6 owners', () {
    for (final service in <String>[
      'lib/services/auth_service.dart',
      'lib/services/account_deletion_service.dart',
      'lib/services/cloud_sync_service.dart',
      'lib/services/iap_service.dart',
      'lib/services/journal_service.dart',
      'lib/services/focus_profile_service.dart',
      'lib/services/reminder_service.dart',
      'lib/services/notification_service.dart',
    ]) {
      final source = _read(service);
      expect(source, isNot(contains('context.l10n')), reason: service);
      expect(
        source,
        isNot(contains('focus_haven_localizations.dart')),
        reason: service,
      );
    }

    expect(_read('lib/widgets/account_sheet.dart'), contains('signInError'));
    expect(
      _read('lib/widgets/pro_sheet.dart'),
      contains('_showMessage(error.message)'),
    );
    expect(
      _read('lib/screens/timer_screen.dart'),
      contains('localizeAccountDeletionResult'),
    );
  });

  test('B5 scope is truthful and planned locales remain inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    for (final required in <String>[
      'B5 — Account, purchases, and private records',
      'Private account identity, journal and reflection content, task names',
      'Stable stored mood and profile identifiers remain unchanged',
      'B5 does not sign in or out, purchase or restore an entitlement',
      'Phase 215G-B English Flutter extraction is complete',
    ]) {
      expect(inventory, contains(required), reason: required);
    }
    expect(policy, contains('Phase 215G-B5'));
    expect(
      policy,
      contains('Phase 215G-B6C3 completes the English Flutter extraction'),
    );
    expect(roadmap, contains('English Flutter extraction shipped'));
    expect(
      roadmap,
      contains('Phase 215G-B English Flutter extraction is complete'),
    );
    expect(readme, contains('Phase 215G-B5'));
    expect(
      readme,
      contains('completed Phase 215G-B English Flutter extraction'),
    );
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
