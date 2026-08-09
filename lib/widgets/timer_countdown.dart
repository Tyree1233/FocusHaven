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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(timerCountdownStateProvider);

    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 270,
            height: 270,
            child: CircularProgressIndicator(
              value: countdown.progress.clamp(0, 1),
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              color: sessionColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTime(countdown.secondsRemaining),
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                durationLabel(countdown.totalSessionSeconds),
                style: const TextStyle(
                  color: Colors.white60,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
