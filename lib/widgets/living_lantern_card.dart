import 'package:flutter/material.dart';

import '../models/living_lantern_state.dart';

/// An accessible, noninteractive view of one ephemeral Living Lantern state.
///
/// Every phase keeps the same complete lantern and flame. Color, language, and
/// the small phase symbol can change, but interruption never damages the visual
/// or removes progress.
class LivingLanternCard extends StatelessWidget {
  const LivingLanternCard({super.key, required this.state});

  final LivingLanternState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _accent(colorScheme, state.phase);
    final phaseLabel = _phaseLabel(state.phase);

    return Semantics(
      container: true,
      label: 'Living Lantern. $phaseLabel. ${state.headline}. ${state.detail}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('living-lantern-card'),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LivingLanternIllustration(accent: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _phaseIcon(state.phase),
                            color: accent,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'LIVING LANTERN · ${phaseLabel.toUpperCase()}',
                              key: const ValueKey('living-lantern-phase'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.75,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        state.headline,
                        key: const ValueKey('living-lantern-headline'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.detail,
                        key: const ValueKey('living-lantern-detail'),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _accent(ColorScheme colors, LivingLanternPhase phase) =>
      switch (phase) {
        LivingLanternPhase.ready => colors.primary,
        LivingLanternPhase.focusing => colors.primary,
        LivingLanternPhase.resting => colors.secondary,
        LivingLanternPhase.celebrating => colors.tertiary,
        LivingLanternPhase.gentleReturn => colors.secondary,
      };

  static String _phaseLabel(LivingLanternPhase phase) => switch (phase) {
    LivingLanternPhase.ready => 'Ready',
    LivingLanternPhase.focusing => 'Steady focus',
    LivingLanternPhase.resting => 'Resting',
    LivingLanternPhase.celebrating => 'Celebrating',
    LivingLanternPhase.gentleReturn => 'Gentle return',
  };

  static IconData _phaseIcon(LivingLanternPhase phase) => switch (phase) {
    LivingLanternPhase.ready => Icons.auto_awesome_rounded,
    LivingLanternPhase.focusing => Icons.center_focus_strong_rounded,
    LivingLanternPhase.resting => Icons.nightlight_round,
    LivingLanternPhase.celebrating => Icons.celebration_rounded,
    LivingLanternPhase.gentleReturn => Icons.replay_rounded,
  };
}

class _LivingLanternIllustration extends StatelessWidget {
  const _LivingLanternIllustration({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 66,
    height: 78,
    child: CustomPaint(
      key: const ValueKey('living-lantern-illustration'),
      painter: _LivingLanternPainter(
        accent: accent,
        frame: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class _LivingLanternPainter extends CustomPainter {
  const _LivingLanternPainter({required this.accent, required this.frame});

  final Color accent;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.34),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.48),
          );
    canvas.drawCircle(center, size.width * 0.48, glowPaint);

    final framePaint = Paint()
      ..color = frame.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.19,
        size.height * 0.28,
        size.width * 0.62,
        size.height * 0.59,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(body, framePaint);
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.30,
        size.height * 0.08,
        size.width * 0.40,
        size.height * 0.38,
      ),
      3.25,
      2.93,
      false,
      framePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.36),
      Offset(size.width * 0.82, size.height * 0.36),
      framePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.82, size.height * 0.78),
      framePaint,
    );

    final flame = Path()
      ..moveTo(size.width * 0.50, size.height * 0.72)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.62,
        size.width * 0.39,
        size.height * 0.48,
        size.width * 0.53,
        size.height * 0.39,
      )
      ..cubicTo(
        size.width * 0.52,
        size.height * 0.51,
        size.width * 0.70,
        size.height * 0.55,
        size.width * 0.64,
        size.height * 0.66,
      )
      ..cubicTo(
        size.width * 0.61,
        size.height * 0.72,
        size.width * 0.55,
        size.height * 0.74,
        size.width * 0.50,
        size.height * 0.72,
      )
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..color = accent
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _LivingLanternPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.frame != frame;
}
