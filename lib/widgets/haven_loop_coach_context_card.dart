import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/focus_haven_localizations.dart';
import '../models/haven_loop_coach_context.dart';
import '../models/haven_journey_state.dart';

/// A read-only disclosure of the text-free Haven Loop moment Local Coach may
/// use. It exposes no task text, identifier, control, or mutable state.
class HavenLoopCoachContextCard extends StatelessWidget {
  const HavenLoopCoachContextCard({required this.loopContext, super.key});

  final HavenLoopCoachContext loopContext;

  String _detail(AppLocalizations l10n) => switch (loopContext.moment) {
    HavenLoopCoachMoment.smartResetChoice =>
      '${l10n.smartResetPauseStillCounts} '
          '${l10n.smartResetLinkedTaskBoundary}',
    HavenLoopCoachMoment.taskDecision => l10n.havenLoopDecisionDescription,
    HavenLoopCoachMoment.reflectionChoice =>
      '${l10n.focusReflectionTitle} ${l10n.focusReflectionDescription}',
    HavenLoopCoachMoment.gentlerNextSession =>
      l10n.havenPlanServiceReflectionTooMuch,
    HavenLoopCoachMoment.steadyNextSession =>
      l10n.havenPlanServiceReflectionAboutRight,
    HavenLoopCoachMoment.flexibleNextSession =>
      l10n.havenPlanServiceReflectionCouldDoMore,
  };

  List<String> _connectionLabels(AppLocalizations l10n) => <String>[
    if (loopContext.usesRhythm) l10n.havenRhythmReflectionSavedUpper,
    if (loopContext.usesForecast) l10n.focusForecastReflectionSavedUpper,
    if (loopContext.journeyKind ==
        HavenJourneyCompletionConnectionKind.placeChanged)
      l10n.havenJourneyNewPlaceUpper
    else if (loopContext.usesJourney)
      l10n.havenJourneyCompletionKeptUpper,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = _detail(l10n);
    final connectionLabels = _connectionLabels(l10n);
    final semantics = <String>[
      l10n.havenLoopNextStepUpper,
      detail,
      ...connectionLabels,
      l10n.havenRhythmPrivacy,
      l10n.havenRhythmNoAutomaticChange,
    ].join('. ');
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      key: const ValueKey<String>('haven-loop-coach-context'),
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.havenLoopNextStepUpper,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(detail),
                if (connectionLabels.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final label in connectionLabels)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(label),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.havenRhythmPrivacy,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.havenRhythmNoAutomaticChange,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
