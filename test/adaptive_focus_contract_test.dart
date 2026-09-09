import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 216A model is text-free, ephemeral, and advisory', () {
    final model = read('lib/models/adaptive_focus_suggestion.dart');

    for (final boundary in <String>[
      'AdaptiveFocusDirection',
      'AdaptiveFocusBreakDirection',
      'AdaptiveFocusBasis',
      'AdaptiveFocusEvidenceStrength',
      'FocusForecastWindow?',
      'preservesExplicitChoice',
    ]) {
      expect(model, contains(boundary), reason: boundary);
    }
    for (final forbidden in <String>[
      'String ',
      'toJson',
      'fromJson',
      'SharedPreferences',
      'Firebase',
      'HttpClient',
      'ChangeNotifier',
    ]) {
      expect(model, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Phase 216A reads bounded signals without copying presentation', () {
    final service = read('lib/services/adaptive_focus_service.dart');

    for (final required in <String>[
      'preserveCurrentChoice',
      'recoverySignals >= 2',
      'FocusSessionFit.tooMuch',
      'HavenRhythmKind.roomToGrow',
      '_minimumRhythmSignals = 3',
      '_minimumForecastSignals = 6',
      '_oneStepUpToward',
    ]) {
      expect(service, contains(required), reason: required);
    }
    for (final forbidden in <String>[
      '.headline',
      '.detail',
      '.evidence',
      'AppLocalizations',
      'TimerService',
      'startFocus',
      'setDuration',
      'notifyListeners',
      'SharedPreferences',
      'Firebase',
      'HttpClient',
    ]) {
      expect(service, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Phase 216A provider requires explicit choices and grants no owner', () {
    final providers = read('lib/providers/app_providers.dart');

    expect(providers, contains('AdaptiveFocusRequest'));
    expect(providers, contains('adaptiveFocusServiceProvider'));
    expect(providers, contains('adaptiveFocusSuggestionProvider'));
    expect(providers, contains('currentFocusMinutes'));
    expect(providers, contains('currentBreakMinutes'));
    expect(providers, contains('preserveCurrentChoice'));
    expect(providers, contains('timerFocusEventsProvider'));
    expect(providers, contains('havenRhythmInsightProvider'));
    expect(providers, contains('focusForecastProvider'));
  });

  test('Phase 216A through 216D keep the production boundary honest', () {
    final roadmap = read('docs/PRODUCT_ROADMAP.md');
    final architecture = read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md');
    final readme = read('README.md');

    expect(roadmap, contains('| Adaptive Focus Engine | Shipped |'));
    expect(
      roadmap,
      contains(
        'Phase 216A local advisory, Phase 216B isolated review, Phase 216C',
      ),
    );
    expect(roadmap, contains('reviewed production card'));
    expect(architecture, contains('## Phase 216A text-free adaptive preview'));
    expect(architecture, contains('## Phase 216B isolated adaptive review'));
    expect(
      architecture,
      contains('## Phase 216C owner-revalidated adaptive delegation'),
    );
    expect(architecture, contains('no timer or scheduling authority'));
    expect(readme, contains('Adaptive Focus Engine foundation'));
    expect(readme, contains('reviewed production card'));
    expect(readme, contains('Adaptive Focus review foundation'));
    expect(readme, contains('Adaptive Focus owner-delegation foundation'));
    expect(readme, contains('Adaptive Focus production review gate'));
  });

  test('Phase 216B review settlement is text-free and fail-closed', () {
    final model = read('lib/models/adaptive_focus_review.dart');
    final service = read('lib/services/adaptive_focus_review_service.dart');
    final combined = '$model\n$service';

    for (final required in <String>[
      'AdaptiveFocusReviewChoice',
      'AdaptiveFocusReviewDecision',
      'AdaptiveFocusReviewTicket',
      'beginReview',
      'latestSuggestion != reviewed',
      'currentFocusMinutes != reviewed.currentFocusMinutes',
      '!reviewed.changesAnything',
      '_activeGeneration = null',
      'authorizesDelegation',
    ]) {
      expect(combined, contains(required), reason: required);
    }
    for (final forbidden in <String>[
      'String ',
      'TimerService',
      'setCustomDuration',
      'SharedPreferences',
      'AppLocalizations',
      'Firebase',
      'HttpClient',
      'toJson',
      'fromJson',
      'ChangeNotifier',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Phase 216B card accepts complete reviewed copy but owns no state', () {
    final card = read('lib/widgets/adaptive_focus_review_card.dart');

    for (final required in <String>[
      'AdaptiveFocusReviewCopy',
      'summarySemantics',
      'onKeepCurrent',
      'onAccept',
      "ValueKey<String>('adaptive-focus-keep-current')",
      "ValueKey<String>('adaptive-focus-accept')",
      'widget.suggestion.changesAnything',
      'if (_settled) return',
      'explicitChildNodes: true',
    ]) {
      expect(card, contains(required), reason: required);
    }
    for (final forbidden in <String>[
      'AppLocalizations',
      'context.l10n',
      'TimerService',
      'ProviderScope',
      'SharedPreferences',
      'setCustomDuration',
      'Firebase',
      'HttpClient',
    ]) {
      expect(card, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Phase 216B card has exactly one production adapter', () {
    final consumers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => file.path != 'lib/widgets/adaptive_focus_review_card.dart',
        )
        .where(
          (file) => file.readAsStringSync().contains('AdaptiveFocusReviewCard'),
        )
        .map((file) => file.path.replaceFirst('${Directory.current.path}/', ''))
        .toList(growable: false);

    expect(consumers, ['lib/widgets/adaptive_focus_production_review.dart']);
  });

  test('Phase 216C delegation result stays text-free and ephemeral', () {
    final model = read('lib/models/adaptive_focus_delegation.dart');

    for (final required in <String>[
      'AdaptiveFocusDelegationOutcome',
      'applied',
      'keptCurrent',
      'rejected',
      'wasApplied',
      'wasRejected',
    ]) {
      expect(model, contains(required), reason: required);
    }
    for (final forbidden in <String>[
      'String ',
      'toJson',
      'fromJson',
      'SharedPreferences',
      'AppLocalizations',
      'Firebase',
      'HttpClient',
      'ChangeNotifier',
    ]) {
      expect(model, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Phase 216C coordinator consumes and revalidates one owner ticket', () {
    final service = read('lib/services/adaptive_focus_delegation_service.dart');

    for (final required in <String>[
      'AdaptiveFocusOwnerReviewTicket',
      'AdaptiveFocusReviewTicket',
      'canApplyReviewedAdaptiveDurations',
      '_hasWholeMinuteDefaults',
      'suggestion.currentFocusMinutes != _currentFocusMinutes',
      '_activeGeneration = null',
      '_reviewService.settle',
      'decision.keepsCurrent',
      'applyReviewedAdaptiveDurations',
      'expectedFocusSeconds:',
      'expectedBreakSeconds:',
    ]) {
      expect(service, contains(required), reason: required);
    }
    for (final forbidden in <String>[
      'AppLocalizations',
      'SharedPreferences',
      'Firebase',
      'HttpClient',
      '.start(',
      '.pause(',
      '.reset(',
      'selectSession(',
      'setCustomDuration(',
      'FocusQueue',
      'HavenAction',
    ]) {
      expect(service, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'Phase 216C timer owner applies both defaults atomically and stopped',
    () {
      final timer = read('lib/services/timer_service.dart');
      final methodStart = timer.indexOf(
        'bool applyReviewedAdaptiveDurations({',
      );
      final methodEnd = timer.indexOf('\n  void setFocusTask', methodStart);
      expect(methodStart, greaterThanOrEqualTo(0));
      expect(methodEnd, greaterThan(methodStart));
      final method = timer.substring(methodStart, methodEnd);

      for (final required in <String>[
        '!canApplyReviewedAdaptiveDurations',
        'expectedFocusSeconds != _focusSeconds',
        'expectedBreakSeconds != _shortBreakSeconds',
        'expectedFocusSeconds % 60 != 0',
        'focusSeconds < 60',
        'focusSeconds % 60 != 0',
        'breakSeconds < 60',
        'breakSeconds % 60 != 0',
        '_focusSeconds = focusSeconds',
        '_shortBreakSeconds = breakSeconds',
        '_secondsRemaining = focusSeconds',
        '_totalSessionSeconds = focusSeconds',
        'notifyListeners();',
        '_saveToPrefs();',
      ]) {
        expect(method, contains(required), reason: required);
      }
      for (final forbidden in <String>[
        'start();',
        'pause();',
        'reset();',
        'selectSession(',
        '_sessionType =',
        '_isRunning = true',
        '_isComplete = true',
        'FocusEventOutcome',
      ]) {
        expect(method, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('Phase 216C delegation is exposed only through the bounded adapter', () {
    final providers = read('lib/providers/app_providers.dart');
    final adapter = read('lib/widgets/adaptive_focus_production_review.dart');
    final timerScreen = read('lib/screens/timer_screen.dart');

    expect(providers, contains('adaptiveFocusDelegationServiceProvider'));
    expect(adapter, contains('AdaptiveFocusOwnerReviewTicket'));
    expect(adapter, contains('_latestSuggestion()'));
    expect(adapter, contains('AdaptiveFocusDelegationOutcome.rejected'));
    expect(timerScreen, contains('adaptiveFocusOwner.canReview'));
    expect(timerScreen, contains('adaptiveFocusSuggestion.changesAnything'));
  });

  test('Phase 216D activates only fully reviewed production copy', () {
    final roadmap = read('docs/PRODUCT_ROADMAP.md');
    final architecture = read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md');
    final policy = read('docs/ADAPTIVE_FOCUS_PRODUCTION_REVIEW.md');

    expect(roadmap, contains('Seventeen reviewed messages'));
    expect(architecture, contains('## Phase 216D reviewed production adapter'));
    expect(architecture, contains('reviewed production adapter'));
    expect(
      policy,
      contains('opens production placement only with localization'),
    );
    expect(policy, contains('fifteen independently reviewed languages'));
    expect(policy, contains('immediately after Focus Forecast'));
  });
}
