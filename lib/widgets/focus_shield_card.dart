import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/focus_shield_state.dart';

/// A compact, honest view of the current Focus Shield state.
///
/// The card cannot change the timer or invoke a platform API by itself. It
/// exposes only the actions admitted by [FocusShieldState], and a host must
/// explicitly provide [onAction] before any control is shown.
class FocusShieldCard extends StatefulWidget {
  const FocusShieldCard({super.key, required this.state, this.onAction});

  final FocusShieldState state;
  final ValueChanged<FocusShieldAction>? onAction;

  @override
  State<FocusShieldCard> createState() => _FocusShieldCardState();
}

class _FocusShieldCardState extends State<FocusShieldCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final colors = Theme.of(context).colorScheme;
    final accent = _accentColor(state, colors);
    final borderRadius = BorderRadius.circular(18);
    final actions = _orderedActions(state.availableActions);

    return Material(
      key: const ValueKey('focus-shield-card'),
      color: accent.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: accent.withValues(alpha: 0.26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('toggle-focus-shield'),
            borderRadius: borderRadius,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                      child: Icon(_phaseIcon(state.phase), color: accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.focusShieldEyebrow(
                            _phaseLabel(state.phase).toUpperCase(),
                          ),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.75,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.headline,
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
          if (_isExpanded) ...[
            Divider(height: 1, color: accent.withValues(alpha: 0.20)),
            Padding(
              key: const ValueKey('focus-shield-details'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    state.detail,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 13),
                  _BoundaryNote(
                    icon: Icons.timer_outlined,
                    text: l10n.focusShieldRunningOnlyBoundary,
                    accent: accent,
                  ),
                  const SizedBox(height: 9),
                  _BoundaryNote(
                    icon: Icons.lock_outline_rounded,
                    text: l10n.focusShieldPrivateSelectionBoundary,
                    accent: accent,
                  ),
                  if (actions.isNotEmpty && widget.onAction != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in actions)
                          action == actions.first
                              ? FilledButton.icon(
                                  key: ValueKey(
                                    'focus-shield-action-${action.name}',
                                  ),
                                  onPressed: () => widget.onAction!(action),
                                  icon: Icon(_actionIcon(action), size: 18),
                                  label: Text(_actionLabel(action)),
                                )
                              : OutlinedButton.icon(
                                  key: ValueKey(
                                    'focus-shield-action-${action.name}',
                                  ),
                                  onPressed: () => widget.onAction!(action),
                                  icon: Icon(_actionIcon(action), size: 18),
                                  label: Text(_actionLabel(action)),
                                ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _accentColor(FocusShieldState state, ColorScheme colors) =>
      switch (state.phase) {
        FocusShieldPhase.protecting => colors.tertiary,
        FocusShieldPhase.needsAttention => colors.error,
        FocusShieldPhase.unsupported => colors.onSurfaceVariant,
        FocusShieldPhase.paused => colors.secondary,
        _ => colors.primary,
      };

  String _phaseLabel(FocusShieldPhase phase) => switch (phase) {
    FocusShieldPhase.off => context.l10n.focusShieldPhaseOff,
    FocusShieldPhase.unsupported => context.l10n.focusShieldPhaseUnavailable,
    FocusShieldPhase.needsAuthorization =>
      context.l10n.focusShieldPhasePermissionNeeded,
    FocusShieldPhase.needsSelection => context.l10n.focusShieldPhaseSetupNeeded,
    FocusShieldPhase.ready => context.l10n.focusShieldPhaseReady,
    FocusShieldPhase.starting => context.l10n.focusShieldPhaseConfirming,
    FocusShieldPhase.protecting => context.l10n.focusShieldPhaseProtected,
    FocusShieldPhase.paused => context.l10n.focusShieldPhasePaused,
    FocusShieldPhase.needsAttention =>
      context.l10n.focusShieldPhaseNeedsAttention,
  };

  static IconData _phaseIcon(FocusShieldPhase phase) => switch (phase) {
    FocusShieldPhase.protecting => Icons.shield_rounded,
    FocusShieldPhase.starting => Icons.shield_outlined,
    FocusShieldPhase.paused => Icons.pause_circle_outline_rounded,
    FocusShieldPhase.needsAttention => Icons.error_outline_rounded,
    FocusShieldPhase.needsAuthorization => Icons.verified_user_outlined,
    FocusShieldPhase.needsSelection => Icons.app_blocking_outlined,
    FocusShieldPhase.unsupported => Icons.phonelink_erase_outlined,
    FocusShieldPhase.off || FocusShieldPhase.ready => Icons.shield_outlined,
  };

  static List<FocusShieldAction> _orderedActions(
    Set<FocusShieldAction> actions,
  ) {
    const order = [
      FocusShieldAction.enable,
      FocusShieldAction.requestAuthorization,
      FocusShieldAction.chooseDistractions,
      FocusShieldAction.resumeProtection,
      FocusShieldAction.retryProtection,
      FocusShieldAction.pauseProtection,
      FocusShieldAction.disable,
    ];
    return [
      for (final action in order)
        if (actions.contains(action)) action,
    ];
  }

  String _actionLabel(FocusShieldAction action) => switch (action) {
    FocusShieldAction.enable => context.l10n.focusShieldActionEnable,
    FocusShieldAction.disable => context.l10n.focusShieldActionDisable,
    FocusShieldAction.requestAuthorization =>
      context.l10n.focusShieldActionReviewPermission,
    FocusShieldAction.chooseDistractions =>
      context.l10n.focusShieldActionChooseDistractions,
    FocusShieldAction.pauseProtection =>
      context.l10n.focusShieldActionPauseProtection,
    FocusShieldAction.resumeProtection =>
      context.l10n.focusShieldActionResumeProtection,
    FocusShieldAction.retryProtection =>
      context.l10n.focusShieldActionRetryProtection,
  };

  static IconData _actionIcon(FocusShieldAction action) => switch (action) {
    FocusShieldAction.enable => Icons.shield_outlined,
    FocusShieldAction.disable => Icons.power_settings_new_rounded,
    FocusShieldAction.requestAuthorization => Icons.verified_user_outlined,
    FocusShieldAction.chooseDistractions => Icons.tune_rounded,
    FocusShieldAction.pauseProtection => Icons.pause_rounded,
    FocusShieldAction.resumeProtection => Icons.play_arrow_rounded,
    FocusShieldAction.retryProtection => Icons.refresh_rounded,
  };
}

class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote({
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
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}
