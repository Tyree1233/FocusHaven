import 'package:flutter/material.dart';

import '../models/focus_event.dart';
import '../models/haven_rhythm_insight.dart';

/// A compact, informational bridge from one saved reflection to Haven Rhythm.
///
/// This surface offers no control because a reflection may inform a future
/// observation but must never silently adapt the timer.
class HavenRhythmReflectionConnectionCard extends StatelessWidget {
  const HavenRhythmReflectionConnectionCard({
    super.key,
    required this.connection,
  });

  final HavenRhythmReflectionConnection connection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.tertiary;

    return Semantics(
      key: const ValueKey('haven-rhythm-reflection-connection'),
      container: true,
      label:
          'Haven Rhythm reflection update. ${connection.headline}. ${connection.detail}. Nothing changed automatically.',
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
                  Icon(Icons.insights_outlined, color: accent, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HAVEN RHYTHM · REFLECTION SAVED',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Text(
                    _fitLabel(connection.selectedFit),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
                      'Nothing changed automatically. Your next session remains your choice.',
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
    );
  }

  static String _fitLabel(FocusSessionFit fit) => switch (fit) {
    FocusSessionFit.tooMuch => 'Too much',
    FocusSessionFit.aboutRight => 'About right',
    FocusSessionFit.couldDoMore => 'Could do more',
  };
}
