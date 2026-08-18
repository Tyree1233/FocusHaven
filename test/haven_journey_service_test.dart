import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/haven_journey_state.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/haven_journey_service.dart';

void main() {
  const service = HavenJourneyService();

  test('starts with one whole lantern instead of an empty score', () {
    final journey = service.createState(completedFocusSessions: 0);

    expect(journey.place, HavenJourneyPlace.lantern);
    expect(journey.hasBegun, isFalse);
    expect(journey.supportingSessionCount, 0);
    expect(journey.headline, contains('whole light'));
    expect(journey.detail, contains('nothing to prove'));
  });

  test('one completed session is enough to begin the campsite', () {
    final journey = service.createState(completedFocusSessions: 1);

    expect(journey.place, HavenJourneyPlace.campsite);
    expect(journey.hasBegun, isTrue);
    expect(journey.supportingSessionCount, 1);
    expect(journey.detail, contains('enough to begin'));
    expect(journey.detail, contains('wait with you'));
  });

  test('exact boundaries establish each compassionate place', () {
    final boundaries = <int, HavenJourneyPlace>{
      0: HavenJourneyPlace.lantern,
      1: HavenJourneyPlace.campsite,
      4: HavenJourneyPlace.cabin,
      10: HavenJourneyPlace.garden,
      25: HavenJourneyPlace.sanctuary,
    };

    for (final entry in boundaries.entries) {
      final journey = service.createState(completedFocusSessions: entry.key);

      expect(
        journey.place,
        entry.value,
        reason: '${entry.key} completed sessions should match the boundary.',
      );
      expect(journey.supportingSessionCount, entry.key);
    }
  });

  test('places remain steady between boundaries without a progress bar', () {
    expect(
      service.createState(completedFocusSessions: 3).place,
      HavenJourneyPlace.campsite,
    );
    expect(
      service.createState(completedFocusSessions: 9).place,
      HavenJourneyPlace.cabin,
    );
    expect(
      service.createState(completedFocusSessions: 24).place,
      HavenJourneyPlace.garden,
    );
  });

  test('increasing completions can never move the Haven backward', () {
    var previousPlace = HavenJourneyPlace.lantern;

    for (
      var completedSessions = 0;
      completedSessions <= 100;
      completedSessions++
    ) {
      final journey = service.createState(
        completedFocusSessions: completedSessions,
      );

      expect(journey.place.index, greaterThanOrEqualTo(previousPlace.index));
      previousPlace = journey.place;
    }
  });

  test('a mature sanctuary keeps every cumulative completion', () {
    final journey = service.createState(completedFocusSessions: 500);

    expect(journey.place, HavenJourneyPlace.sanctuary);
    expect(journey.isSanctuary, isTrue);
    expect(journey.supportingSessionCount, 500);
    expect(journey.detail, contains('cannot undo'));
  });

  test('rejects an impossible negative cumulative count', () {
    expect(
      () => service.createState(completedFocusSessions: -1),
      throwsArgumentError,
    );
  });

  test('Riverpod derives the journey from the narrow timer summary', () {
    const summary = (
      todayFocusMinutes: 0,
      currentStreak: 0,
      completedFocusSessions: 10,
      dailyGoalMinutes: 60,
      dailyGoalProgress: 0.0,
      hasReachedDailyGoal: false,
      todayFocusSessions: 0,
      dailyChallengeTarget: 3,
      dailyChallengeProgress: 0.0,
      hasCompletedDailyChallenge: false,
    );
    final container = ProviderContainer(
      overrides: [timerSummaryStateProvider.overrideWithValue(summary)],
    );
    addTearDown(container.dispose);

    final journey = container.read(havenJourneyStateProvider);

    expect(journey.place, HavenJourneyPlace.garden);
    expect(journey.supportingSessionCount, 10);
  });
}
