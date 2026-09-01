import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/focus_session.dart';

enum _HistoryFilter { all, today, week }

class FocusHistorySheet extends StatefulWidget {
  const FocusHistorySheet({
    required this.completedSessions,
    required this.weeklyFocusSeconds,
    required this.weeklyFocusSessions,
    required this.lastSevenDaysFocusSeconds,
    required this.sessions,
    required this.onCopySummary,
    super.key,
  });

  final int completedSessions;
  final int weeklyFocusSeconds;
  final int weeklyFocusSessions;
  final List<int> lastSevenDaysFocusSeconds;
  final List<FocusSession> sessions;
  final Future<void> Function() onCopySummary;

  @override
  State<FocusHistorySheet> createState() => _FocusHistorySheetState();
}

class _FocusHistorySheetState extends State<FocusHistorySheet> {
  final ScrollController _scrollController = ScrollController();
  _HistoryFilter _filter = _HistoryFilter.all;
  bool _isCopying = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copySummary() async {
    if (_isCopying) {
      return;
    }
    setState(() => _isCopying = true);
    try {
      await widget.onCopySummary();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.focusHistoryCopyFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  List<FocusSession> get _filteredSessions {
    final now = DateTime.now().toLocal();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return widget.sessions
        .where((session) {
          final completedAt = session.completedAt.toLocal();
          return switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.today => DateUtils.isSameDay(completedAt, now),
            _HistoryFilter.week => !completedAt.isBefore(weekStart),
          };
        })
        .toList(growable: false);
  }

  String _focusSessionLabel(BuildContext context, int seconds) {
    if (seconds < 60) {
      return context.l10n.focusHistorySessionSeconds(seconds);
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return context.l10n.focusHistorySessionMinutes(minutes);
    }
    return context.l10n.focusHistorySessionMinutesSeconds(
      minutes,
      remainingSeconds,
    );
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now().toLocal();
    if (DateUtils.isSameDay(localDate, now)) {
      return context.l10n.dateToday;
    }
    if (DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      return context.l10n.dateYesterday;
    }
    return MaterialLocalizations.of(context).formatShortDate(localDate);
  }

  String _weeklyDuration(BuildContext context) {
    if (widget.weeklyFocusSeconds < 60) {
      return context.l10n.durationSeconds(widget.weeklyFocusSeconds);
    }
    final minutes = widget.weeklyFocusSeconds ~/ 60;
    return context.l10n.durationMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final dailySeconds = List<int>.generate(
      7,
      (index) => index < widget.lastSevenDaysFocusSeconds.length
          ? widget.lastSevenDaysFocusSeconds[index]
          : 0,
      growable: false,
    );
    final highestDaySeconds = dailySeconds.fold<int>(
      1,
      (highest, seconds) => seconds > highest ? seconds : highest,
    );
    final sessions = _filteredSessions;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.focusHistoryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.focusHistoryCompleted(widget.completedSessions),
                style: const TextStyle(color: Colors.white70),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isCopying ? null : _copySummary,
                  icon: _isCopying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy_outlined),
                  label: Text(context.l10n.focusHistoryCopySummary),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.focusHistoryThisWeek,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.focusHistoryWeeklySummary(
                          _weeklyDuration(context),
                          widget.weeklyFocusSessions,
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final day = DateTime.now().subtract(
                              Duration(days: 6 - index),
                            );
                            final seconds = dailySeconds[index];
                            final height = seconds == 0
                                ? 3.0
                                : 8.0 + (42 * seconds / highestDaySeconds);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      MaterialLocalizations.of(
                                        context,
                                      ).narrowWeekdays[day.weekday % 7],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final option in _HistoryFilter.values)
                      ChoiceChip(
                        label: Text(switch (option) {
                          _HistoryFilter.all => context.l10n.focusHistoryAll,
                          _HistoryFilter.today => context.l10n.dateToday,
                          _HistoryFilter.week =>
                            context.l10n.focusHistoryThisWeek,
                        }),
                        selected: _filter == option,
                        onSelected: (_) => setState(() => _filter = option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  interactive: true,
                  child: sessions.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.focusHistoryEmptyRange,
                            style: const TextStyle(color: Colors.white60),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: sessions.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Colors.white12),
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final localCompletedAt = session.completedAt
                                .toLocal();
                            final time = MaterialLocalizations.of(context)
                                .formatTimeOfDay(
                                  TimeOfDay.fromDateTime(localCompletedAt),
                                );
                            return ListTile(
                              key: ValueKey(
                                'focus-history-${session.completedAt.microsecondsSinceEpoch}-$index',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                session.focusTask ??
                                    _focusSessionLabel(
                                      context,
                                      session.durationSeconds,
                                    ),
                              ),
                              subtitle: Text(
                                context.l10n.focusHistorySessionMetadata(
                                  _focusSessionLabel(
                                    context,
                                    session.durationSeconds,
                                  ),
                                  _dateLabel(context, localCompletedAt),
                                  time,
                                ),
                                style: const TextStyle(color: Colors.white60),
                              ),
                            );
                          },
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
