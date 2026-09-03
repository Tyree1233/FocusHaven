import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/haven_plan.dart';
import 'package:focushaven/services/haven_plan_service.dart';

void main() {
  test('B6C3 remaining service catalog has complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'authServiceGuest',
      'authServiceGoogleSignInCancelled',
      'authServiceGoogleSignInFailed',
      'authServiceAppleSignInUnavailable',
      'authServiceAppleSignInCancelled',
      'authServiceAppleSignInFailed',
      'authServiceSignOutFailed',
      'iapServicePurchasingUnavailable',
      'iapServiceLifetimePurchasesUnavailable',
      'iapServiceProUnavailable',
      'iapServicePurchaseCouldNotStart',
      'iapServiceStoreCouldNotLoadPro',
      'journalServicePromptGratitude',
      'journalServicePromptFocus',
      'journalServicePromptTomorrow',
      'journalServicePromptSmallWin',
      'journalServicePromptRelease',
      'journalServicePromptCalm',
      'journalServicePromptKindness',
      'timerServiceExportTitle',
      'timerServiceExportedAt',
      'timerServiceExportSummaryHeading',
      'timerServiceExportTotalFocusTime',
      'timerServiceExportCompletedSessions',
      'timerServiceExportCurrentStreak',
      'timerServiceExportDailyGoal',
      'timerServiceExportSessionsHeading',
      'timerServiceExportNoSessions',
      'timerServiceExportFocusSession',
      'timerServiceExportSessionRow',
      'timerServiceExportSeconds',
      'timerServiceExportMinutes',
      'timerServiceExportMinutesAndSeconds',
      'havenPlanServiceChooseSmallStep',
      'havenPlanServiceNameVisibleAction',
      'havenPlanServiceOpenSmallestAction',
      'havenPlanServiceRecentRecovery',
      'havenPlanServiceReflectionTooMuch',
      'havenPlanServiceReflectionAboutRight',
      'havenPlanServiceReflectionCouldDoMore',
      'havenPlanServicePersonalRhythm',
      'havenPlanServiceGentleStart',
      'havenPlanServiceFreshStartSpacious',
      'havenPlanServiceFreshStartSteady',
      'havenPlanServiceEnergyBound',
      'havenPlanServiceTimeBound',
      'havenPlanServiceExplanationWithDetails',
      'livingLanternServicePendingHeadline',
      'livingLanternServicePendingDetail',
      'livingLanternServiceBreakRunningHeadline',
      'livingLanternServiceBreakRunningDetail',
      'livingLanternServiceBreakCompleteHeadline',
      'livingLanternServiceBreakCompleteDetail',
      'livingLanternServiceBreakIdleHeadline',
      'livingLanternServiceBreakIdleDetail',
      'livingLanternServiceFocusCompleteHeadline',
      'livingLanternServiceFocusCompleteDetail',
      'livingLanternServiceFocusRunningHeadline',
      'livingLanternServiceFocusRunningDetail',
      'livingLanternServiceRecoveryHeadline',
      'livingLanternServiceRecoveryDetail',
      'livingLanternServiceReadyHeadline',
      'livingLanternServiceReadyWithHistoryDetail',
      'livingLanternServiceReadyWithoutHistoryDetail',
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

    expect(_placeholderKeys(catalog, 'timerServiceExportSessionRow'), {
      'dateTime',
      'duration',
      'task',
    });
    expect(_placeholderKeys(catalog, 'havenPlanServiceOpenSmallestAction'), {
      'task',
    });
  });

  test('B6C3 production paths pass the selected catalog explicitly', () {
    final account = _normalize(_read('lib/widgets/account_sheet.dart'));
    final pro = _normalize(_read('lib/widgets/pro_sheet.dart'));
    final reflection = _normalize(
      _read('lib/widgets/reflection_journal_sheet.dart'),
    );
    final timer = _normalize(_read('lib/screens/timer_screen.dart'));
    final providers = _normalize(_read('lib/providers/app_providers.dart'));
    final planner = _normalize(_read('lib/widgets/haven_plan_sheet.dart'));

    expect(account, contains('signInWithGoogle(localizations: l10n)'));
    expect(account, contains('signInWithApple(localizations: l10n)'));
    expect(account, contains('signOut(localizations: l10n)'));
    expect(pro, contains('proPrice(localizations: context.l10n)'));
    expect(pro, contains('buyPro(localizations: l10n)'));
    expect(reflection, contains('dailyPromptFor(context.l10n)'));
    expect(timer, contains('focusHistoryExportFor(context.l10n)'));
    expect(timer, contains('localizedLivingLanternStateProvider(l10n)'));
    expect(providers, contains('localizedHavenPlanProvider'));
    expect(providers, contains('localizations: request.localizations'));
    expect(planner, contains('localizations: l10n'));
  });

  test('B6C3 keeps private values opaque and removes provider diagnostics', () {
    const privateTask = 'Private acquisition plan';
    final l10n = lookupAppLocalizations(const Locale('en'));
    const service = HavenPlanService();
    final plan = service.createPlan(
      queue: const [HavenTaskCandidate(id: 'private', title: privateTask)],
      recentEvents: const [],
      energy: HavenEnergy.steady,
      availableMinutes: 30,
      localizations: l10n,
    );
    final catalog = _read('lib/l10n/app_en.arb');
    final auth = _read('lib/services/auth_service.dart');
    final store = _read('lib/services/iap_service.dart');
    final timer = _read('lib/services/timer_service.dart');

    expect(plan.taskTitle, privateTask);
    expect(plan.firstStep, contains(privateTask));
    expect(catalog, isNot(contains(privateTask)));
    expect(auth, isNot(contains('error.message ?? error.code')));
    expect(auth, isNot(contains(r'${error.runtimeType}')));
    expect(store, isNot(contains(r'${error.message}')));
    expect(timer, isNot(contains('extension SessionTypeDetails')));
  });

  test(
    'B6C3 completes English Flutter extraction without activating locales',
    () {
      final inventory = _normalize(
        _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
      );
      final policy = _normalize(
        _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
      );
      final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
      final readme = _normalize(_read('README.md'));
      final locales = _read('lib/l10n/focus_haven_locales.dart');

      expect(inventory, contains('B6C3 — Remaining service results'));
      expect(
        inventory,
        contains('Phase 215G-B English Flutter extraction is complete'),
      );
      expect(policy, contains('Phase 215G-B6C3'));
      expect(policy, contains('the English Flutter extraction is complete'));
      expect(roadmap, contains('English Flutter extraction shipped'));
      expect(
        roadmap,
        contains('Phase 215G-B English Flutter extraction is complete'),
      );
      expect(readme, contains('Phase 215G-B6C3'));
      expect(
        locales,
        contains(
          "static const productionLocales = <Locale>[Locale('en'), Locale('es')]",
        ),
      );
      expect(
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .length,
        2,
      );
    },
  );
}

Set<String> _placeholderKeys(Map<String, dynamic> catalog, String key) {
  final metadata = catalog['@$key'] as Map<String, dynamic>;
  final placeholders = metadata['placeholders'] as Map<String, dynamic>;
  return placeholders.keys.toSet();
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
