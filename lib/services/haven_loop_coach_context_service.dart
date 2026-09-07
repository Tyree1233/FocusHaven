import '../models/focus_event.dart';
import '../models/focus_forecast.dart';
import '../models/haven_journey_state.dart';
import '../models/haven_loop_coach_context.dart';
import '../models/haven_loop_state.dart';
import '../models/haven_rhythm_insight.dart';
import 'timer_service.dart';

/// Builds one fail-closed, ephemeral bridge from Haven Loop to Local Coach.
///
/// Every input remains owned by its existing service. The bridge copies only
/// enums, booleans, and one text-free completion identity; it has no mutation,
/// persistence, networking, or remote-coaching authority.
class HavenLoopCoachContextService {
  const HavenLoopCoachContextService();

  HavenLoopCoachContext? createContext({
    required HavenLoopState loop,
    required SessionType sessionType,
    required bool isComplete,
    required bool canOfferSmartReset,
    required FocusCompletionIdentity? completion,
    required FocusSessionFit? sessionFit,
    required List<FocusEvent> recentEvents,
    required HavenRhythmReflectionConnection? rhythmConnection,
    required FocusForecastReflectionConnection? forecastConnection,
    required HavenJourneyCompletionConnection? journeyConnection,
  }) {
    if (!loop.isInitialized || sessionType != SessionType.focus) return null;

    final phaseIsComplete = loop.phase == HavenLoopPhase.completed;
    if (phaseIsComplete != isComplete) return null;

    if (loop.phase == HavenLoopPhase.paused) {
      if (!canOfferSmartReset || !loop.hasSelectedTask) return null;
      if (completion != null ||
          sessionFit != null ||
          rhythmConnection != null ||
          forecastConnection != null ||
          journeyConnection != null) {
        return null;
      }
      return const HavenLoopCoachContext(
        moment: HavenLoopCoachMoment.smartResetChoice,
        hasLinkedTask: true,
      );
    }

    if (!isComplete) return null;
    final matchedEvent = _exactCurrentCompletion(
      completion: completion,
      recentEvents: recentEvents,
    );
    if (matchedEvent == null || matchedEvent.sessionFit != sessionFit) {
      return null;
    }

    if (loop.canResolveCompletion) {
      if (!loop.hasSelectedTask || sessionFit != null) return null;
      if (rhythmConnection != null ||
          forecastConnection != null ||
          journeyConnection != null) {
        return null;
      }
      return HavenLoopCoachContext(
        moment: HavenLoopCoachMoment.taskDecision,
        hasLinkedTask: true,
        completion: completion,
      );
    }

    if (loop.hasSelectedTask) return null;
    if (!_matchesReflectionConnection(
          rhythmConnection?.completion,
          rhythmConnection?.selectedFit,
          completion,
          sessionFit,
        ) ||
        !_matchesReflectionConnection(
          forecastConnection?.completion,
          forecastConnection?.selectedFit,
          completion,
          sessionFit,
        ) ||
        !_matchesCompletion(journeyConnection?.completion, completion)) {
      return null;
    }

    final moment = switch (sessionFit) {
      null => HavenLoopCoachMoment.reflectionChoice,
      FocusSessionFit.tooMuch => HavenLoopCoachMoment.gentlerNextSession,
      FocusSessionFit.aboutRight => HavenLoopCoachMoment.steadyNextSession,
      FocusSessionFit.couldDoMore => HavenLoopCoachMoment.flexibleNextSession,
    };
    return HavenLoopCoachContext(
      moment: moment,
      hasLinkedTask: false,
      completion: completion,
      sessionFit: sessionFit,
      rhythmKind: rhythmConnection?.kind,
      forecastKind: forecastConnection?.kind,
      journeyKind: journeyConnection?.kind,
    );
  }

  FocusEvent? _exactCurrentCompletion({
    required FocusCompletionIdentity? completion,
    required List<FocusEvent> recentEvents,
  }) {
    if (completion == null || recentEvents.isEmpty) return null;
    final matches = recentEvents
        .where((event) => event.completionIdentity == completion)
        .toList(growable: false);
    if (matches.length != 1 ||
        recentEvents.last.completionIdentity != completion) {
      return null;
    }
    return matches.single;
  }

  bool _matchesReflectionConnection(
    FocusCompletionIdentity? connectionCompletion,
    FocusSessionFit? connectionFit,
    FocusCompletionIdentity? completion,
    FocusSessionFit? sessionFit,
  ) {
    if (connectionCompletion == null && connectionFit == null) return true;
    return connectionCompletion == completion &&
        connectionFit != null &&
        connectionFit == sessionFit;
  }

  bool _matchesCompletion(
    FocusCompletionIdentity? connectionCompletion,
    FocusCompletionIdentity? completion,
  ) => connectionCompletion == null || connectionCompletion == completion;
}
