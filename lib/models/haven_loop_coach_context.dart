import 'focus_event.dart';
import 'focus_forecast.dart';
import 'haven_journey_state.dart';
import 'haven_rhythm_insight.dart';

/// The one current, text-free Haven Loop moment available to Local Coach.
enum HavenLoopCoachMoment {
  smartResetChoice,
  taskDecision,
  reflectionChoice,
  gentlerNextSession,
  steadyNextSession,
  flexibleNextSession,
}

/// An ephemeral, local-only view of one exact Haven Loop boundary.
///
/// This object deliberately contains no task title, queue identifier, journal
/// text, mood label, transcript, account value, or localized prose. It is
/// rebuilt from the services that own the underlying state and is never
/// persisted or included in remote coaching payloads.
class HavenLoopCoachContext {
  const HavenLoopCoachContext({
    required this.moment,
    required this.hasLinkedTask,
    this.completion,
    this.sessionFit,
    this.rhythmKind,
    this.forecastKind,
    this.journeyKind,
  });

  final HavenLoopCoachMoment moment;
  final bool hasLinkedTask;
  final FocusCompletionIdentity? completion;
  final FocusSessionFit? sessionFit;
  final HavenRhythmReflectionConnectionKind? rhythmKind;
  final FocusForecastReflectionConnectionKind? forecastKind;
  final HavenJourneyCompletionConnectionKind? journeyKind;

  bool get isCompletionMoment => completion != null;
  bool get usesRhythm => rhythmKind != null;
  bool get usesForecast => forecastKind != null;
  bool get usesJourney => journeyKind != null;

  @override
  bool operator ==(Object other) =>
      other is HavenLoopCoachContext &&
      other.moment == moment &&
      other.hasLinkedTask == hasLinkedTask &&
      other.completion == completion &&
      other.sessionFit == sessionFit &&
      other.rhythmKind == rhythmKind &&
      other.forecastKind == forecastKind &&
      other.journeyKind == journeyKind;

  @override
  int get hashCode => Object.hash(
    moment,
    hasLinkedTask,
    completion,
    sessionFit,
    rhythmKind,
    forecastKind,
    journeyKind,
  );
}
