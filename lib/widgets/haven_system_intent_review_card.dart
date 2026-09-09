import 'dart:async';

import 'package:flutter/material.dart';

import '../services/haven_system_intent_review_service.dart';

typedef HavenSystemIntentReviewCallback =
    FutureOr<void> Function(HavenSystemIntentReview review);

/// Complete reviewed copy for one system-assistant review presentation.
///
/// The widget deliberately performs no localization, interpolation, or
/// sentence assembly. A later production adapter must supply complete copy
/// from reviewed locale catalogs for the exact review being shown.
final class HavenSystemIntentReviewCopy {
  const HavenSystemIntentReviewCopy({
    required this.eyebrow,
    required this.title,
    required this.sourceBoundary,
    required this.privacyBoundary,
    required this.freshnessBoundary,
    required this.confirmationBoundary,
    required this.riskLabel,
    required this.summarySemantics,
    required this.dismissAction,
    required this.confirmAction,
  });

  final String eyebrow;
  final String title;
  final String sourceBoundary;
  final String privacyBoundary;
  final String freshnessBoundary;
  final String confirmationBoundary;
  final String riskLabel;
  final String summarySemantics;
  final String dismissAction;
  final String confirmAction;
}

/// Accessible, localization-neutral presentation for one opaque review.
///
/// Both choices are one-shot. This widget cannot prepare, inspect, confirm, or
/// execute the private proposal; it can only return the exact opaque review to
/// one callback selected by the person.
final class HavenSystemIntentReviewCard extends StatefulWidget {
  const HavenSystemIntentReviewCard({
    required this.review,
    required this.copy,
    required this.onDismiss,
    required this.onConfirm,
    super.key,
  });

  final HavenSystemIntentReview review;
  final HavenSystemIntentReviewCopy copy;
  final HavenSystemIntentReviewCallback onDismiss;
  final HavenSystemIntentReviewCallback onConfirm;

  @override
  State<HavenSystemIntentReviewCard> createState() =>
      _HavenSystemIntentReviewCardState();
}

final class _HavenSystemIntentReviewCardState
    extends State<HavenSystemIntentReviewCard> {
  bool _settled = false;

  Future<void> _settle(HavenSystemIntentReviewCallback callback) async {
    if (_settled) return;
    setState(() => _settled = true);
    await callback(widget.review);
  }

  @override
  void didUpdateWidget(covariant HavenSystemIntentReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.review, widget.review)) {
      _settled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final copy = widget.copy;
    final review = widget.review;
    final actionsEnabled = !_settled;

    return Material(
      key: const ValueKey<String>('system-intent-review-card'),
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
                key: const ValueKey<String>('system-intent-review-summary'),
                container: true,
                liveRegion: true,
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
                          'system-intent-interpretation',
                        ),
                        icon: Icons.fact_check_outlined,
                        text: review.interpretation,
                      ),
                      const SizedBox(height: 9),
                      _ReviewLine(
                        key: const ValueKey<String>('system-intent-effect'),
                        icon: Icons.arrow_forward_rounded,
                        text: review.effect,
                      ),
                      const SizedBox(height: 12),
                      _ReviewLine(
                        icon: Icons.assistant_outlined,
                        text: copy.sourceBoundary,
                        subdued: true,
                      ),
                      const SizedBox(height: 7),
                      _ReviewLine(
                        icon: Icons.lock_outline_rounded,
                        text: copy.privacyBoundary,
                        subdued: true,
                      ),
                      const SizedBox(height: 7),
                      _ReviewLine(
                        icon: Icons.schedule_outlined,
                        text: copy.freshnessBoundary,
                        subdued: true,
                      ),
                      const SizedBox(height: 7),
                      _ReviewLine(
                        icon: Icons.touch_app_outlined,
                        text: copy.confirmationBoundary,
                        subdued: true,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        copy.riskLabel,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                enabled: actionsEnabled,
                label: copy.dismissAction,
                child: ExcludeSemantics(
                  child: OutlinedButton(
                    key: const ValueKey<String>('system-intent-dismiss-review'),
                    onPressed: actionsEnabled
                        ? () => _settle(widget.onDismiss)
                        : null,
                    child: Text(
                      copy.dismissAction,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                enabled: actionsEnabled,
                label: copy.confirmAction,
                child: ExcludeSemantics(
                  child: FilledButton(
                    key: const ValueKey<String>('system-intent-confirm-review'),
                    onPressed: actionsEnabled
                        ? () => _settle(widget.onConfirm)
                        : null,
                    child: Text(
                      copy.confirmAction,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReviewLine extends StatelessWidget {
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
