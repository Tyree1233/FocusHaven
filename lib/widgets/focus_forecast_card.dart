import 'package:flutter/material.dart';

import '../models/focus_forecast.dart';

/// A compact, expandable view of one private Focus Forecast observation.
///
/// The card describes completed-session timing without claiming a best time,
/// predicting success, scheduling work, or controlling the timer.
class FocusForecastCard extends StatefulWidget {
  const FocusForecastCard({super.key, required this.forecast});

  final FocusForecast forecast;

  @override
  State<FocusForecastCard> createState() => _FocusForecastCardState();
}

class _FocusForecastCardState extends State<FocusForecastCard> {
  bool _isExpanded = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final forecast = widget.forecast;
    final colors = Theme.of(context).colorScheme;
    final accent = _accentColor(forecast.kind, colors);
    final borderRadius = BorderRadius.circular(18);

    return Material(
      key: const ValueKey('focus-forecast-card'),
      color: accent.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            onTap: _toggle,
            label:
                'Focus Forecast. ${_kindLabel(forecast.kind)}. '
                '${forecast.headline}. '
                '${_isExpanded ? 'Hide details.' : 'Show details.'}',
            child: ExcludeSemantics(
              child: InkWell(
                key: const ValueKey('toggle-focus-forecast'),
                borderRadius: borderRadius,
                onTap: _toggle,
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
                          child: Icon(
                            _kindIcon(forecast.kind),
                            color: accent,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FOCUS FORECAST · ${_kindLabel(forecast.kind).toUpperCase()}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.75,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              forecast.headline,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: accent.withValues(alpha: 0.20)),
            Padding(
              key: const ValueKey('focus-forecast-details'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    forecast.detail,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: _ForecastNote(
                        icon: Icons.schedule_rounded,
                        text: forecast.evidence,
                        accent: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _ForecastNote(
                    icon: Icons.explore_outlined,
                    text:
                        'A possible window is not a promise. Your energy and real-life availability keep leading.',
                    accent: accent,
                  ),
                  const SizedBox(height: 9),
                  _ForecastNote(
                    icon: Icons.lock_outline_rounded,
                    text:
                        'Calculated on this device from text-free completed-session timing. No task text, productivity score, or automatic schedule.',
                    accent: accent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _accentColor(FocusForecastKind kind, ColorScheme colors) =>
      switch (kind) {
        FocusForecastKind.learning => colors.secondary,
        FocusForecastKind.emergingWindow => colors.primary,
        FocusForecastKind.flexible => colors.tertiary,
      };

  static String _kindLabel(FocusForecastKind kind) => switch (kind) {
    FocusForecastKind.learning => 'Still learning',
    FocusForecastKind.emergingWindow => 'Possible window',
    FocusForecastKind.flexible => 'Flexible timing',
  };

  static IconData _kindIcon(FocusForecastKind kind) => switch (kind) {
    FocusForecastKind.learning => Icons.hourglass_empty_rounded,
    FocusForecastKind.emergingWindow => Icons.wb_twilight_outlined,
    FocusForecastKind.flexible => Icons.waves_rounded,
  };
}

class _ForecastNote extends StatelessWidget {
  const _ForecastNote({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: accent, size: 17),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}
