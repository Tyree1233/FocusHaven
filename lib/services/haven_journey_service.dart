import '../models/haven_journey_state.dart';

/// Derives a durable-feeling Haven place from an existing cumulative signal.
///
/// The result is rebuilt locally and is never persisted by itself. Completed
/// sessions can move the Haven forward, while resets, pauses, breaks, missed
/// days, and time away are deliberately absent from the input and cannot take
/// anything away.
class HavenJourneyService {
  const HavenJourneyService();

  static const _campsiteSessions = 1;
  static const _cabinSessions = 4;
  static const _gardenSessions = 10;
  static const _sanctuarySessions = 25;

  HavenJourneyState createState({required int completedFocusSessions}) {
    if (completedFocusSessions < 0) {
      throw ArgumentError.value(
        completedFocusSessions,
        'completedFocusSessions',
        'A cumulative completion count cannot be negative.',
      );
    }

    if (completedFocusSessions >= _sanctuarySessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.sanctuary,
        headline: 'Your Haven has become a sanctuary',
        detail:
            'Every completed focus moment still belongs here. Rest and difficult days cannot undo what you built.',
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _gardenSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.garden,
        headline: 'A gentle garden is growing',
        detail:
            'Your completed sessions have made room for something living. The garden keeps its shape without demanding a streak.',
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _cabinSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.cabin,
        headline: 'Your Haven has a quiet cabin',
        detail:
            'Focus has created a place to return to. Pauses and resets never remove anything from it.',
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _campsiteSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.campsite,
        headline: 'A quiet campsite is taking shape',
        detail:
            'One completed session was enough to begin. This place can wait with you for as long as you need.',
        supportingSessionCount: completedFocusSessions,
      );
    }

    return const HavenJourneyState(
      place: HavenJourneyPlace.lantern,
      headline: 'Your Haven begins with one whole light',
      detail:
          'Nothing is missing and there is nothing to prove. The lantern is ready whenever you choose to focus.',
      supportingSessionCount: 0,
    );
  }
}
