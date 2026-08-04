import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/iap_service.dart';
import '../services/notification_service.dart';
import '../services/timer_service.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  static const _pink = Color(0xFFF16FBA);
  static const _lavender = Color(0xFF9B82FF);
  static const _ink = Color(0xFF211442);

  String _formattedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _chooseCustomDuration(BuildContext context, TimerService timer) async {
    const maximumMinutes = 180;
    final initialMinutes = (timer.totalSessionSeconds ~/ 60).clamp(0, maximumMinutes).toInt();
    final initialSeconds = timer.totalSessionSeconds % 60;
    var selectedMinutes = initialMinutes;
    var selectedSeconds = initialSeconds;
    final pickerController = FixedExtentScrollController(initialItem: initialMinutes);
    final secondsPickerController = FixedExtentScrollController(initialItem: initialSeconds);

    final duration = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF352260),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 20),
                Text('${timer.sessionType.label} duration', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Tap a favorite or scroll minutes and seconds.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 15, 25, 45, 60]
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes min'),
                          selected: selectedMinutes == minutes,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedMinutes = minutes;
                              selectedSeconds = 0;
                            });
                            pickerController.animateToItem(
                              minutes,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                            secondsPickerController.animateToItem(
                              0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker.builder(
                          scrollController: pickerController,
                          itemExtent: 42,
                          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                            background: _pink.withValues(alpha: 0.15),
                          ),
                          onSelectedItemChanged: (index) => setSheetState(() => selectedMinutes = index),
                          childCount: maximumMinutes + 1,
                          itemBuilder: (context, index) => Center(
                            child: Text('$index min', style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker.builder(
                          scrollController: secondsPickerController,
                          itemExtent: 42,
                          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                            background: _pink.withValues(alpha: 0.15),
                          ),
                          onSelectedItemChanged: (index) => setSheetState(() => selectedSeconds = index),
                          childCount: 60,
                          itemBuilder: (context, index) => Center(
                            child: Text('${index.toString().padLeft(2, '0')} sec', style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, Duration(minutes: selectedMinutes, seconds: selectedSeconds)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _pink,
                      foregroundColor: _ink,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text('Set ${selectedMinutes.toString().padLeft(2, '0')}:${selectedSeconds.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    pickerController.dispose();
    secondsPickerController.dispose();
    if (duration != null && duration.inSeconds > 0) {
      timer.setCustomDuration(duration.inMinutes, duration.inSeconds % 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerService>();
    final auth = context.read<AuthService>();
    final sessionColor = timer.sessionType == SessionType.focus ? _pink : _lavender;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusHaven'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test notifications',
            onPressed: () async {
              final notifications = context.read<NotificationService>();
              final granted = await notifications.requestPermissions();
              if (!context.mounted) return;
              if (!granted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enable FocusHaven notifications in macOS System Settings.'),
                  ),
                );
                return;
              }
              await notifications.showTestNotification();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Sign in with Google',
            onPressed: auth.signInWithGoogle,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: SessionType.values
                            .map(
                              (type) => ChoiceChip(
                                label: Text(type.label),
                                selected: timer.sessionType == type,
                                onSelected: (_) => timer.selectSession(type),
                                selectedColor: sessionColor.withValues(alpha: 0.32),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        timer.isComplete ? 'SESSION COMPLETE' : timer.sessionType.label.toUpperCase(),
                        style: TextStyle(color: sessionColor, fontWeight: FontWeight.bold, letterSpacing: 1.8),
                      ),
                      const SizedBox(height: 10),
                      Text(timer.sessionType.encouragement, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 270,
                        height: 270,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 270,
                              height: 270,
                              child: CircularProgressIndicator(
                                value: timer.progress.clamp(0, 1),
                                strokeWidth: 11,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withValues(alpha: 0.10),
                                color: sessionColor,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_formattedTime(timer.secondsRemaining), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w700, height: 1)),
                                const SizedBox(height: 10),
                                Text('${timer.totalSessionSeconds ~/ 60} MINUTES', style: const TextStyle(color: Colors.white60, letterSpacing: 1.2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (timer.isComplete)
                        FilledButton.icon(
                          onPressed: timer.beginNextSession,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(timer.sessionType == SessionType.focus ? 'Take a break' : 'Begin focus'),
                          style: FilledButton.styleFrom(backgroundColor: sessionColor, foregroundColor: _ink, minimumSize: const Size(210, 54)),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.outlined(
                              onPressed: timer.reset,
                              tooltip: 'Reset timer',
                              icon: const Icon(Icons.replay),
                            ),
                            const SizedBox(width: 18),
                            FilledButton.icon(
                              onPressed: timer.isRunning ? timer.pause : timer.start,
                              icon: Icon(timer.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              label: Text(
                                timer.isRunning
                                    ? 'Pause'
                                    : 'Begin ${timer.sessionType.label.toLowerCase()}',
                              ),
                              style: FilledButton.styleFrom(backgroundColor: sessionColor, foregroundColor: _ink, minimumSize: const Size(172, 54)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () => _chooseCustomDuration(context, timer),
                        icon: const Icon(Icons.tune),
                        label: const Text('Custom duration'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.today_outlined,
                                value: '${timer.todayFocusMinutes}m',
                                label: 'today',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.local_fire_department_outlined,
                                value: '${timer.currentStreak}',
                                label: 'day streak',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.check_circle_outline,
                                value: '${timer.completedFocusSessions}',
                                label: 'completed',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Recent focus', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const SizedBox(height: 8),
                        if (timer.recentFocusSessions.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Complete a focus session to begin your history.', style: TextStyle(color: Colors.white60)),
                          )
                        else
                          ...timer.recentFocusSessions.take(3).map(
                                (session) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0x33F16FBA),
                                    child: Icon(Icons.auto_awesome, color: _pink),
                                  ),
                                  title: Text('${session.durationSeconds ~/ 60}-minute focus session'),
                                  trailing: Text(_dateLabel(session.completedAt), style: const TextStyle(color: Colors.white60)),
                                ),
                              ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () async {
                            final isPro = await IAPService.isProUser();
                            if (!context.mounted) return;
                            if (isPro) {
                              await context.read<CloudSyncService>().syncTimerSettings(timer.secondsRemaining);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isPro ? 'Timer settings synced' : 'Upgrade to Pro to sync across devices')),
                              );
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Sync settings'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 18, color: TimerScreen._pink),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
