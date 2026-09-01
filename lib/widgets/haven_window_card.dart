import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/haven_window_suggestion.dart';

/// A compact consent surface for one private Haven Window suggestion.
///
/// The card cannot start a platform bridge, request permission, refresh
/// availability, create an event, or control the timer by itself. A reviewed
/// native host must first start the bridge and provide the one action admitted
/// by the current authorization state.
class HavenWindowCard extends StatefulWidget {
  const HavenWindowCard({
    super.key,
    required this.suggestion,
    required this.availabilityStatus,
    required this.isPlatformStarted,
    this.isHeld = false,
    this.hasArrived = false,
    this.heldStartsAtUtc,
    this.heldEndsAtUtc,
    this.isHoldUpdating = false,
    this.onRequestReadOnlyAccess,
    this.onRefreshAvailability,
    this.onHoldWindow,
    this.onReleaseHold,
    this.onBeginFocus,
  }) : assert(!hasArrived || isHeld);

  final HavenWindowSuggestion suggestion;
  final PrivateCalendarAvailabilityStatus availabilityStatus;
  final bool isPlatformStarted;
  final bool isHeld;
  final bool hasArrived;
  final DateTime? heldStartsAtUtc;
  final DateTime? heldEndsAtUtc;
  final bool isHoldUpdating;
  final Future<bool> Function()? onRequestReadOnlyAccess;
  final Future<bool> Function()? onRefreshAvailability;
  final Future<bool> Function()? onHoldWindow;
  final Future<bool> Function()? onReleaseHold;
  final Future<bool> Function()? onBeginFocus;

  @override
  State<HavenWindowCard> createState() => _HavenWindowCardState();
}

class _HavenWindowCardState extends State<HavenWindowCard> {
  bool _isExpanded = false;
  bool _isWorking = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  Future<void> _perform(Future<bool> Function() action) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await action();
    } catch (_) {
      // The platform controller remains the source of the honest status.
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final accent = _accentColor(colors);
    final borderRadius = BorderRadius.circular(18);
    final headline = widget.hasArrived
        ? l10n.havenWindowHeadlineArrived
        : widget.isHeld
        ? l10n.havenWindowHeadlineHeld
        : widget.isPlatformStarted
        ? widget.suggestion.headline
        : l10n.havenWindowHeadlineOff;
    final actions = _availableActions();
    final isBusy = _isWorking || widget.isHoldUpdating;

    return Material(
      key: const ValueKey('haven-window-card'),
      color: accent.withValues(alpha: 0.09),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            onTap: _toggle,
            label: l10n.havenWindowSemantics(
              _statusLabel(),
              headline,
              _isExpanded
                  ? l10n.havenWindowHideDetails
                  : l10n.havenWindowShowDetails,
            ),
            child: ExcludeSemantics(
              child: InkWell(
                key: const ValueKey('toggle-haven-window'),
                borderRadius: borderRadius,
                onTap: _toggle,
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
                          child: Icon(_statusIcon(), color: accent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.havenWindowEyebrow(
                                _statusLabel().toUpperCase(),
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
                              headline,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: accent.withValues(alpha: 0.20)),
            Padding(
              key: const ValueKey('haven-window-details'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.hasArrived
                        ? l10n.havenWindowArrivedDetail
                        : widget.isHeld
                        ? l10n.havenWindowHeldDetail
                        : widget.isPlatformStarted
                        ? widget.suggestion.detail
                        : l10n.havenWindowDormantDetail,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: _WindowNote(
                        icon: Icons.schedule_outlined,
                        text: widget.isHeld
                            ? _heldWindowLabel(context)
                            : widget.isPlatformStarted
                            ? widget.suggestion.evidence
                            : l10n.havenWindowNoAvailabilityRead,
                        accent: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _WindowNote(
                    icon: Icons.visibility_off_outlined,
                    text: l10n.havenWindowPrivateBoundary,
                    accent: accent,
                  ),
                  const SizedBox(height: 9),
                  _WindowNote(
                    icon: Icons.event_busy_outlined,
                    text: l10n.havenWindowNoCalendarWriteBoundary,
                    accent: accent,
                  ),
                  if (widget.isHeld || widget.suggestion.hasOpening) ...[
                    const SizedBox(height: 9),
                    _WindowNote(
                      icon: widget.hasArrived
                          ? Icons.self_improvement_outlined
                          : widget.isHeld
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      text: widget.hasArrived
                          ? l10n.havenWindowArrivedHoldBoundary
                          : widget.isHeld
                          ? l10n.havenWindowHeldNotificationBoundary
                          : l10n.havenWindowAvailableHoldBoundary,
                      accent: accent,
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...actions.map(
                      (action) => Padding(
                        padding: EdgeInsets.only(
                          top: identical(action, actions.first) ? 0 : 9,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: action.isPrimary
                              ? FilledButton.icon(
                                  key: ValueKey(action.key),
                                  onPressed: isBusy
                                      ? null
                                      : () => _perform(action.callback),
                                  icon: _ActionIcon(
                                    icon: action.icon,
                                    isWorking: isBusy,
                                  ),
                                  label: Text(action.label),
                                )
                              : OutlinedButton.icon(
                                  key: ValueKey(action.key),
                                  onPressed: isBusy
                                      ? null
                                      : () => _perform(action.callback),
                                  icon: _ActionIcon(
                                    icon: action.icon,
                                    isWorking: isBusy,
                                  ),
                                  label: Text(action.label),
                                ),
                        ),
                      ),
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

  List<_WindowAction> _availableActions() {
    final l10n = context.l10n;
    if (widget.isHeld) {
      final release = widget.onReleaseHold;
      if (widget.hasArrived) {
        final begin = widget.onBeginFocus;
        return [
          if (begin != null)
            _WindowAction(
              key: 'haven-window-begin-focus',
              label: l10n.havenWindowActionBeginFocus,
              icon: Icons.play_arrow_rounded,
              isPrimary: true,
              callback: begin,
            ),
          if (release != null)
            _WindowAction(
              key: 'haven-window-let-pass',
              label: l10n.havenWindowActionLetPass,
              icon: Icons.close_rounded,
              isPrimary: false,
              callback: release,
            ),
        ];
      }
      return release == null
          ? const []
          : [
              _WindowAction(
                key: 'haven-window-release-hold',
                label: l10n.havenWindowActionReleaseHold,
                icon: Icons.notifications_off_outlined,
                isPrimary: false,
                callback: release,
              ),
            ];
    }
    if (!widget.isPlatformStarted) return const [];
    final availabilityAction = switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.disconnected =>
        widget.onRequestReadOnlyAccess == null
            ? null
            : _WindowAction(
                key: 'haven-window-request-access',
                label: l10n.havenWindowActionReviewCalendarAccess,
                icon: Icons.event_available_outlined,
                isPrimary: true,
                callback: widget.onRequestReadOnlyAccess!,
              ),
      PrivateCalendarAvailabilityStatus.denied =>
        widget.onRefreshAvailability == null
            ? null
            : _WindowAction(
                key: 'haven-window-refresh-access',
                label: l10n.havenWindowActionRecheckAccess,
                icon: Icons.refresh_rounded,
                isPrimary: false,
                callback: widget.onRefreshAvailability!,
              ),
      PrivateCalendarAvailabilityStatus.ready =>
        widget.onRefreshAvailability == null
            ? null
            : _WindowAction(
                key: 'haven-window-refresh-availability',
                label: l10n.havenWindowActionRefreshAvailability,
                icon: Icons.refresh_rounded,
                isPrimary: false,
                callback: widget.onRefreshAvailability!,
              ),
      PrivateCalendarAvailabilityStatus.unsupported => null,
    };
    final holdAction =
        widget.availabilityStatus == PrivateCalendarAvailabilityStatus.ready &&
            widget.suggestion.hasOpening &&
            widget.onHoldWindow != null
        ? _WindowAction(
            key: 'haven-window-hold',
            label: l10n.havenWindowActionHold,
            icon: Icons.notifications_active_outlined,
            isPrimary: true,
            callback: widget.onHoldWindow!,
          )
        : null;
    return [?holdAction, ?availabilityAction];
  }

  String _statusLabel() {
    final l10n = context.l10n;
    if (widget.hasArrived) return l10n.havenWindowStatusArrived;
    if (widget.isHeld) return l10n.havenWindowStatusHeld;
    if (!widget.isPlatformStarted) return l10n.havenWindowStatusOff;
    return switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.unsupported =>
        l10n.havenWindowStatusUnavailable,
      PrivateCalendarAvailabilityStatus.disconnected =>
        l10n.havenWindowStatusNotConnected,
      PrivateCalendarAvailabilityStatus.denied =>
        l10n.havenWindowStatusAccessOff,
      PrivateCalendarAvailabilityStatus.ready =>
        switch (widget.suggestion.kind) {
          HavenWindowKind.learning => l10n.havenWindowStatusLearning,
          HavenWindowKind.opening => l10n.havenWindowStatusPossibleOpening,
          HavenWindowKind.noOpening => l10n.havenWindowStatusNoOpening,
          HavenWindowKind.unavailable => l10n.havenWindowStatusUnavailable,
        },
    };
  }

  Color _accentColor(ColorScheme colors) {
    if (widget.isHeld) return colors.primary;
    if (!widget.isPlatformStarted) return colors.onSurfaceVariant;
    return switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.unsupported => colors.onSurfaceVariant,
      PrivateCalendarAvailabilityStatus.disconnected => colors.secondary,
      PrivateCalendarAvailabilityStatus.denied => colors.onSurfaceVariant,
      PrivateCalendarAvailabilityStatus.ready =>
        switch (widget.suggestion.kind) {
          HavenWindowKind.opening => colors.primary,
          HavenWindowKind.learning => colors.secondary,
          HavenWindowKind.noOpening => colors.tertiary,
          HavenWindowKind.unavailable => colors.onSurfaceVariant,
        },
    };
  }

  IconData _statusIcon() {
    if (widget.hasArrived) return Icons.self_improvement_outlined;
    if (widget.isHeld) return Icons.notifications_active_outlined;
    if (!widget.isPlatformStarted) return Icons.calendar_month_outlined;
    return switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.unsupported =>
        Icons.event_busy_outlined,
      PrivateCalendarAvailabilityStatus.disconnected => Icons.link_off_rounded,
      PrivateCalendarAvailabilityStatus.denied => Icons.lock_outline_rounded,
      PrivateCalendarAvailabilityStatus.ready =>
        widget.suggestion.hasOpening
            ? Icons.event_available_outlined
            : Icons.calendar_month_outlined,
    };
  }

  String _heldWindowLabel(BuildContext context) {
    final startsAt = widget.heldStartsAtUtc?.toLocal();
    final endsAt = widget.heldEndsAtUtc?.toLocal();
    if (startsAt == null || endsAt == null || !startsAt.isBefore(endsAt)) {
      return context.l10n.havenWindowHeldFallback;
    }
    final localizations = MaterialLocalizations.of(context);
    final startDate = localizations.formatShortDate(startsAt);
    final startTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(startsAt),
    );
    final endTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(endsAt),
    );
    final isSameDay =
        startsAt.year == endsAt.year &&
        startsAt.month == endsAt.month &&
        startsAt.day == endsAt.day;
    if (isSameDay) {
      return context.l10n.havenWindowHeldSameDay(startDate, startTime, endTime);
    }
    return context.l10n.havenWindowHeldMultiDay(
      startDate,
      startTime,
      localizations.formatShortDate(endsAt),
      endTime,
    );
  }
}

class _WindowAction {
  const _WindowAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.callback,
  });

  final String key;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final Future<bool> Function() callback;
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.isWorking});

  final IconData icon;
  final bool isWorking;

  @override
  Widget build(BuildContext context) => isWorking
      ? const SizedBox.square(
          dimension: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon, size: 18);
}

class _WindowNote extends StatelessWidget {
  const _WindowNote({
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
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}
