import 'package:flutter/material.dart';

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
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  List<FocusSession> get _filteredSessions {
    final now = DateTime.now();
    return widget.sessions
        .where((session) {
          return switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.today => DateUtils.isSameDay(
              session.completedAt,
              now,
            ),
            _HistoryFilter.week => !session.completedAt.isBefore(
              now.subtract(const Duration(days: 6)),
            ),
          };
        })
        .toList(growable: false);
  }

  String _focusSessionLabel(int seconds) {
    if (seconds < 60) {
      return '$seconds-second focus session';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes-minute focus session';
    }
    return '$minutes min $remainingSeconds sec focus session';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String get _weeklyDuration {
    if (widget.weeklyFocusSeconds < 60) {
      final seconds = widget.weeklyFocusSeconds;
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    }
    final minutes = widget.weeklyFocusSeconds ~/ 60;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
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
                'All focus sessions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.completedSessions} completed sessions',
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
                  label: const Text('Copy full summary'),
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
                        'This week',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_weeklyDuration • ${widget.weeklyFocusSessions} '
                        '${widget.weeklyFocusSessions == 1 ? 'session' : 'sessions'}',
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
                                      const [
                                        'M',
                                        'T',
                                        'W',
                                        'T',
                                        'F',
                                        'S',
                                        'S',
                                      ][day.weekday - 1],
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
                          _HistoryFilter.all => 'All',
                          _HistoryFilter.today => 'Today',
                          _HistoryFilter.week => 'This week',
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
                      ? const Center(
                          child: Text(
                            'No focus sessions in this time range yet.',
                            style: TextStyle(color: Colors.white60),
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
                            final time = MaterialLocalizations.of(context)
                                .formatTimeOfDay(
                                  TimeOfDay.fromDateTime(session.completedAt),
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
                                    _focusSessionLabel(session.durationSeconds),
                              ),
                              subtitle: Text(
                                '${_focusSessionLabel(session.durationSeconds)} '
                                '• ${_dateLabel(session.completedAt)} at $time',
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
