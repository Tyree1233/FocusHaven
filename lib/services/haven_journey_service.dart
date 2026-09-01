import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
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
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
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
      localizations: l10n,
    );
    if (verifiedCurrent.place != journey.place ||
        verifiedCurrent.headline != journey.headline ||
        verifiedCurrent.detail != journey.detail) {
      return null;
    }

    final previous = createState(
      completedFocusSessions: journey.supportingSessionCount - 1,
      localizations: l10n,
    );
    final changedPlace = previous.place != journey.place;
    final (headline, detail) = changedPlace
        ? (
            l10n.havenJourneyConnectionChangedHeadline,
            l10n.havenJourneyConnectionChangedDetail(
              _placeLabel(journey.place, l10n),
            ),
          )
        : (
            l10n.havenJourneyConnectionHeldHeadline,
            l10n.havenJourneyConnectionHeldDetail(
              _placeLabel(journey.place, l10n),
            ),
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

  HavenJourneyState createState({
    required int completedFocusSessions,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    if (completedFocusSessions < 0) {
      throw ArgumentError.value(
        completedFocusSessions,
        'completedFocusSessions',
        l10n.havenJourneyNegativeCompletionCount,
      );
    }

    if (completedFocusSessions >= _sanctuarySessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.sanctuary,
        headline: l10n.havenJourneySanctuaryHeadline,
        detail: l10n.havenJourneySanctuaryDetail,
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _gardenSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.garden,
        headline: l10n.havenJourneyGardenHeadline,
        detail: l10n.havenJourneyGardenDetail,
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _cabinSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.cabin,
        headline: l10n.havenJourneyCabinHeadline,
        detail: l10n.havenJourneyCabinDetail,
        supportingSessionCount: completedFocusSessions,
      );
    }
    if (completedFocusSessions >= _campsiteSessions) {
      return HavenJourneyState(
        place: HavenJourneyPlace.campsite,
        headline: l10n.havenJourneyCampsiteHeadline,
        detail: l10n.havenJourneyCampsiteDetail,
        supportingSessionCount: completedFocusSessions,
      );
    }

    return HavenJourneyState(
      place: HavenJourneyPlace.lantern,
      headline: l10n.havenJourneyLanternHeadline,
      detail: l10n.havenJourneyLanternDetail,
      supportingSessionCount: 0,
    );
  }

  static String _placeLabel(HavenJourneyPlace place, AppLocalizations l10n) =>
      switch (place) {
        HavenJourneyPlace.lantern => l10n.havenJourneyLanternLabel,
        HavenJourneyPlace.campsite => l10n.havenJourneyCampsiteLabel,
        HavenJourneyPlace.cabin => l10n.havenJourneyCabinLabel,
        HavenJourneyPlace.garden => l10n.havenJourneyGardenLabel,
        HavenJourneyPlace.sanctuary => l10n.havenJourneySanctuaryLabel,
      };
}
