import '../models/focus_event.dart';
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

  HavenJourneyCompletionConnection? createCompletionConnection({
    required FocusCompletionIdentity completion,
    required List<FocusEvent> recentEvents,
    required HavenJourneyState journey,
  }) {
    final ordered = [...recentEvents]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    if (ordered.isEmpty || ordered.first.completionIdentity != completion) {
      return null;
    }

    final matches = ordered
        .where((event) => event.completionIdentity == completion)
        .toList(growable: false);
    if (matches.length != 1 || journey.supportingSessionCount < 1) return null;

    final verifiedCurrent = createState(
      completedFocusSessions: journey.supportingSessionCount,
    );
    if (verifiedCurrent.place != journey.place ||
        verifiedCurrent.headline != journey.headline ||
        verifiedCurrent.detail != journey.detail) {
      return null;
    }

    final previous = createState(
      completedFocusSessions: journey.supportingSessionCount - 1,
    );
    final changedPlace = previous.place != journey.place;
    final (headline, detail) = changedPlace
        ? (
            'This completed Focus session opened a new Haven place',
            'Your private Journey now rests at ${_placeLabel(journey.place)}. The change comes only from the existing cumulative completion count.',
          )
        : (
            'This completed Focus session belongs in your Haven',
            'Your private Journey remains at ${_placeLabel(journey.place)}. Every completed Focus session is kept equally, without a score or streak requirement.',
          );

    return HavenJourneyCompletionConnection(
      kind: changedPlace
          ? HavenJourneyCompletionConnectionKind.placeChanged
          : HavenJourneyCompletionConnectionKind.placeHeld,
      completion: completion,
      previousPlace: previous.place,
      currentPlace: journey.place,
      headline: headline,
      detail: detail,
    );
  }

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

  static String _placeLabel(HavenJourneyPlace place) => switch (place) {
    HavenJourneyPlace.lantern => 'the lantern',
    HavenJourneyPlace.campsite => 'the campsite',
    HavenJourneyPlace.cabin => 'the quiet cabin',
    HavenJourneyPlace.garden => 'the gentle garden',
    HavenJourneyPlace.sanctuary => 'the sanctuary',
  };
}
