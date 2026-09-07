import 'dart:async';

import 'package:flutter/material.dart';

import '../models/adaptive_focus_suggestion.dart';

typedef AdaptiveFocusReviewCallback =
    FutureOr<void> Function(AdaptiveFocusSuggestion suggestion);

/// Complete reviewed copy for one Adaptive Focus presentation.
///
/// The widget deliberately performs no localization or sentence assembly.
/// A future production caller must supply complete copy from reviewed locale
/// catalogs for the exact suggestion being shown.
class AdaptiveFocusReviewCopy {
  const AdaptiveFocusReviewCopy({
    required this.eyebrow,
    required this.title,
    required this.currentPlan,
    required this.suggestedPlan,
    required this.reason,
    required this.privacyBoundary,
    required this.noAutomaticChange,
    required this.summarySemantics,
    required this.keepCurrentAction,
    required this.acceptAction,
  });

  final String eyebrow;
  final String title;
  final String currentPlan;
  final String suggestedPlan;
  final String reason;
  final String privacyBoundary;
  final String noAutomaticChange;
  final String summarySemantics;
  final String keepCurrentAction;
  final String acceptAction;
}

/// An accessible, localization-neutral review surface for one exact preview.
///
/// Both actions are one-shot. This widget never owns or changes timer state;
/// it only returns the exact immutable suggestion to the selected callback.
class AdaptiveFocusReviewCard extends StatefulWidget {
  const AdaptiveFocusReviewCard({
    required this.suggestion,
    required this.copy,
    required this.onKeepCurrent,
    required this.onAccept,
    super.key,
  });

  final AdaptiveFocusSuggestion suggestion;
  final AdaptiveFocusReviewCopy copy;
  final AdaptiveFocusReviewCallback onKeepCurrent;
  final AdaptiveFocusReviewCallback onAccept;

  @override
  State<AdaptiveFocusReviewCard> createState() =>
      _AdaptiveFocusReviewCardState();
}

class _AdaptiveFocusReviewCardState extends State<AdaptiveFocusReviewCard> {
  bool _settled = false;

  Future<void> _settle(AdaptiveFocusReviewCallback callback) async {
    if (_settled) return;
    setState(() => _settled = true);
    await callback(widget.suggestion);
  }

  @override
  void didUpdateWidget(covariant AdaptiveFocusReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestion != widget.suggestion) {
      _settled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = widget.copy;
    final actionsEnabled = !_settled;

    return Material(
      key: const ValueKey<String>('adaptive-focus-review-card'),
      color: colors.primaryContainer.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.32)),
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                key: const ValueKey<String>('adaptive-focus-review-summary'),
                container: true,
                label: copy.summarySemantics,
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.eyebrow,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      _ReviewLine(
                        key: const ValueKey<String>(
                          'adaptive-focus-current-plan',
                        ),
                        icon: Icons.timer_outlined,
                        text: copy.currentPlan,
                      ),
                      const SizedBox(height: 9),
                      _ReviewLine(
                        key: const ValueKey<String>(
                          'adaptive-focus-suggested-plan',
                        ),
                        icon: Icons.auto_awesome_outlined,
                        text: copy.suggestedPlan,
                      ),
                      const SizedBox(height: 12),
                      Text(copy.reason),
                      const SizedBox(height: 12),
                      _ReviewLine(
                        icon: Icons.lock_outline_rounded,
                        text: copy.privacyBoundary,
                        subdued: true,
                      ),
                      const SizedBox(height: 7),
                      _ReviewLine(
                        icon: Icons.touch_app_outlined,
                        text: copy.noAutomaticChange,
                        subdued: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                enabled: actionsEnabled,
                label: copy.keepCurrentAction,
                child: ExcludeSemantics(
                  child: OutlinedButton(
                    key: const ValueKey<String>('adaptive-focus-keep-current'),
                    onPressed: actionsEnabled
                        ? () => _settle(widget.onKeepCurrent)
                        : null,
                    child: Text(
                      copy.keepCurrentAction,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (widget.suggestion.changesAnything) ...[
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  enabled: actionsEnabled,
                  label: copy.acceptAction,
                  child: ExcludeSemantics(
                    child: FilledButton(
                      key: const ValueKey<String>('adaptive-focus-accept'),
                      onPressed: actionsEnabled
                          ? () => _settle(widget.onAccept)
                          : null,
                      child: Text(
                        copy.acceptAction,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.icon,
    required this.text,
    this.subdued = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: subdued
                ? Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
