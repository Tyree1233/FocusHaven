import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B3A planning and queue messages have complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'focusQueueSheetTitle',
      'focusQueueSheetDescription',
      'focusQueueCompletedToday',
      'focusQueueAddHint',
      'focusQueueAddTooltip',
      'focusQueueEmpty',
      'focusQueueEditTooltip',
      'focusQueueRemoveTooltip',
      'focusQueueCompletedCount',
      'focusQueueAddError',
      'focusQueueCompleteReceipt',
      'focusQueueCompleteError',
      'focusQueueRemoveError',
      'focusQueueUpdateError',
      'focusQueueChangedError',
      'focusQueueSelectError',
      'focusQueueEditTitle',
      'focusQueueEditSave',
      'focusQueueTaskHint',
      'completedTasksTitle',
      'completedTasksDescription',
      'completedTaskLabel',
      'completedTaskOnDate',
      'completedTaskReturnTooltip',
      'completedTaskRestoreError',
      'havenPlanTitle',
      'havenPlanCloseTooltip',
      'havenPlanDescription',
      'havenPlanEnergyQuestion',
      'havenPlanEnergyLow',
      'havenPlanEnergySteady',
      'havenPlanEnergyStrong',
      'havenPlanTimeQuestion',
      'havenPlanLabelUpper',
      'havenPlanFocusMinutes',
      'havenPlanBreakWhenReady',
      'havenPlanBreakMinutes',
      'havenPlanPrivacy',
      'havenPlanStartFocus',
      'havenPlanNotNow',
      'havenPlanEntry',
      'havenPlanStarted',
      'havenPlannerTitle',
      'havenPlannerLocalOnly',
      'havenPlannerDescription',
      'havenPlannerGoalLabel',
      'havenPlannerGoalHint',
      'havenPlannerTimeAvailable',
      'havenPlannerPreferredFocus',
      'havenPlannerCreateDraft',
      'havenPlannerDraftSemantics',
      'havenPlannerReviewEach',
      'havenPlannerApplying',
      'havenPlannerApplyReviewed',
      'havenPlannerStartOver',
      'havenPlannerEnterGoal',
      'havenPlannerQueueItemLengthError',
      'havenPlannerNothingChanged',
      'havenPlannerConfirmTitle',
      'havenPlannerConfirmMessage',
      'havenPlannerKeepReviewing',
      'havenPlannerAddToQueue',
      'havenPlannerAddSuccess',
      'havenPlannerAddPartial',
      'havenPlannerInputs',
      'havenPlannerGoalValue',
      'havenPlannerAvailableMinutes',
      'havenPlannerPreferredMinutes',
      'havenPlannerAssumptions',
      'havenPlannerUncertainty',
      'havenPlannerUncertaintyLow',
      'havenPlannerUncertaintyMedium',
      'havenPlannerUncertaintyHigh',
      'havenPlannerAffectedData',
      'havenPlannerReviewedQueueItem',
      'havenPlannerAccepted',
      'havenPlannerAccept',
      'havenPlannerEditing',
      'havenPlannerEdit',
      'havenPlannerRejected',
      'havenPlannerReject',
      'havenPlannerKindQueueTask',
      'havenPlannerKindSession',
      'havenPlannerKindFreeTime',
      'havenLoopTaskChanged',
      'havenLoopQueueUpdateError',
      'havenLoopNextStepUpper',
      'havenLoopDecisionDescription',
      'havenLoopMarkComplete',
      'havenLoopKeepLater',
      'havenLoopRecoveryUnlinked',
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
      'focusQueueCompletedToday',
      'havenPlanFocusMinutes',
      'havenPlanBreakMinutes',
      'havenPlannerDraftSemantics',
      'havenPlannerConfirmMessage',
      'havenPlannerAddSuccess',
      'havenPlannerAvailableMinutes',
      'havenPlannerPreferredMinutes',
    ]) {
      expect(catalog[key], contains('plural'), reason: 'plural: $key');
    }
  });

  test('B3A production presentation uses generated localization access', () {
    final sources = <String, List<String>>{
      'lib/widgets/focus_queue_sheet.dart': <String>[
        'focusQueueSheetTitle',
        'focusQueueCompletedToday',
        'focusQueueAddError',
        'focusQueueCompleteReceipt',
        'focusQueueCompletedCount',
      ],
      'lib/widgets/completed_tasks_sheet.dart': <String>[
        'completedTasksTitle',
        'completedTasksDescription',
        'completedTaskLabel',
        'completedTaskOnDate',
        'completedTaskReturnTooltip',
        'completedTaskRestoreError',
      ],
      'lib/widgets/haven_plan_sheet.dart': <String>[
        'havenPlanTitle',
        'havenPlanEnergyQuestion',
        'havenPlanFocusMinutes',
        'havenPlanPrivacy',
        'havenPlanStartFocus',
      ],
      'lib/widgets/haven_planner_sheet.dart': <String>[
        'havenPlannerTitle',
        'havenPlannerGoalLabel',
        'havenPlannerDraftSemantics',
        'havenPlannerConfirmMessage',
        'havenPlannerAddSuccess',
        'havenPlannerAffectedData',
        'havenPlannerKindQueueTask',
      ],
      'lib/widgets/haven_loop_completion_card.dart': <String>[
        'havenLoopTaskChanged',
        'havenLoopNextStepUpper',
        'havenLoopDecisionDescription',
        'havenLoopMarkComplete',
      ],
      'lib/screens/timer_screen.dart': <String>[
        'havenLoopRecoveryUnlinked',
        'havenPlanStarted',
        'focusQueueEditTitle',
        'havenPlannerTitle',
        'havenPlanEntry',
      ],
    };

    for (final entry in sources.entries) {
      final source = _read(entry.key);
      expect(source, contains('l10n'), reason: entry.key);
      for (final getter in entry.value) {
        expect(source, contains('.$getter'), reason: '${entry.key}: $getter');
      }
    }

    final combined = sources.keys.map(_read).join('\n');
    for (final stale in <String>[
      "'Focus queue'",
      "'Completed tasks'",
      "'Plan a gentle start'",
      "'Plan a goal'",
      "'Create local draft'",
      "'ONE CALM NEXT STEP'",
      "'Mark task complete'",
      "'Plan my next session'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: 'stale literal: $stale');
    }
  });

  test('B3A preserves private text and later localization owners', () {
    final planner = _read('lib/widgets/haven_planner_sheet.dart');
    final planService = _read('lib/services/haven_plan_service.dart');
    final plannerService = _read('lib/services/haven_planner_service.dart');
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));

    expect(planner, contains('proposal.input.goal'));
    expect(planner, contains('titles.join'));
    expect(planner, contains('Text(item.title)'));
    expect(planner, contains('Text(item.explanation)'));
    expect(planService, contains("selectedTask?.title"));
    expect(
      plannerService,
      contains('havenPlannerServiceDefineDoneTitle(shortGoal)'),
    );
    expect(plannerService, isNot(contains("'Define done for \$shortGoal'")));

    for (final required in <String>[
      'B3A — Queue and planning foundation',
      'User-authored task titles and goals remain opaque placeholders',
      'service-originated planning text remain B6-owned',
      'B3C — Optional system connections',
      'English behavior and stored planning data are unchanged',
    ]) {
      expect(inventory, contains(required));
    }
    expect(policy, contains('Phase 215G-B4'));
    expect(policy, contains('B6 remains required'));
    expect(roadmap, contains('B1–B6C2 extraction shipped'));
    expect(roadmap, contains('remaining B6 extraction work is B6C3'));
    expect(readme, contains('Phase 215G-B3A'));
    expect(readme, contains('service-originated planning copy remain B6'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
