import 'dart:math';

import '../models/haven_planner_proposal.dart';

typedef HavenPlannerClock = DateTime Function();
typedef HavenPlannerIdGenerator = String Function();

/// Creates an explainable planning draft without persistence or remote calls.
class HavenPlannerService {
  HavenPlannerService({
    HavenPlannerClock? clock,
    HavenPlannerIdGenerator? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _secureId;

  static const maxGoalLength = 240;
  static const maxQueueTitleLength = 100;
  static const _allowedFocusMinutes = <int>[10, 15, 25, 45, 60];

  final HavenPlannerClock _clock;
  final HavenPlannerIdGenerator _idGenerator;

  HavenPlannerProposal createProposal({
    required String goal,
    required int availableMinutes,
    required int preferredFocusMinutes,
  }) {
    final normalizedGoal = goal.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedGoal.isEmpty) {
      throw ArgumentError.value(goal, 'goal', 'A goal is required.');
    }
    if (normalizedGoal.length > maxGoalLength) {
      throw ArgumentError.value(
        goal,
        'goal',
        'A goal must be 240 characters or fewer.',
      );
    }

    final boundedAvailable = availableMinutes.clamp(10, 180).toInt();
    final focusMinutes = _closestFocusMinutes(
      preferredFocusMinutes,
      boundedAvailable,
    );
    final breakMinutes = focusMinutes >= 45
        ? 10
        : focusMinutes >= 25
        ? 5
        : 2;
    final proposalId = _idGenerator();
    final shortGoal = _shortGoal(normalizedGoal);

    return HavenPlannerProposal(
      schemaVersion: 1,
      id: proposalId,
      createdAtUtc: _clock().toUtc(),
      input: HavenPlannerInput(
        goal: normalizedGoal,
        availableMinutes: boundedAvailable,
        preferredFocusMinutes: focusMinutes,
      ),
      assumptions: List.unmodifiable(<String>[
        'You want a small starting sequence, not a complete project plan.',
        'The goal can be advanced through visible steps you can revise.',
        'A $focusMinutes-minute focus block fits within the $boundedAvailable-minute window you entered.',
      ]),
      uncertainty: HavenPlannerUncertainty.medium,
      uncertaintyExplanation:
          'Haven has only the goal and time you entered. It does not know your deadlines, dependencies, calendar, or preferred order.',
      affectedLocalData: const <HavenPlannerLocalData>{
        HavenPlannerLocalData.temporaryGoalText,
        HavenPlannerLocalData.focusQueue,
      },
      items: List.unmodifiable(<HavenPlannerItem>[
        _queueItem(
          '$proposalId-task-1',
          _boundedTitle('Define done for $shortGoal'),
          'Clarify one observable result before doing the work.',
        ),
        _queueItem(
          '$proposalId-task-2',
          _boundedTitle('Take the first visible step for $shortGoal'),
          'Choose an action small enough to begin without another planning pass.',
        ),
        _queueItem(
          '$proposalId-task-3',
          _boundedTitle(
            'Review progress and choose the next step for $shortGoal',
          ),
          'Pause after the first attempt and decide what actually belongs next.',
        ),
        HavenPlannerItem(
          id: '$proposalId-session',
          kind: HavenPlannerItemKind.sessionSuggestion,
          title:
              '$focusMinutes minutes of focus, then $breakMinutes minutes away',
          explanation:
              'This is an informational session-size suggestion. Accepting it does not start or reconfigure the timer.',
          affectedLocalData: const <HavenPlannerLocalData>{},
          canEdit: false,
          willMutateWhenAccepted: false,
        ),
        HavenPlannerItem(
          id: '$proposalId-free-time',
          kind: HavenPlannerItemKind.freeTimeSuggestion,
          title: 'Look for one uninterrupted $focusMinutes-minute opening',
          explanation:
              'This is informational only. Haven did not read or write a calendar and will not reserve time.',
          affectedLocalData: const <HavenPlannerLocalData>{},
          canEdit: false,
          willMutateWhenAccepted: false,
        ),
      ]),
      isLocalOnly: true,
    );
  }

  static HavenPlannerItem _queueItem(
    String id,
    String title,
    String explanation,
  ) => HavenPlannerItem(
    id: id,
    kind: HavenPlannerItemKind.queueTask,
    title: title,
    explanation: explanation,
    affectedLocalData: const <HavenPlannerLocalData>{
      HavenPlannerLocalData.focusQueue,
    },
    canEdit: true,
    willMutateWhenAccepted: true,
  );

  static int _closestFocusMinutes(int requested, int available) {
    final fitting = _allowedFocusMinutes
        .where((minutes) => minutes <= available)
        .toList(growable: false);
    final candidates = fitting.isEmpty ? <int>[10] : fitting;
    return candidates.reduce(
      (best, candidate) =>
          (candidate - requested).abs() < (best - requested).abs()
          ? candidate
          : best,
    );
  }

  static String _shortGoal(String goal) =>
      goal.length <= 58 ? goal : '${goal.substring(0, 57).trimRight()}…';

  static String _boundedTitle(String title) =>
      title.length <= maxQueueTitleLength
      ? title
      : '${title.substring(0, maxQueueTitleLength - 1).trimRight()}…';

  static String _secureId() {
    final random = Random.secure();
    final entropy = List<int>.generate(12, (_) => random.nextInt(256));
    return entropy
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
