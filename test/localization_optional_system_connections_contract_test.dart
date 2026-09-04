import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B3C optional-system-connection messages have complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'havenWindowHeadlineArrived',
      'havenWindowHeadlineHeld',
      'havenWindowHeadlineOff',
      'havenWindowShowDetails',
      'havenWindowHideDetails',
      'havenWindowSemantics',
      'havenWindowEyebrow',
      'havenWindowArrivedDetail',
      'havenWindowHeldDetail',
      'havenWindowDormantDetail',
      'havenWindowNoAvailabilityRead',
      'havenWindowPrivateBoundary',
      'havenWindowNoCalendarWriteBoundary',
      'havenWindowArrivedHoldBoundary',
      'havenWindowHeldNotificationBoundary',
      'havenWindowAvailableHoldBoundary',
      'havenWindowActionBeginFocus',
      'havenWindowActionLetPass',
      'havenWindowActionReleaseHold',
      'havenWindowActionReviewCalendarAccess',
      'havenWindowActionRecheckAccess',
      'havenWindowActionRefreshAvailability',
      'havenWindowActionHold',
      'havenWindowStatusArrived',
      'havenWindowStatusHeld',
      'havenWindowStatusOff',
      'havenWindowStatusUnavailable',
      'havenWindowStatusNotConnected',
      'havenWindowStatusAccessOff',
      'havenWindowStatusLearning',
      'havenWindowStatusPossibleOpening',
      'havenWindowStatusNoOpening',
      'havenWindowHeldFallback',
      'havenWindowHeldSameDay',
      'havenWindowHeldMultiDay',
      'havenWindowAccessReviewFailed',
      'havenWindowRefreshFailed',
      'havenWindowStaleHold',
      'havenWindowHoldFailed',
      'havenWindowReleaseFailed',
      'havenWindowBeginReleaseFailed',
      'havenWindowTimerChanged',
      'havenWindowFocusBegan',
      'focusShieldEyebrow',
      'focusShieldPhaseOff',
      'focusShieldPhaseUnavailable',
      'focusShieldPhasePermissionNeeded',
      'focusShieldPhaseSetupNeeded',
      'focusShieldPhaseReady',
      'focusShieldPhaseConfirming',
      'focusShieldPhaseProtected',
      'focusShieldPhasePaused',
      'focusShieldPhaseNeedsAttention',
      'focusShieldRunningOnlyBoundary',
      'focusShieldPrivateSelectionBoundary',
      'focusShieldActionEnable',
      'focusShieldActionDisable',
      'focusShieldActionReviewPermission',
      'focusShieldActionChooseDistractions',
      'focusShieldActionPauseProtection',
      'focusShieldActionResumeProtection',
      'focusShieldActionRetryProtection',
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

    for (final key in <String>[
      'havenWindowSemantics',
      'havenWindowEyebrow',
      'havenWindowHeldSameDay',
      'havenWindowHeldMultiDay',
      'focusShieldEyebrow',
    ]) {
      final metadata = catalog['@$key'] as Map<String, dynamic>;
      expect(metadata['placeholders'], isA<Map<String, dynamic>>());
    }
  });

  test('B3C production presentation uses generated localization access', () {
    final window = _read('lib/widgets/haven_window_card.dart');
    final shield = _read('lib/widgets/focus_shield_card.dart');
    final timer = _read('lib/screens/timer_screen.dart');

    for (final getter in <String>[
      'havenWindowHeadlineArrived',
      'havenWindowSemantics',
      'havenWindowDormantDetail',
      'havenWindowPrivateBoundary',
      'havenWindowActionReviewCalendarAccess',
      'havenWindowStatusPossibleOpening',
      'havenWindowHeldSameDay',
      'havenWindowHeldMultiDay',
    ]) {
      expect(window, contains(getter), reason: getter);
    }
    for (final getter in <String>[
      'focusShieldEyebrow',
      'focusShieldPhasePermissionNeeded',
      'focusShieldRunningOnlyBoundary',
      'focusShieldPrivateSelectionBoundary',
      'focusShieldActionReviewPermission',
      'focusShieldActionRetryProtection',
    ]) {
      expect(shield, contains(getter), reason: getter);
    }
    for (final getter in <String>[
      'havenWindowAccessReviewFailed',
      'havenWindowRefreshFailed',
      'havenWindowStaleHold',
      'havenWindowHoldFailed',
      'havenWindowReleaseFailed',
      'havenWindowBeginReleaseFailed',
      'havenWindowTimerChanged',
      'havenWindowFocusBegan',
    ]) {
      expect(timer, contains(getter), reason: getter);
    }

    final combined = '$window\n$shield\n$timer';
    for (final stale in <String>[
      "'Calendar assistance stays off'",
      "'Review calendar access'",
      "'FocusHaven never creates or changes calendar events.",
      "'FOCUS SHIELD · ",
      "'Protection is requested only during a running focus session.",
      "'Turn on Focus Shield'",
      "'Calendar access could not be reviewed right now.",
      "'Focus began by your choice.'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: 'stale literal: $stale');
    }
  });

  test('B3C keeps generated runtime values with their service owners', () {
    final window = _read('lib/widgets/haven_window_card.dart');
    final shield = _read('lib/widgets/focus_shield_card.dart');

    expect(window, contains('widget.suggestion.headline'));
    expect(window, contains('widget.suggestion.detail'));
    expect(window, contains('widget.suggestion.evidence'));
    expect(shield, contains('state.headline'));
    expect(shield, contains('state.detail'));

    for (final service in <String>[
      'lib/services/haven_window_service.dart',
      'lib/services/focus_shield_service.dart',
    ]) {
      final source = _read(service);
      expect(source, isNot(contains('context.l10n')), reason: service);
      expect(
        source,
        isNot(contains('focus_haven_localizations.dart')),
        reason: service,
      );
    }
  });

  test('B3C scope is truthful and planned locales remain inactive', () {
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
      'B3C — Optional system connections',
      'Haven Window suggestion headlines, details, and evidence and Focus Shield state headlines and details remain B6-owned',
      'changes no permission prompt, calendar access, calendar write behavior, reminder behavior, Focus Shield rule, platform bridge',
      'No locale was activated by B3C',
      'Phase 215G-B English Flutter extraction is complete',
    ]) {
      expect(inventory, contains(required));
    }
    expect(policy, contains('Phase 215G-B4'));
    expect(
      policy,
      contains('Phase 215G-B6C3 completes the English Flutter extraction'),
    );
    expect(roadmap, contains('English Flutter extraction shipped'));
    expect(
      roadmap,
      contains('Phase 215G-B English Flutter extraction is complete'),
    );
    expect(readme, contains('Phase 215G-B3C'));
    expect(
      readme,
      contains(
        'Haven Window suggestion text and Focus Shield state text remain opaque B6-owned service values',
      ),
    );
    expect(locales, contains("languageCode: 'es'"));
    expect(
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .length,
      greaterThanOrEqualTo(2),
    );
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
