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

  test('Phase 216A and 216B keep the production boundary honest', () {
    final roadmap = read('docs/PRODUCT_ROADMAP.md');
    final architecture = read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md');
    final readme = read('README.md');

    expect(roadmap, contains('| Adaptive Focus Engine | Foundation shipped |'));
    expect(
      roadmap,
      contains('Phase 216A local advisory foundation and Phase 216B'),
    );
    expect(roadmap, contains('is not consumed by a production screen'));
    expect(architecture, contains('## Phase 216A text-free adaptive preview'));
    expect(architecture, contains('## Phase 216B isolated adaptive review'));
    expect(architecture, contains('no timer or scheduling authority'));
    expect(readme, contains('Adaptive Focus Engine foundation'));
    expect(readme, contains('No production control consumes it yet'));
    expect(readme, contains('Adaptive Focus review foundation'));
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

  test('Phase 216B foundation has no production consumer or new catalog', () {
    const foundationFiles = <String>{
      'lib/models/adaptive_focus_review.dart',
      'lib/services/adaptive_focus_review_service.dart',
      'lib/widgets/adaptive_focus_review_card.dart',
    };
    final productionDart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !foundationFiles.contains(
            file.path.replaceFirst('${Directory.current.path}/', ''),
          ),
        );

    for (final file in productionDart) {
      expect(
        file.readAsStringSync(),
        isNot(contains('AdaptiveFocusReviewCard')),
        reason: file.path,
      );
    }

    final catalogs = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList(growable: false);
    expect(catalogs, hasLength(11));
    for (final catalog in catalogs) {
      expect(
        catalog.readAsStringSync(),
        isNot(contains('adaptiveFocusReview')),
        reason: catalog.path,
      );
    }
  });
}
