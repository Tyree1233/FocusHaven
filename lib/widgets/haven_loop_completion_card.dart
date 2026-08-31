import 'package:flutter/material.dart';

import '../services/haven_loop_service.dart';

typedef HavenLoopResolutionAction = Future<HavenLoopResolution> Function();

class HavenLoopCompletionCard extends StatefulWidget {
  const HavenLoopCompletionCard({
    required this.taskTitle,
    required this.onMarkComplete,
    required this.onKeepForLater,
    super.key,
  });

  final String taskTitle;
  final HavenLoopResolutionAction onMarkComplete;
  final HavenLoopResolutionAction onKeepForLater;

  @override
  State<HavenLoopCompletionCard> createState() =>
      _HavenLoopCompletionCardState();
}

class _HavenLoopCompletionCardState extends State<HavenLoopCompletionCard> {
  bool _isResolving = false;

  Future<void> _resolve(HavenLoopResolutionAction action) async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result != HavenLoopResolution.unavailable) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That task changed, so no queue action was taken.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The queue could not be updated. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('haven-loop-completion-card'),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ONE CALM NEXT STEP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.taskTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'You decide whether this queue task is finished. FocusHaven never completes it automatically.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('haven-loop-mark-complete'),
                  onPressed: _isResolving
                      ? null
                      : () => _resolve(widget.onMarkComplete),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark task complete'),
                ),
                OutlinedButton(
                  key: const ValueKey('haven-loop-keep-for-later'),
                  onPressed: _isResolving
                      ? null
                      : () => _resolve(widget.onKeepForLater),
                  child: const Text('Keep for later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
