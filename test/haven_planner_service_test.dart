import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_planner_proposal.dart';
import 'package:focushaven/services/haven_planner_service.dart';

void main() {
  test('creates one transparent local-only planning proposal', () {
    final createdAt = DateTime.utc(2026, 8, 30, 22, 15);
    final service = HavenPlannerService(
      clock: () => createdAt,
      idGenerator: () => 'planner-one',
    );

    final proposal = service.createProposal(
      goal: '  Prepare   the FocusHaven launch  ',
      availableMinutes: 60,
      preferredFocusMinutes: 25,
    );

    expect(proposal.schemaVersion, 1);
    expect(proposal.id, 'planner-one');
    expect(proposal.createdAtUtc, createdAt);
    expect(proposal.isLocalOnly, isTrue);
    expect(proposal.input.goal, 'Prepare the FocusHaven launch');
    expect(proposal.input.availableMinutes, 60);
    expect(proposal.input.preferredFocusMinutes, 25);
    expect(proposal.assumptions, hasLength(3));
    expect(proposal.assumptions, <String>[
      'You want a small starting sequence, not a complete project plan.',
      'The goal can be advanced through visible steps you can revise.',
      'A 25-minute focus block fits within the 60-minute window you entered.',
    ]);
    expect(proposal.uncertainty, HavenPlannerUncertainty.medium);
    expect(proposal.uncertaintyExplanation, contains('deadlines'));
    expect(
      proposal.affectedLocalData,
      containsAll(<HavenPlannerLocalData>{
        HavenPlannerLocalData.temporaryGoalText,
        HavenPlannerLocalData.focusQueue,
      }),
    );

    final queueItems = proposal.items
        .where((item) => item.kind == HavenPlannerItemKind.queueTask)
        .toList();
    expect(queueItems, hasLength(3));
    expect(queueItems.map((item) => item.title), <String>[
      'Define done for Prepare the FocusHaven launch',
      'Take the first visible step for Prepare the FocusHaven launch',
      'Review progress and choose the next step for Prepare the FocusHaven launch',
    ]);
    expect(queueItems.every((item) => item.canEdit), isTrue);
    expect(queueItems.every((item) => item.willMutateWhenAccepted), isTrue);
    expect(
      proposal.items
          .singleWhere(
            (item) => item.kind == HavenPlannerItemKind.sessionSuggestion,
          )
          .explanation,
      contains('does not start or reconfigure the timer'),
    );
    expect(
      proposal.items
          .singleWhere(
            (item) => item.kind == HavenPlannerItemKind.freeTimeSuggestion,
          )
          .explanation,
      contains('did not read or write a calendar'),
    );
  });

  test('bounds time inputs and keeps generated queue titles bounded', () {
    final service = HavenPlannerService(idGenerator: () => 'bounded');
    final proposal = service.createProposal(
      goal: List.filled(200, 'a').join(),
      availableMinutes: 500,
      preferredFocusMinutes: 58,
    );

    expect(proposal.input.availableMinutes, 180);
    expect(proposal.input.preferredFocusMinutes, 60);
    expect(
      proposal.items
          .where((item) => item.kind == HavenPlannerItemKind.queueTask)
          .every(
            (item) =>
                item.title.isNotEmpty &&
                item.title.length <= HavenPlannerService.maxQueueTitleLength,
          ),
      isTrue,
    );
  });

  test('rejects missing and oversized goals without creating a draft', () {
    final service = HavenPlannerService();

    expect(
      () => service.createProposal(
        goal: '   ',
        availableMinutes: 60,
        preferredFocusMinutes: 25,
      ),
      throwsArgumentError,
    );
    expect(
      () => service.createProposal(
        goal: List.filled(HavenPlannerService.maxGoalLength + 1, 'x').join(),
        availableMinutes: 60,
        preferredFocusMinutes: 25,
      ),
      throwsArgumentError,
    );
  });
}
