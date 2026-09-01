import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/haven_journey_state.dart';

/// A read-only bridge from one exact completed Focus session to Haven Journey.
///
/// This card explains existing local derivation. It has no control, mutation,
/// persistence, task-content, reflection-content, or external-service surface.
class HavenJourneyCompletionConnectionCard extends StatelessWidget {
  const HavenJourneyCompletionConnectionCard({
    super.key,
    required this.connection,
  });

  final HavenJourneyCompletionConnection connection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final l10n = context.l10n;

    return Semantics(
      key: const ValueKey('haven-journey-completion-connection'),
      container: true,
      label: l10n.havenJourneyCompletionSemantics(
        connection.headline,
        connection.detail,
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.landscape_outlined, color: accent, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connection.enteredNewPlace
                            ? l10n.havenJourneyNewPlaceUpper
                            : l10n.havenJourneyCompletionKeptUpper,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  connection.headline,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  connection.detail,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: accent, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.havenJourneyNoAutomaticChange,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
