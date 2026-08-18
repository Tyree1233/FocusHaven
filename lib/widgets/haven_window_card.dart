import 'package:flutter/material.dart';

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
    this.onRequestReadOnlyAccess,
    this.onRefreshAvailability,
  });

  final HavenWindowSuggestion suggestion;
  final PrivateCalendarAvailabilityStatus availabilityStatus;
  final bool isPlatformStarted;
  final Future<bool> Function()? onRequestReadOnlyAccess;
  final Future<bool> Function()? onRefreshAvailability;

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
    final colors = Theme.of(context).colorScheme;
    final accent = _accentColor(colors);
    final borderRadius = BorderRadius.circular(18);
    final headline = widget.isPlatformStarted
        ? widget.suggestion.headline
        : 'Calendar assistance stays off';
    final action = _availableAction();

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
            label:
                'Haven Window. ${_statusLabel()}. $headline. '
                '${_isExpanded ? 'Hide details.' : 'Show details.'}',
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
                              'HAVEN WINDOW · ${_statusLabel().toUpperCase()}',
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
                    widget.isPlatformStarted
                        ? widget.suggestion.detail
                        : 'FocusHaven has not checked or requested calendar access. A supported native connection must be available before any permission control appears.',
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
                        text: widget.isPlatformStarted
                            ? widget.suggestion.evidence
                            : 'No calendar availability was read.',
                        accent: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _WindowNote(
                    icon: Icons.visibility_off_outlined,
                    text:
                        'Only short-range busy and free boundaries can enter FocusHaven. Event titles, calendars, people, locations, notes, and accounts stay outside.',
                    accent: accent,
                  ),
                  const SizedBox(height: 9),
                  _WindowNote(
                    icon: Icons.event_busy_outlined,
                    text:
                        'FocusHaven never creates or changes calendar events. A possible opening remains optional and never starts the timer.',
                    accent: accent,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: action.isPrimary
                          ? FilledButton.icon(
                              key: ValueKey(action.key),
                              onPressed: _isWorking
                                  ? null
                                  : () => _perform(action.callback),
                              icon: _ActionIcon(
                                icon: action.icon,
                                isWorking: _isWorking,
                              ),
                              label: Text(action.label),
                            )
                          : OutlinedButton.icon(
                              key: ValueKey(action.key),
                              onPressed: _isWorking
                                  ? null
                                  : () => _perform(action.callback),
                              icon: _ActionIcon(
                                icon: action.icon,
                                isWorking: _isWorking,
                              ),
                              label: Text(action.label),
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

  _WindowAction? _availableAction() {
    if (!widget.isPlatformStarted) return null;
    return switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.disconnected =>
        widget.onRequestReadOnlyAccess == null
            ? null
            : _WindowAction(
                key: 'haven-window-request-access',
                label: 'Review calendar access',
                icon: Icons.event_available_outlined,
                isPrimary: true,
                callback: widget.onRequestReadOnlyAccess!,
              ),
      PrivateCalendarAvailabilityStatus.denied =>
        widget.onRefreshAvailability == null
            ? null
            : _WindowAction(
                key: 'haven-window-refresh-access',
                label: 'Recheck access',
                icon: Icons.refresh_rounded,
                isPrimary: false,
                callback: widget.onRefreshAvailability!,
              ),
      PrivateCalendarAvailabilityStatus.ready =>
        widget.onRefreshAvailability == null
            ? null
            : _WindowAction(
                key: 'haven-window-refresh-availability',
                label: 'Refresh private availability',
                icon: Icons.refresh_rounded,
                isPrimary: false,
                callback: widget.onRefreshAvailability!,
              ),
      PrivateCalendarAvailabilityStatus.unsupported => null,
    };
  }

  String _statusLabel() {
    if (!widget.isPlatformStarted) return 'Off';
    return switch (widget.availabilityStatus) {
      PrivateCalendarAvailabilityStatus.unsupported => 'Unavailable',
      PrivateCalendarAvailabilityStatus.disconnected => 'Not connected',
      PrivateCalendarAvailabilityStatus.denied => 'Access off',
      PrivateCalendarAvailabilityStatus.ready =>
        switch (widget.suggestion.kind) {
          HavenWindowKind.learning => 'Still learning',
          HavenWindowKind.opening => 'Possible opening',
          HavenWindowKind.noOpening => 'No opening',
          HavenWindowKind.unavailable => 'Unavailable',
        },
    };
  }

  Color _accentColor(ColorScheme colors) {
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
