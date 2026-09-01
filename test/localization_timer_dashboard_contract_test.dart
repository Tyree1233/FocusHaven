import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B2 timer-dashboard messages and metadata are complete', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'sessionFocus',
      'sessionShortBreak',
      'sessionLongBreak',
      'sessionStatusFocus',
      'sessionStatusShortBreak',
      'sessionStatusLongBreak',
      'sessionComplete',
      'sessionFocusEncouragement',
      'sessionShortBreakEncouragement',
      'sessionLongBreakEncouragement',
      'sessionFocusCompleteMessage',
      'sessionShortBreakCompleteMessage',
      'sessionLongBreakCompleteMessage',
      'timerDurationSecondsUpper',
      'timerDurationMinutesUpper',
      'timerDurationSecondsShortUpper',
      'focusSessionSeconds',
      'focusSessionMinutes',
      'focusSessionMinutesSeconds',
      'dateToday',
      'dateYesterday',
      'focusSummaryCopyError',
      'focusSummaryCopied',
      'focusIntentionTitle',
      'actionSave',
      'focusIntentionHint',
      'actionClear',
      'focusIntentionSet',
      'focusQueueLinked',
      'focusQueueOpen',
      'focusQueueCount',
      'resumeSessionTitle',
      'resumeSessionDescription',
      'resumeSessionStartFresh',
      'actionResume',
      'timerTakeBreak',
      'timerBeginFocus',
      'timerBeginShortBreak',
      'timerBeginLongBreak',
      'timerLinkedTaskRestoring',
      'timerTaskOutcomeRequired',
      'timerResetTooltip',
      'actionPauseTimer',
      'timerCustomDuration',
      'statMinutesCompact',
      'statToday',
      'statDayStreak',
      'statCompleted',
      'dashboardMilestones',
      'dailyGoalTitle',
      'actionChange',
      'dailyGoalProgress',
      'dailyGoalComplete',
      'dailyGoalRemaining',
      'dailyGoalDialogTitle',
      'dailyGoalSave',
      'dailyGoalMinutesHint',
      'dailyGoalRangeHelp',
      'dailyChallengeTitle',
      'dailyChallengeComplete',
      'dailyChallengeTarget',
      'recentFocusTitle',
      'actionViewAll',
      'recentFocusEmpty',
      'focusHistoryClear',
      'focusHistoryClearTitle',
      'focusHistoryClearMessage',
      'focusHistoryKeep',
      'focusHistoryClearConfirm',
      'focusHistoryCleared',
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
      'timerDurationSecondsUpper',
      'timerDurationMinutesUpper',
      'focusSessionSeconds',
      'focusSessionMinutes',
      'dailyGoalRemaining',
      'dailyChallengeTarget',
    ]) {
      expect(catalog[key], contains('plural'), reason: 'plural: $key');
    }
  });

  test('B2 dashboard presentation uses generated localization access', () {
    final source = _read('lib/screens/timer_screen.dart');
    for (final getter in <String>[
      'sessionFocus',
      'sessionShortBreak',
      'sessionLongBreak',
      'sessionComplete',
      'sessionFocusEncouragement',
      'sessionFocusCompleteMessage',
      'timerDurationSecondsUpper',
      'focusSessionMinutes',
      'dateToday',
      'focusSummaryCopyError',
      'focusIntentionTitle',
      'focusQueueOpen',
      'resumeSessionTitle',
      'timerBeginFocus',
      'timerResetTooltip',
      'timerCustomDuration',
      'statMinutesCompact',
      'dailyGoalTitle',
      'dailyGoalRemaining',
      'dailyChallengeTarget',
      'recentFocusTitle',
      'focusHistoryClearTitle',
      'focusHistoryCleared',
    ]) {
      expect(source, contains('.$getter'), reason: getter);
    }

    for (final stale in <String>[
      "'SESSION COMPLETE'",
      "'Set a focus intention'",
      "'Open focus queue'",
      "'Resume your saved session?'",
      "'Reset timer'",
      "'Custom duration'",
      "'Daily focus goal'",
      "'Daily challenge'",
      "'Recent focus'",
      "'Clear focus history'",
    ]) {
      expect(source, isNot(contains(stale)), reason: 'stale literal: $stale');
    }

    expect(source, contains('MaterialLocalizations.of(context)'));
    expect(source, contains('String _dashboardDateLabel'));
    expect(
      source,
      contains('dateLabel: (date) => _dateLabel(sheetContext, date)'),
    );
    expect(source, isNot(contains('session.sessionType.label')));
    expect(source, isNot(contains('session.completionMessage')));
  });

  test('B2 scope remains truthful and later owners stay explicit', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));

    for (final required in <String>[
      'B2 — Timer dashboard and session controls',
      'Planning and recovery cards outside the completed B3A, B3B, and B3C presentation boundaries retain their later audited owners',
      'Timer notification wording intentionally continues to come from `TimerService` until B6',
      'No locale was activated by B2',
      'B3A — Queue and planning foundation',
      'B3B — Reflection and restorative guidance',
      'B3C — Optional system connections',
      'B4 — Coaching and voice',
      'B5 — Account, purchases, and private records',
      'B6A — Notifications and bounded service receipts',
      'B6B1 — Generated Haven Planner guidance',
      'B6B2 — Restorative and optional-system guidance',
      'B6C1 — Haven action service results',
    ]) {
      expect(inventory, contains(required));
    }

    expect(policy, contains('Phase 215G-B4'));
    expect(policy, contains('B6 remains required'));
    expect(roadmap, contains('B1–B6C2 extraction shipped'));
    expect(roadmap, contains('remaining B6 extraction work is B6C3'));
    expect(readme, contains('Phases 215G-B1, B2, B3A, B3B, B3C, B4, and B5'));
    expect(readme, contains('remaining B6 work'));
  });
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
