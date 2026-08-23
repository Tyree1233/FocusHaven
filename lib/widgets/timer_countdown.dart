import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Displays the active countdown while limiting one-second rebuilds to this
/// small subtree.
class TimerCountdown extends ConsumerWidget {
  const TimerCountdown({
    required this.sessionColor,
    required this.formatTime,
    required this.durationLabel,
    super.key,
  });

  final Color sessionColor;
  final String Function(int seconds) formatTime;
  final String Function(int seconds) durationLabel;

  String _accessibleDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final parts = <String>[];
    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (remainingSeconds > 0 || parts.isEmpty) {
      parts.add(
        '$remainingSeconds ${remainingSeconds == 1 ? 'second' : 'seconds'}',
      );
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(timerCountdownStateProvider);
    final progress = countdown.progress.clamp(0, 1).toDouble();
    final percentComplete = (progress * 100).round();

    return Semantics(
      key: const ValueKey('timer-countdown-semantics'),
      container: true,
      label: 'Session timer',
      value:
          '${_accessibleDuration(countdown.secondsRemaining)} remaining '
          'of ${_accessibleDuration(countdown.totalSessionSeconds)}. '
          '$percentComplete percent complete.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 270.0;
            final diameter = availableWidth.clamp(0.0, 270.0).toDouble();
            final innerWidth = (diameter - 48).clamp(0.0, 222.0).toDouble();

            return SizedBox.square(
              dimension: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: diameter,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      color: sessionColor,
                    ),
                  ),
                  SizedBox.square(
                    dimension: innerWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: innerWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatTime(countdown.secondsRemaining),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              durationLabel(countdown.totalSessionSeconds),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
