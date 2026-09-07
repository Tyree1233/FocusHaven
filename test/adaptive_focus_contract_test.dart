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

  test('Phase 216A is honest about its non-UI foundation boundary', () {
    final roadmap = read('docs/PRODUCT_ROADMAP.md');
    final architecture = read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md');
    final readme = read('README.md');

    expect(roadmap, contains('| Adaptive Focus Engine | Foundation shipped |'));
    expect(roadmap, contains('Phase 216A local advisory foundation'));
    expect(roadmap, contains('does not expose a production control'));
    expect(architecture, contains('## Phase 216A text-free adaptive preview'));
    expect(architecture, contains('no timer or scheduling authority'));
    expect(readme, contains('Adaptive Focus Engine foundation'));
    expect(readme, contains('No production control consumes it yet'));
  });
}
