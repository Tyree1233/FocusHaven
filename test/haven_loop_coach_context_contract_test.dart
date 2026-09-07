import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_loop_coach_context.dart';
import 'package:focushaven/services/coaching_service.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('Phase 215H keeps the Loop snapshot text-free and ephemeral', () {
    final model = read('lib/models/haven_loop_coach_context.dart');
    final service = read('lib/services/haven_loop_coach_context_service.dart');

    for (final boundary in <String>[
      'HavenLoopCoachMoment',
      'FocusCompletionIdentity?',
      'FocusSessionFit?',
      'HavenRhythmReflectionConnectionKind?',
      'FocusForecastReflectionConnectionKind?',
      'HavenJourneyCompletionConnectionKind?',
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
    ]) {
      expect(model, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(service, contains('matches.length != 1'));
    expect(
      service,
      contains('recentEvents.last.completionIdentity != completion'),
    );
    expect(service, contains('matchedEvent.sessionFit != sessionFit'));
    expect(service, isNot(contains('.title')));
    expect(service, isNot(contains('selectedItemId')));
    expect(service, isNot(contains('notifyListeners')));
  });

  test('Phase 215H cannot enter a remote coaching payload', () {
    const context = CoachingContext(
      focusTask: 'Opaque private task',
      havenLoopContext: HavenLoopCoachContext(
        moment: HavenLoopCoachMoment.taskDecision,
        hasLinkedTask: true,
      ),
    );

    expect(context.havenLoopContext, isNotNull);
    expect(context.toPromptData()['focusTask'], 'Opaque private task');
    expect(context.toPromptData(), isNot(contains('havenLoopContext')));
    expect(context.toPromptData(), isNot(contains('havenLoop')));
    expect(context.toPromptData(), isNot(contains('completion')));
    expect(context.toPromptData(), isNot(contains('sessionFit')));
  });

  test('Phase 215H wiring remains local, explicit, and action-free', () {
    final providers = read('lib/providers/app_providers.dart');
    final coach = read('lib/services/coaching_service.dart');
    final timer = read('lib/screens/timer_screen.dart');
    final sheet = read('lib/widgets/coaching_sheet.dart');
    final card = read('lib/widgets/haven_loop_coach_context_card.dart');

    expect(providers, contains('havenLoopCoachContextProvider'));
    expect(providers, contains('HavenLoopCoachContextService'));
    expect(coach, contains('context.havenLoopContext != null'));
    expect(coach, contains('_localResponder'));
    expect(timer, contains('coach.enhancedCoachingEnabled'));
    expect(timer, contains('ref.read(havenLoopCoachContextProvider)'));
    expect(sheet, contains('HavenLoopCoachContextCard'));
    expect(card, contains('havenRhythmPrivacy'));
    expect(card, contains('havenRhythmNoAutomaticChange'));
    expect(card, isNot(contains('onPressed:')));
    expect(card, isNot(contains('HavenAction')));
    expect(card, isNot(contains('taskTitle')));
  });

  test('Phase 215H is documented as complete without widening authority', () {
    final roadmap = read('docs/PRODUCT_ROADMAP.md');
    final architecture = read('docs/HAVEN_AI_ACTION_ARCHITECTURE.md');
    final readme = read('README.md');

    expect(roadmap, contains('Phase 215H text-free Local-Coach context'));
    expect(roadmap, contains('sends no Loop snapshot'));
    expect(
      architecture,
      contains('## Phase 215H text-free Local-Coach context'),
    );
    expect(architecture, contains('or create a Haven'));
    expect(architecture, contains('action proposal. Every state change'));
    expect(readme, contains('Unified Loop-to-Local-Coach'));
    expect(readme, contains('never persisted or serialized'));
  });
}
