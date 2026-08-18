import 'package:flutter/material.dart';

import '../models/haven_journey_state.dart';

/// An accessible, noninteractive view of one private Haven Journey place.
///
/// Every place is presented as complete. The card has no progress bar, next-
/// milestone countdown, timer control, or navigation action.
class HavenJourneyCard extends StatelessWidget {
  const HavenJourneyCard({super.key, required this.state});

  final HavenJourneyState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _accent(colors, state.place);
    final placeLabel = _placeLabel(state.place);

    return Semantics(
      container: true,
      label:
          'Haven Journey. $placeLabel. ${state.headline}. ${state.detail} '
          'Built privately from completed focus sessions. No score or public ranking.',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('haven-journey-card'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.14),
                colors.surface.withValues(alpha: 0.44),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 16, 15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final stacks = constraints.maxWidth < 310 || textScale > 1.45;
                final illustration = _HavenJourneyIllustration(
                  place: state.place,
                  accent: accent,
                );
                final copy = _JourneyCopy(
                  state: state,
                  placeLabel: placeLabel,
                  accent: accent,
                );

                if (stacks) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: Alignment.center, child: illustration),
                      const SizedBox(height: 10),
                      copy,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    illustration,
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _placeLabel(HavenJourneyPlace place) => switch (place) {
    HavenJourneyPlace.lantern => 'Lantern',
    HavenJourneyPlace.campsite => 'Campsite',
    HavenJourneyPlace.cabin => 'Cabin',
    HavenJourneyPlace.garden => 'Garden',
    HavenJourneyPlace.sanctuary => 'Sanctuary',
  };

  static Color _accent(ColorScheme colors, HavenJourneyPlace place) =>
      switch (place) {
        HavenJourneyPlace.lantern => colors.primary,
        HavenJourneyPlace.campsite => colors.secondary,
        HavenJourneyPlace.cabin => colors.tertiary,
        HavenJourneyPlace.garden => colors.secondary,
        HavenJourneyPlace.sanctuary => colors.tertiary,
      };
}

class _JourneyCopy extends StatelessWidget {
  const _JourneyCopy({
    required this.state,
    required this.placeLabel,
    required this.accent,
  });

  final HavenJourneyState state;
  final String placeLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'HAVEN JOURNEY · ${placeLabel.toUpperCase()}',
        key: const ValueKey('haven-journey-place'),
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        state.headline,
        key: const ValueKey('haven-journey-headline'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        state.detail,
        key: const ValueKey('haven-journey-detail'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: accent, size: 14),
          const SizedBox(width: 5),
          const Expanded(
            child: Text(
              'Private and lasting · no score, decay, or public rank',
              style: TextStyle(fontSize: 11, height: 1.25),
            ),
          ),
        ],
      ),
    ],
  );
}

class _HavenJourneyIllustration extends StatelessWidget {
  const _HavenJourneyIllustration({required this.place, required this.accent});

  final HavenJourneyPlace place;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    height: 92,
    child: CustomPaint(
      key: const ValueKey('haven-journey-illustration'),
      painter: _HavenJourneyPainter(
        place: place,
        accent: accent,
        frame: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class _HavenJourneyPainter extends CustomPainter {
  const _HavenJourneyPainter({
    required this.place,
    required this.accent,
    required this.frame,
  });

  final HavenJourneyPlace place;
  final Color accent;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.30),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.52),
              radius: size.width * 0.48,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.52),
      size.width * 0.48,
      glow,
    );

    final line = Paint()
      ..color = frame.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.82),
      Offset(size.width * 0.94, size.height * 0.82),
      line,
    );

    switch (place) {
      case HavenJourneyPlace.lantern:
        _drawLantern(canvas, size, line, fill, 0.50, 0.47);
        break;
      case HavenJourneyPlace.campsite:
        _drawTent(canvas, size, line, fill);
        _drawLantern(canvas, size, line, fill, 0.22, 0.57);
        break;
      case HavenJourneyPlace.cabin:
        _drawCabin(canvas, size, line, fill);
        _drawLantern(canvas, size, line, fill, 0.20, 0.59);
        break;
      case HavenJourneyPlace.garden:
        _drawCabin(canvas, size, line, fill);
        _drawGarden(canvas, size, line);
        _drawLantern(canvas, size, line, fill, 0.16, 0.60);
        break;
      case HavenJourneyPlace.sanctuary:
        _drawSanctuary(canvas, size, line, fill);
        _drawGarden(canvas, size, line);
        _drawLantern(canvas, size, line, fill, 0.50, 0.50);
        break;
    }
  }

  void _drawLantern(
    Canvas canvas,
    Size size,
    Paint line,
    Paint fill,
    double x,
    double y,
  ) {
    final center = Offset(size.width * x, size.height * y);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.16,
        height: size.height * 0.26,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, line);
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, -size.height * 0.13),
        width: size.width * 0.10,
        height: size.height * 0.13,
      ),
      3.2,
      2.9,
      false,
      line,
    );
    canvas.drawCircle(center.translate(0, size.height * 0.02), 3.2, fill);
  }

  void _drawTent(Canvas canvas, Size size, Paint line, Paint fill) {
    final tent = Path()
      ..moveTo(size.width * 0.43, size.height * 0.80)
      ..lineTo(size.width * 0.68, size.height * 0.40)
      ..lineTo(size.width * 0.91, size.height * 0.80)
      ..close();
    canvas.drawPath(tent, fill);
    canvas.drawPath(tent, line);
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.40),
      Offset(size.width * 0.68, size.height * 0.80),
      line,
    );
  }

  void _drawCabin(Canvas canvas, Size size, Paint line, Paint fill) {
    final body = Rect.fromLTWH(
      size.width * 0.42,
      size.height * 0.48,
      size.width * 0.45,
      size.height * 0.33,
    );
    final roof = Path()
      ..moveTo(size.width * 0.36, size.height * 0.50)
      ..lineTo(size.width * 0.64, size.height * 0.25)
      ..lineTo(size.width * 0.92, size.height * 0.50)
      ..close();
    canvas.drawRect(body, fill);
    canvas.drawRect(body, line);
    canvas.drawPath(roof, fill);
    canvas.drawPath(roof, line);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.60,
        size.height * 0.61,
        size.width * 0.10,
        size.height * 0.20,
      ),
      line,
    );
  }

  void _drawGarden(Canvas canvas, Size size, Paint line) {
    for (final x in <double>[0.27, 0.36, 0.79, 0.88]) {
      final stemTop = Offset(size.width * x, size.height * 0.67);
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.82),
        stemTop,
        line,
      );
      canvas.drawCircle(
        stemTop,
        3.2,
        Paint()..color = accent.withValues(alpha: 0.78),
      );
    }
  }

  void _drawSanctuary(Canvas canvas, Size size, Paint line, Paint fill) {
    final arch = Path()
      ..moveTo(size.width * 0.24, size.height * 0.81)
      ..lineTo(size.width * 0.24, size.height * 0.49)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.18,
        size.width * 0.76,
        size.height * 0.49,
      )
      ..lineTo(size.width * 0.76, size.height * 0.81);
    canvas.drawPath(arch, line);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.42, size.height * 0.82)
        ..lineTo(size.width * 0.48, size.height * 0.65)
        ..lineTo(size.width * 0.52, size.height * 0.65)
        ..lineTo(size.width * 0.58, size.height * 0.82)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HavenJourneyPainter oldDelegate) =>
      oldDelegate.place != place ||
      oldDelegate.accent != accent ||
      oldDelegate.frame != frame;
}
