import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
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
    final l10n = context.l10n;
    if (seconds < 60) return l10n.durationSecondsShort(seconds.toString());
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return remaining == 0
        ? l10n.durationMinutesShort(minutes)
        : '${l10n.durationMinutesShort(minutes)} '
              '${l10n.durationSecondsShort(remaining.toString())}';
  }

  void _close(SmartResetChoice choice) {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final progressMessage = plan.focusedDurationSeconds >= 60
        ? l10n.smartResetFocusStillCounts(
            _durationLabel(plan.focusedDurationSeconds),
          )
        : l10n.smartResetPauseStillCounts;

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
            Text(
              l10n.smartResetTitle,
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
                    Text(
                      l10n.smartResetSmallerWayBackUpper,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 17, color: Colors.white60),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.smartResetPrivacy,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (widget.preservesSelectedTask) ...[
              const SizedBox(height: 12),
              Row(
                key: ValueKey('smart-reset-linked-task-boundary'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.link_rounded, size: 17, color: Colors.white60),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l10n.smartResetLinkedTaskBoundary,
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
                l10n.smartResetRestartWith(
                  _durationLabel(plan.restartDurationSeconds),
                ),
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
              child: Text(l10n.smartResetResetWithoutRestarting),
            ),
            TextButton(
              key: const ValueKey('smart-reset-keep'),
              onPressed: _isClosing
                  ? null
                  : () => _close(SmartResetChoice.keep),
              child: Text(l10n.smartResetKeepSession),
            ),
          ],
        ),
      ),
    );
  }
}
