import 'package:flutter/material.dart';

import '../models/haven_rhythm_insight.dart';

/// A calm, expandable view of one ephemeral local Haven Rhythm insight.
///
/// The collapsed card shows only the current headline. Evidence and any pace
/// suggestion remain behind an explicit tap, and the card never controls the
/// timer or schedules work.
class HavenRhythmCard extends StatefulWidget {
  const HavenRhythmCard({super.key, required this.insight});

  final HavenRhythmInsight insight;

  @override
  State<HavenRhythmCard> createState() => _HavenRhythmCardState();
}

class _HavenRhythmCardState extends State<HavenRhythmCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = insight.isLearning
        ? colorScheme.secondary
        : colorScheme.primary;
    final borderRadius = BorderRadius.circular(18);

    return Material(
      key: const ValueKey('haven-rhythm-card'),
      color: accent.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('toggle-haven-rhythm'),
            borderRadius: borderRadius,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 11, 13),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(_icon(insight.kind), color: accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HAVEN RHYTHM · ${_kindLabel(insight.kind).toUpperCase()}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.headline,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: accent.withValues(alpha: 0.20)),
            Padding(
              key: const ValueKey('haven-rhythm-details'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    insight.detail,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.search_rounded, color: accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              insight.evidence,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (insight.suggestedFocusMinutes != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 17),
                        label: Text(
                          'Possible pace · ${insight.suggestedFocusMinutes} min',
                        ),
                        backgroundColor: accent.withValues(alpha: 0.14),
                        side: BorderSide.none,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Built privately from text-free focus signals. No productivity score.',
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
          ],
        ],
      ),
    );
  }

  static String _kindLabel(HavenRhythmKind kind) => switch (kind) {
    HavenRhythmKind.learning => 'Still learning',
    HavenRhythmKind.gentleReturn => 'Gentle return',
    HavenRhythmKind.gentlerPace => 'Gentler pace',
    HavenRhythmKind.sustainablePace => 'Sustainable pace',
    HavenRhythmKind.roomToGrow => 'Room to grow',
    HavenRhythmKind.variablePace => 'Flexible rhythm',
    HavenRhythmKind.completionPattern => 'Pattern emerging',
  };

  static IconData _icon(HavenRhythmKind kind) => switch (kind) {
    HavenRhythmKind.learning => Icons.hourglass_empty_rounded,
    HavenRhythmKind.gentleReturn => Icons.replay_rounded,
    HavenRhythmKind.gentlerPace => Icons.self_improvement_rounded,
    HavenRhythmKind.sustainablePace => Icons.spa_outlined,
    HavenRhythmKind.roomToGrow => Icons.north_east_rounded,
    HavenRhythmKind.variablePace => Icons.tune_rounded,
    HavenRhythmKind.completionPattern => Icons.insights_rounded,
  };
}
