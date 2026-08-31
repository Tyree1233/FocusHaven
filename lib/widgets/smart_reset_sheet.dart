import 'package:flutter/material.dart';

import '../models/smart_reset_plan.dart';

enum SmartResetChoice { restart, reset, keep }

class SmartResetSheet extends StatefulWidget {
  const SmartResetSheet({
    required this.plan,
    this.preservesSelectedTask = false,
    super.key,
  });

  final SmartResetPlan plan;
  final bool preservesSelectedTask;

  @override
  State<SmartResetSheet> createState() => _SmartResetSheetState();
}

class _SmartResetSheetState extends State<SmartResetSheet> {
  bool _isClosing = false;

  String _durationLabel(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return remaining == 0 ? '$minutes min' : '$minutes min $remaining sec';
  }

  void _close(SmartResetChoice choice) {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final colors = Theme.of(context).colorScheme;
    final progressMessage = plan.focusedDurationSeconds >= 60
        ? '${_durationLabel(plan.focusedDurationSeconds)} of focus still counts.'
        : 'Pausing to choose a better fit still counts.';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Icon(Icons.refresh_rounded, size: 34, color: colors.primary),
            const SizedBox(height: 12),
            const Text(
              'This session isn’t a failure',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              progressMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  children: [
                    const Text(
                      'A SMALLER WAY BACK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _durationLabel(plan.restartDurationSeconds),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.explanation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 17, color: Colors.white60),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Calculated privately on this device from time-only focus signals.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (widget.preservesSelectedTask) ...[
              const SizedBox(height: 12),
              const Row(
                key: ValueKey('smart-reset-linked-task-boundary'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.link_rounded, size: 17, color: Colors.white60),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Your selected queue item stays linked only while it remains active and unchanged. No task text is copied into Smart Reset.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('smart-reset-restart'),
              onPressed: _isClosing
                  ? null
                  : () => _close(SmartResetChoice.restart),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Restart with ${_durationLabel(plan.restartDurationSeconds)}',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('smart-reset-plain-reset'),
              onPressed: _isClosing
                  ? null
                  : () => _close(SmartResetChoice.reset),
              child: const Text('Reset without restarting'),
            ),
            TextButton(
              key: const ValueKey('smart-reset-keep'),
              onPressed: _isClosing
                  ? null
                  : () => _close(SmartResetChoice.keep),
              child: const Text('Keep this session'),
            ),
          ],
        ),
      ),
    );
  }
}
