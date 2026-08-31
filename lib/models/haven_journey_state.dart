import 'focus_event.dart';

enum HavenJourneyPlace { lantern, campsite, cabin, garden, sanctuary }

enum HavenJourneyCompletionConnectionKind { placeHeld, placeChanged }

/// One ephemeral explanation of how the exact current completion relates to
/// the already-derived Haven Journey.
///
/// It contains only text-free completion identity and cumulative place state.
/// Task titles, queue identifiers, reflections, and authored content are
/// deliberately absent.
class HavenJourneyCompletionConnection {
  const HavenJourneyCompletionConnection({
    required this.kind,
    required this.completion,
    required this.previousPlace,
    required this.currentPlace,
    required this.headline,
    required this.detail,
  });

  final HavenJourneyCompletionConnectionKind kind;
  final FocusCompletionIdentity completion;
  final HavenJourneyPlace previousPlace;
  final HavenJourneyPlace currentPlace;
  final String headline;
  final String detail;

  bool get enteredNewPlace =>
      kind == HavenJourneyCompletionConnectionKind.placeChanged;
}

/// One calm, local interpretation of the Haven the person has built.
///
/// The journey has no score, health, streak requirement, competitive rank, or
/// failure state. A place can grow after completed focus, but interruptions,
/// rest, and time away can never shrink it.
class HavenJourneyState {
  const HavenJourneyState({
    required this.place,
    required this.headline,
    required this.detail,
    required this.supportingSessionCount,
  });

  final HavenJourneyPlace place;
  final String headline;
  final String detail;

  /// The cumulative completed-session count that established this place.
  ///
  /// This is transparent evidence, not points or a public productivity score.
  final int supportingSessionCount;

  bool get hasBegun => supportingSessionCount > 0;
  bool get isSanctuary => place == HavenJourneyPlace.sanctuary;
}
