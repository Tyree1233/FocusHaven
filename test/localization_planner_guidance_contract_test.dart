import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B6B1 generated Haven Planner guidance has complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'havenPlannerServiceGoalRequired',
      'havenPlannerServiceGoalTooLong',
      'havenPlannerServiceAssumptionSmallSequence',
      'havenPlannerServiceAssumptionVisibleSteps',
      'havenPlannerServiceAssumptionFocusFits',
      'havenPlannerServiceUncertainty',
      'havenPlannerServiceDefineDoneTitle',
      'havenPlannerServiceDefineDoneExplanation',
      'havenPlannerServiceFirstStepTitle',
      'havenPlannerServiceFirstStepExplanation',
      'havenPlannerServiceReviewProgressTitle',
      'havenPlannerServiceReviewProgressExplanation',
      'havenPlannerServiceSessionTitle',
      'havenPlannerServiceSessionExplanation',
      'havenPlannerServiceFreeTimeTitle',
      'havenPlannerServiceFreeTimeExplanation',
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

    expect(
      _placeholderKeys(catalog, 'havenPlannerServiceAssumptionFocusFits'),
      {'focusMinutes', 'availableMinutes'},
    );
    expect(_placeholderKeys(catalog, 'havenPlannerServiceDefineDoneTitle'), {
      'goal',
    });
    expect(_placeholderKeys(catalog, 'havenPlannerServiceFirstStepTitle'), {
      'goal',
    });
    expect(
      _placeholderKeys(catalog, 'havenPlannerServiceReviewProgressTitle'),
      {'goal'},
    );
    expect(_placeholderKeys(catalog, 'havenPlannerServiceSessionTitle'), {
      'focusMinutes',
      'breakMinutes',
    });
    expect(_placeholderKeys(catalog, 'havenPlannerServiceFreeTimeTitle'), {
      'focusMinutes',
    });
  });

  test('B6B1 planner service uses generated catalog values', () {
    final source = _read('lib/services/haven_planner_service.dart');

    for (final getter in <String>[
      'havenPlannerServiceGoalRequired',
      'havenPlannerServiceGoalTooLong',
      'havenPlannerServiceAssumptionSmallSequence',
      'havenPlannerServiceAssumptionFocusFits',
      'havenPlannerServiceUncertainty',
      'havenPlannerServiceDefineDoneTitle',
      'havenPlannerServiceFirstStepTitle',
      'havenPlannerServiceReviewProgressTitle',
      'havenPlannerServiceSessionTitle',
      'havenPlannerServiceFreeTimeTitle',
    ]) {
      expect(source, contains(getter), reason: getter);
    }

    for (final stale in <String>[
      "'A goal is required.'",
      "'You want a small starting sequence, not a complete project plan.'",
      "'Define done for \$shortGoal'",
      "'Clarify one observable result before doing the work.'",
      "'This is an informational session-size suggestion. Accepting it does not start or reconfigure the timer.'",
      "'This is informational only. Haven did not read or write a calendar and will not reserve time.'",
    ]) {
      expect(source, isNot(contains(stale)), reason: stale);
    }
  });

  test('B6B1 preserves private goal and proposal ownership boundaries', () {
    final source = _read('lib/services/haven_planner_service.dart');
    final model = _read('lib/models/haven_planner_proposal.dart');
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );

    expect(source, contains('final normalizedGoal = goal.trim()'));
    expect(source, contains('final shortGoal = _shortGoal(normalizedGoal)'));
    expect(source, contains('_boundedTitle('));
    expect(model, contains('final String goal;'));
    expect(model, contains('final List<String> assumptions;'));
    expect(
      inventory,
      contains('User-authored goal text remains an opaque placeholder'),
    );
    expect(
      inventory,
      contains('Proposal schema, IDs, time bounds, title bounds'),
    );
  });

  test('B6B1 remains partial and planned locales stay inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    expect(inventory, contains('B6B1 — Generated Haven Planner guidance'));
    expect(
      inventory,
      contains('B6B2 — Restorative and optional-system guidance'),
    );
    expect(inventory, contains('B6C1 — Haven action service results'));
    expect(policy, contains('Phase 215G-B6B1'));
    expect(
      policy,
      contains('Phase 215G-B6C3 completes the English Flutter extraction'),
    );
    expect(roadmap, contains('English Flutter extraction shipped'));
    expect(readme, contains('Phase 215G-B6B1'));
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
      2,
    );
  });
}

Set<String> _placeholderKeys(Map<String, dynamic> catalog, String key) {
  final metadata = catalog['@$key'] as Map<String, dynamic>;
  final placeholders = metadata['placeholders'] as Map<String, dynamic>;
  return placeholders.keys.toSet();
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
