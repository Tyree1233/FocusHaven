import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/focus_session.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/focus_profile_service.dart';
import '../services/focus_queue_service.dart';
import '../services/iap_service.dart';
import '../services/journal_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/theme_service.dart';
import '../services/timer_service.dart';
import '../widgets/guided_breathing_sheet.dart';

enum _HistoryFilter { all, today, week }

class TimerScreen extends riverpod.ConsumerWidget {
  const TimerScreen({super.key});

  static const _ink = Color(0xFF211442);

  Color _sessionColor(BuildContext context, SessionType type) => switch (type) {
    SessionType.focus => Theme.of(context).colorScheme.primary,
    SessionType.shortBreak => Theme.of(context).colorScheme.secondary,
    SessionType.longBreak => Theme.of(context).colorScheme.tertiary,
  };

  String _formattedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  Future<void> _copyFocusHistory(
    BuildContext context,
    TimerService timer,
  ) async {
    await Clipboard.setData(ClipboardData(text: timer.focusHistoryExport));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Focus summary copied. Paste it into Notes, email, or a document.',
        ),
      ),
    );
  }

  String _durationLabel(int seconds) {
    if (seconds < 60) {
      return '$seconds ${seconds == 1 ? 'SECOND' : 'SECONDS'}';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes ${minutes == 1 ? 'MINUTE' : 'MINUTES'}';
    }
    return '$minutes ${minutes == 1 ? 'MINUTE' : 'MINUTES'} $remainingSeconds SEC';
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

  String _shortDurationLabel(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds == 0
        ? '$minutes min'
        : '$minutes min $remainingSeconds sec';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
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

  Future<void> _chooseCustomDuration(
    BuildContext context,
    TimerService timer,
  ) async {
    const maximumMinutes = 180;
    final sessionColor = _sessionColor(context, timer.sessionType);
    final initialMinutes = (timer.totalSessionSeconds ~/ 60)
        .clamp(0, maximumMinutes)
        .toInt();
    final initialSeconds = timer.totalSessionSeconds % 60;
    var selectedMinutes = initialMinutes;
    var selectedSeconds = initialSeconds;
    final pickerController = FixedExtentScrollController(
      initialItem: initialMinutes,
    );
    final secondsPickerController = FixedExtentScrollController(
      initialItem: initialSeconds,
    );

    final duration = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${timer.sessionType.label} duration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap a favorite or scroll minutes and seconds.',
                  style: TextStyle(color: Colors.white70),
                ),
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
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                                background: sessionColor.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                          onSelectedItemChanged: (index) =>
                              setSheetState(() => selectedMinutes = index),
                          childCount: maximumMinutes + 1,
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              '$index min',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker.builder(
                          scrollController: secondsPickerController,
                          itemExtent: 42,
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                                background: sessionColor.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                          onSelectedItemChanged: (index) =>
                              setSheetState(() => selectedSeconds = index),
                          childCount: 60,
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              '${index.toString().padLeft(2, '0')} sec',
                              style: const TextStyle(fontSize: 22),
                            ),
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
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      Duration(
                        minutes: selectedMinutes,
                        seconds: selectedSeconds,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: sessionColor,
                      foregroundColor: _ink,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text(
                      'Set ${selectedMinutes.toString().padLeft(2, '0')}:${selectedSeconds.toString().padLeft(2, '0')}',
                    ),
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

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const policyUrl =
        'https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html';
    final opened = await launchUrl(
      Uri.parse(policyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the privacy policy right now.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteCloudBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete cloud backup?'),
        content: const Text(
          'This permanently deletes the FocusHaven backup stored in your account. Your data on this device will stay here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep backup'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await context.read<CloudSyncService>().deleteFocusData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Cloud backup deleted. Your local focus data remains on this device.'
              : 'Unable to delete the cloud backup right now.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocalData(BuildContext context) async {
    final timer = context.read<TimerService>();
    final journal = context.read<JournalService>();
    final focusQueue = context.read<FocusQueueService>();
    final profile = context.read<FocusProfileService>();
    final themes = context.read<ThemeService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete local data?'),
        content: const Text(
          'This permanently removes your timer history, journal entries, tasks, parked thoughts, goals, profile, and appearance choices from this device. Your cloud backup will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete local data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      timer.clearLocalData(),
      journal.clearLocalData(),
      focusQueue.clearLocalData(),
      profile.clearLocalData(),
      themes.clearLocalData(),
      preferences.remove('hasCompletedOnboarding'),
    ]);
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _showReminderSheet(BuildContext context) async {
    final selectedWeekdays = context.read<ReminderService>().weekdays.toSet();
    const weekdayLabels = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<ReminderService>(
                builder: (context, reminders, _) {
                  final scheduledDays = weekdayLabels.entries
                      .where((entry) => reminders.weekdays.contains(entry.key))
                      .map((entry) => entry.value)
                      .join(', ');
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Scheduled focus time',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose the days and time for a gentle invitation to focus. You can change or turn it off at any time.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          reminders.isEnabled
                              ? Icons.event_available_outlined
                              : Icons.event_busy_outlined,
                        ),
                        title: Text(
                          reminders.isEnabled
                              ? 'Focus time is scheduled'
                              : 'No focus time scheduled',
                        ),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatTimeOfDay(reminders.time)}${reminders.isEnabled ? ' • $scheduledDays' : ''}',
                        ),
                        trailing: Switch(
                          value: reminders.isEnabled,
                          onChanged: (enabled) async {
                            if (enabled) {
                              final selected = await showTimePicker(
                                context: sheetContext,
                                initialTime: reminders.time,
                              );
                              if (selected == null || !sheetContext.mounted) {
                                return;
                              }
                              final scheduled = await reminders
                                  .setDailyReminder(
                                    selected,
                                    weekdays: selectedWeekdays,
                                  );
                              if (!sheetContext.mounted || scheduled) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Allow notifications to schedule a focus time.',
                                  ),
                                ),
                              );
                            } else {
                              await reminders.disableDailyReminder();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Repeat on',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: weekdayLabels.entries
                            .map(
                              (entry) => FilterChip(
                                label: Text(entry.value),
                                selected: selectedWeekdays.contains(entry.key),
                                onSelected: (selected) {
                                  if (!selected &&
                                      selectedWeekdays.length == 1) {
                                    return;
                                  }
                                  setSheetState(() {
                                    if (selected) {
                                      selectedWeekdays.add(entry.key);
                                    } else {
                                      selectedWeekdays.remove(entry.key);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose at least one day. Changes are saved when you choose a focus time.',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: sheetContext,
                            initialTime: reminders.time,
                          );
                          if (selected == null || !sheetContext.mounted) return;
                          final scheduled = await reminders.setDailyReminder(
                            selected,
                            weekdays: selectedWeekdays,
                          );
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                scheduled
                                    ? 'Focus time scheduled for ${MaterialLocalizations.of(sheetContext).formatTimeOfDay(selected)}.'
                                    : 'Allow notifications to schedule a focus time.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          reminders.isEnabled
                              ? 'Update focus time'
                              : 'Choose focus time',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final notifications = context
                              .read<NotificationService>();
                          final permitted = await notifications
                              .requestPermissions();
                          if (!context.mounted) return;
                          if (!permitted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Allow notifications to send a test alert.',
                                ),
                              ),
                            );
                            return;
                          }
                          await notifications.showTestNotification();
                        },
                        icon: const Icon(Icons.notifications_outlined),
                        label: const Text('Send a test notification'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Consumer<AuthService>(
              builder: (context, auth, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your FocusHaven account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.isSignedIn
                        ? 'Signed in as ${auth.displayName}'
                        : 'Sign in to protect your focus history and use cloud backup.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            auth.isSignedIn
                                ? Icons.cloud_done_outlined
                                : Icons.phone_android_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              auth.isSignedIn
                                  ? 'Your focus data stays on this device. FocusHaven Pro can also back it up privately to your account.'
                                  : 'Your focus data stays private on this device. Sign in only when you want optional cloud backup.',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (auth.isSignedIn)
                    OutlinedButton.icon(
                      onPressed: auth.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        final result = await auth.signInWithGoogle();
                        if (!sheetContext.mounted) return;
                        if (result != null) {
                          Navigator.pop(sheetContext);
                        } else {
                          final message =
                              auth.signInError ??
                              'Sign-in was not completed. Please try again.';
                          ScaffoldMessenger.of(
                            sheetContext,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                    ),
                  if (auth.isSignedIn)
                    TextButton.icon(
                      onPressed: () => _confirmDeleteCloudBackup(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete cloud backup'),
                    ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteLocalData(context),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete local data'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showProSheet(context),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('FocusHaven Pro'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showFocusProfileSheet(context),
                    icon: const Icon(Icons.psychology_outlined),
                    label: const Text('Discover your focus profile'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showThemeSheet(context),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Appearance'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openPrivacyPolicy(context),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showThemeSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Consumer<ThemeService>(
          builder: (context, themes, _) => SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: RadioGroup<FocusHavenTheme>(
                groupValue: themes.selectedTheme,
                onChanged: (value) {
                  if (value != null) themes.setTheme(value);
                },
                child: ListView(
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the atmosphere that feels best for your focus.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    ...FocusHavenTheme.values.map(
                      (theme) => RadioListTile<FocusHavenTheme>(
                        contentPadding: EdgeInsets.zero,
                        value: theme,
                        title: Text(theme.label),
                        secondary: CircleAvatar(backgroundColor: theme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBreathingPause(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const GuidedBreathingSheet(),
    );
  }

  Future<void> _showFocusProfileSheet(BuildContext context) async {
    const questions = [
      _FocusQuestion(
        prompt: 'When does focused work feel most natural?',
        choices: [
          _FocusChoice('Early in the day', 'Clear Starter'),
          _FocusChoice('Once I build momentum', 'Momentum Builder'),
          _FocusChoice('Later in the evening', 'Night Owl'),
        ],
      ),
      _FocusQuestion(
        prompt: 'Which environment helps you settle in?',
        choices: [
          _FocusChoice('Quiet and uninterrupted', 'Deep Diver'),
          _FocusChoice('Gentle music or ambient sound', 'Gentle Flow'),
          _FocusChoice('A clear plan and small steps', 'Momentum Builder'),
        ],
      ),
      _FocusQuestion(
        prompt: 'When you feel stuck, what helps most?',
        choices: [
          _FocusChoice('Removing every distraction', 'Deep Diver'),
          _FocusChoice('Taking a brief reset', 'Gentle Flow'),
          _FocusChoice('Starting with one tiny action', 'Momentum Builder'),
        ],
      ),
      _FocusQuestion(
        prompt: 'What kind of session sounds best?',
        choices: [
          _FocusChoice('A long, uninterrupted block', 'Deep Diver'),
          _FocusChoice('A calm, flexible rhythm', 'Gentle Flow'),
          _FocusChoice('A quick, energizing sprint', 'Clear Starter'),
        ],
      ),
    ];
    final profile = context.read<FocusProfileService>();
    var page = -1;
    String? result;
    final answers = List<_FocusChoice?>.filled(questions.length, null);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final activeType = result ?? profile.focusType;
          if (page == questions.length && result != null) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your focus profile',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeType!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _focusProfileTip(activeType),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: _ink,
                      ),
                      child: const Text('Use this profile'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (page == -1) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Find your focus profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      activeType == null
                          ? 'Answer four quick questions for a practical focus style and tip.'
                          : 'Your current profile is $activeType. Retake the quiz anytime as your habits change.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => setSheetState(() => page = 0),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: _ink,
                      ),
                      child: Text(
                        activeType == null ? 'Start quiz' : 'Retake quiz',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final question = questions[page];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${page + 1} of ${questions.length}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  ...question.choices.map(
                    (choice) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () async {
                          answers[page] = choice;
                          if (page == questions.length - 1) {
                            final scores = <String, int>{};
                            for (final answer
                                in answers.whereType<_FocusChoice>()) {
                              scores.update(
                                answer.focusType,
                                (count) => count + 1,
                                ifAbsent: () => 1,
                              );
                            }
                            final winner = scores.entries
                                .reduce(
                                  (first, next) =>
                                      first.value >= next.value ? first : next,
                                )
                                .key;
                            await profile.saveFocusType(winner);
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                result = winner;
                                page = questions.length;
                              });
                            }
                          } else {
                            setSheetState(() => page++);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Text(choice.label),
                      ),
                    ),
                  ),
                  if (page > 0) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => setSheetState(() => page--),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to previous question'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _focusProfileTip(String focusType) => switch (focusType) {
    'Clear Starter' =>
      'Protect your best early window with one clear intention and a short timer.',
    'Momentum Builder' =>
      'Start with a small five-minute step. Momentum is your best fuel.',
    'Deep Diver' =>
      'Create a quiet, distraction-free block and let yourself stay with one meaningful task.',
    'Gentle Flow' =>
      'Use calm transitions, a comfortable pace, and intentional breaks to stay steady.',
    'Night Owl' =>
      'Plan your most important work for your later high-energy window and protect your wind-down.',
    _ => 'Choose a calm space and one clear next step.',
  };

  Future<void> _showProSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final purchases = sheetContext.read<IAPService>();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FocusHaven Pro',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Protect your focus progress with secure cloud backup and restore it on your other devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  const _ProBenefit(
                    icon: Icons.cloud_done_outlined,
                    label: 'Secure cloud backup',
                  ),
                  const _ProBenefit(
                    icon: Icons.devices_outlined,
                    label: 'Restore on another device',
                  ),
                  const _ProBenefit(
                    icon: Icons.all_inclusive,
                    label: 'One-time lifetime unlock',
                  ),
                  const SizedBox(height: 22),
                  FutureBuilder<String?>(
                    future: purchases.proPrice(),
                    builder: (context, snapshot) {
                      final price = snapshot.data;
                      return FilledButton(
                        onPressed: price == null
                            ? null
                            : () async {
                                try {
                                  await purchases.buyPro();
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Complete your purchase in the store window',
                                        ),
                                      ),
                                    );
                                  }
                                } on StateError catch (error) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: Text(
                          price == null
                              ? 'Pro is not available yet'
                              : 'Unlock Pro for $price',
                        ),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      await purchases.restorePurchases();
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Checking the store for previous purchases',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Restore purchases'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    TimerService timer,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear focus history?'),
        content: const Text(
          'This removes all saved focus sessions on this device and resets your completed count and streak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep history'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _ink,
            ),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      timer.clearFocusHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Focus history cleared from this device'),
          ),
        );
      }
    }
  }

  Future<void> _editFocusTask(BuildContext context, TimerService timer) async {
    final controller = TextEditingController(text: timer.focusTask);
    final task = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What are you focusing on?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Example: Finish the project proposal',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _ink,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (task != null) {
      timer.setFocusTask(task);
    }
  }

  Future<void> _showFocusQueueSheet(
    BuildContext context,
    TimerService timer,
  ) async {
    final textController = TextEditingController();
    final scrollController = ScrollController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: riverpod.Consumer(
            builder: (context, ref, _) {
              final queueState = ref.watch(focusQueueStateProvider);
              final queue = ref.read(focusQueueServiceProvider);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: false,
                  interactive: true,
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 42,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Focus queue',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Choose a task to make it your current focus intention.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      if (queueState.completedToday > 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${queueState.completedToday} ${queueState.completedToday == 1 ? 'task' : 'tasks'} tended today — gentle progress.',
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textController,
                              maxLength: 100,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) async {
                                await queue.add(textController.text);
                                textController.clear();
                              },
                              decoration: const InputDecoration(
                                hintText: 'Add a task',
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () async {
                              await queue.add(textController.text);
                              textController.clear();
                            },
                            icon: const Icon(Icons.add),
                            tooltip: 'Add task',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (queueState.activeItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: Center(
                            child: Text(
                              'Your next task can live here.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        )
                      else
                        ...queueState.activeItems.map(
                          (item) => ListTile(
                            onTap: item.isComplete
                                ? null
                                : () {
                                    timer.setFocusTask(item.title);
                                    Navigator.pop(sheetContext);
                                  },
                            leading: Checkbox(
                              value: item.isComplete,
                              onChanged: (_) async {
                                final wasComplete = item.isComplete;
                                await queue.toggle(item.id);
                                if (!wasComplete && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'One thing handled. Take a breath.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            title: Text(
                              item.title,
                              style: item.isComplete
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _editFocusQueueTask(
                                    sheetContext,
                                    queue,
                                    item,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit task',
                                ),
                                IconButton(
                                  onPressed: () => queue.remove(item.id),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remove task',
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (queueState.completedItems.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showCompletedTasksSheet(sheetContext),
                            icon: const Icon(Icons.history_outlined),
                            label: Text(
                              'Completed (${queueState.completedItems.length})',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => textController.dispose(),
    );
    scrollController.dispose();
  }

  Future<void> _editFocusQueueTask(
    BuildContext context,
    FocusQueueService queue,
    FocusQueueItem item,
  ) async {
    final controller = TextEditingController(text: item.title);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
          decoration: const InputDecoration(
            hintText: 'What needs your attention?',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog route still owns the text field during its closing animation.
    // Dispose after that animation so saving with Return is safe on desktop.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });
    if (updated != null) {
      await queue.rename(item.id, updated);
    }
  }

  Future<void> _showCompletedTasksSheet(BuildContext context) async {
    final scrollController = ScrollController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.62,
          child: riverpod.Consumer(
            builder: (context, ref, _) {
              final queueState = ref.watch(focusQueueStateProvider);
              final queue = ref.read(focusQueueServiceProvider);
              return Padding(
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
                      'Completed tasks',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'A quiet record of what you handled.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        controller: scrollController,
                        thumbVisibility: false,
                        interactive: true,
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: queueState.completedItems.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Colors.white12),
                          itemBuilder: (context, index) {
                            final item = queueState.completedItems[index];
                            return ListTile(
                              leading: Icon(
                                Icons.check_circle_outline,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                item.completedAt == null
                                    ? 'Completed'
                                    : 'Completed ${_dateLabel(item.completedAt!)}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Return to queue',
                                icon: const Icon(Icons.undo),
                                onPressed: () => queue.toggle(item.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    scrollController.dispose();
  }

  Future<void> _captureDistraction(
    BuildContext context,
    TimerService timer,
  ) async {
    final controller = TextEditingController();
    final thought = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Park this thought'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Example: Reply to Jordan after this session',
            helperText: 'Save it, then return to your focus.',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _ink,
            ),
            child: const Text('Save thought'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (thought != null) {
      timer.captureDistraction(thought);
    }
  }

  Future<String?> _editParkedThought(
    BuildContext context, {
    String? existingThought,
  }) async {
    final controller = TextEditingController(text: existingThought ?? '');
    final thought = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existingThought == null
              ? 'Add a parked thought'
              : 'Edit parked thought',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Example: Reply to Jordan after this session',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _ink,
            ),
            child: Text(
              existingThought == null ? 'Add thought' : 'Save changes',
            ),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    return thought;
  }

  Future<void> _showDistractionSheet(
    BuildContext context,
    TimerService timer,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
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
                    'Distraction parking lot',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your saved thoughts stay on this device until you clear them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final thought = await _editParkedThought(context);
                      if (thought == null) return;
                      timer.captureDistraction(thought);
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add a thought'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        sheetContext,
                      ).colorScheme.primary,
                      foregroundColor: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: timer.distractions.isEmpty
                        ? const Center(
                            child: Text(
                              'Nothing parked yet. Keep your attention where you want it.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: timer.distractions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, color: Colors.white12),
                            itemBuilder: (context, index) => ListTile(
                              leading: Icon(
                                Icons.bookmark_outline,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                              title: Text(timer.distractions[index]),
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit thought',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final updated = await _editParkedThought(
                                        context,
                                        existingThought:
                                            timer.distractions[index],
                                      );
                                      if (updated == null) return;
                                      timer.updateDistraction(index, updated);
                                      setSheetState(() {});
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Remove thought',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      timer.removeDistractionAt(index);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (timer.distractions.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        timer.clearDistractions();
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear parking lot'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMilestonesSheet(
    BuildContext context,
    TimerService timer,
  ) async {
    final scrollController = ScrollController();
    final milestones = [
      _Milestone(
        'First step',
        'Complete your first focus session.',
        timer.completedFocusSessions >= 1,
      ),
      _Milestone(
        'Weekly rhythm',
        'Complete 3 focus sessions in seven days.',
        timer.weeklyFocusSessions >= 3,
      ),
      _Milestone(
        'Momentum',
        'Complete 5 focus sessions in total.',
        timer.completedFocusSessions >= 5,
      ),
      _Milestone(
        'Half-hour haven',
        'Reach 30 total minutes of focus.',
        timer.totalFocusSeconds >= 30 * 60,
      ),
      _Milestone(
        'Century club',
        'Reach 100 total minutes of focus.',
        timer.totalFocusSeconds >= 100 * 60,
      ),
      _Milestone(
        'Steady flame',
        'Build a 3-day focus streak.',
        timer.currentStreak >= 3,
      ),
      _Milestone(
        'Deep roots',
        'Build a 7-day focus streak.',
        timer.currentStreak >= 7,
      ),
      _Milestone(
        'Goal getter',
        'Reach your daily focus goal.',
        timer.hasReachedDailyGoal,
      ),
    ];
    final unlocked = milestones.where((milestone) => milestone.unlocked).length;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
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
                  'Focus milestones',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  '$unlocked of ${milestones.length} unlocked',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: false,
                    interactive: true,
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: milestones.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final milestone = milestones[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(sheetContext)
                                .colorScheme
                                .primary
                                .withValues(
                                  alpha: milestone.unlocked ? 0.22 : 0.08,
                                ),
                            child: Icon(
                              milestone.unlocked
                                  ? Icons.emoji_events_outlined
                                  : Icons.lock_outline,
                              color: milestone.unlocked
                                  ? Theme.of(sheetContext).colorScheme.primary
                                  : Colors.white38,
                            ),
                          ),
                          title: Text(milestone.title),
                          subtitle: Text(milestone.detail),
                          trailing: Icon(
                            milestone.unlocked
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: milestone.unlocked
                                ? Theme.of(sheetContext).colorScheme.primary
                                : Colors.white38,
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
      ),
    );
    scrollController.dispose();
  }

  Future<void> _showFocusHistory(
    BuildContext context,
    TimerService timer,
    List<FocusSession> focusHistory,
  ) async {
    final weeklySeconds = timer.lastSevenDaysFocusSeconds;
    final weeklyMinutes = timer.weeklyFocusSeconds ~/ 60;
    final weeklySessions = timer.weeklyFocusSessions;
    final weeklyDuration = timer.weeklyFocusSeconds < 60
        ? '${timer.weeklyFocusSeconds} ${timer.weeklyFocusSeconds == 1 ? 'second' : 'seconds'}'
        : '$weeklyMinutes ${weeklyMinutes == 1 ? 'minute' : 'minutes'}';
    final highestDaySeconds = weeklySeconds.fold(
      1,
      (highest, seconds) => seconds > highest ? seconds : highest,
    );
    var historyFilter = _HistoryFilter.all;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
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
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${timer.completedFocusSessions} completed sessions',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _copyFocusHistory(sheetContext, timer),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy full summary'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
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
                            style: Theme.of(sheetContext).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$weeklyDuration • $weeklySessions ${weeklySessions == 1 ? 'session' : 'sessions'}',
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
                                final double height = weeklySeconds[index] == 0
                                    ? 3.0
                                    : 8.0 +
                                          (42 *
                                              weeklySeconds[index] /
                                              highestDaySeconds);
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
                                              sheetContext,
                                            ).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
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
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final sessions = focusHistory.where((session) {
                          return switch (historyFilter) {
                            _HistoryFilter.all => true,
                            _HistoryFilter.today => DateUtils.isSameDay(
                              session.completedAt,
                              now,
                            ),
                            _HistoryFilter.week =>
                              !session.completedAt.isBefore(
                                now.subtract(const Duration(days: 6)),
                              ),
                          };
                        }).toList();

                        return Column(
                          children: [
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
                                      selected: historyFilter == option,
                                      onSelected: (_) => setSheetState(
                                        () => historyFilter = option,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: sessions.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No focus sessions in this time range yet.',
                                        style: TextStyle(color: Colors.white60),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: sessions.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(
                                            height: 1,
                                            color: Colors.white12,
                                          ),
                                      itemBuilder: (context, index) {
                                        final session = sessions[index];
                                        final time =
                                            MaterialLocalizations.of(
                                              context,
                                            ).formatTimeOfDay(
                                              TimeOfDay.fromDateTime(
                                                session.completedAt,
                                              ),
                                            );
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.2),
                                            child: Icon(
                                              Icons.auto_awesome,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          title: Text(
                                            session.focusTask ??
                                                _focusSessionLabel(
                                                  session.durationSeconds,
                                                ),
                                          ),
                                          subtitle: Text(
                                            '${_focusSessionLabel(session.durationSeconds)} • ${_dateLabel(session.completedAt)} at $time',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
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

  Future<void> _chooseDailyGoal(
    BuildContext context,
    TimerService timer,
  ) async {
    final controller = TextEditingController(
      text: timer.dailyGoalMinutes.toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set daily focus goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Minutes per day',
            helperText: 'Choose between 5 and 480 minutes',
          ),
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _ink,
            ),
            child: const Text('Save goal'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (minutes != null) {
      timer.setDailyGoalMinutes(minutes);
    }
  }

  Future<void> _editTodayJournal(
    BuildContext context,
    JournalService journal,
  ) async {
    const moods = ['Calm', 'Focused', 'Tired', 'Stressed', 'Grateful'];
    var selectedMood = journal.todayEntry?.mood ?? moods.first;
    final controller = TextEditingController(
      text: journal.todayEntry?.reflection ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Today's reflection"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How are you feeling?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: moods
                      .map(
                        (mood) => ChoiceChip(
                          label: Text(mood),
                          selected: selectedMood == mood,
                          onSelected: (_) =>
                              setDialogState(() => selectedMood = mood),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  maxLength: 800,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: journal.dailyPrompt,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await journal.saveToday(
                  mood: selectedMood,
                  reflection: controller.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: _ink,
              ),
              child: const Text('Save reflection'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  Future<void> _showJournalSheet(BuildContext context) async {
    final scrollController = ScrollController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Consumer<JournalService>(
            builder: (context, journal, _) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: false,
                      interactive: true,
                      child: ListView(
                        controller: scrollController,
                        children: [
                          Text(
                            'Reflection journal',
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'A private space saved only on this device.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Today’s prompt: ${journal.dailyPrompt}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                          if (journal.recentMoodCounts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Mood snapshot',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Over the last 7 days, you most often felt ${journal.mostCommonRecentMood?.toLowerCase()}.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: journal.recentMoodCounts.entries
                                  .map(
                                    (entry) => Chip(
                                      label: Text(
                                        '${entry.key} ${entry.value}',
                                      ),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.13),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _editTodayJournal(sheetContext, journal),
                            icon: const Icon(Icons.edit_note),
                            label: Text(
                              journal.todayEntry == null
                                  ? 'Write today’s reflection'
                                  : 'Update today’s reflection',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: _ink,
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Recent reflections',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          if (journal.entries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  'Your first reflection will appear here.',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                            )
                          else
                            ...journal.entries.map(
                              (entry) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                leading: Icon(
                                  Icons.favorite_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  '${entry.mood} • ${_dateLabel(entry.createdAt)}',
                                ),
                                subtitle: Text(
                                  entry.reflection,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final timer = ref.read(timerServiceProvider);
    final session = ref.watch(timerSessionStateProvider);
    final focusHistory = ref.watch(timerFocusHistoryProvider);
    final summary = ref.watch(timerSummaryStateProvider);
    final isSignedIn = ref.watch(authIsSignedInProvider);
    final queueRemaining = ref.watch(focusQueueRemainingCountProvider);
    final sessionColor = _sessionColor(context, session.sessionType);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusHaven'),
        actions: [
          IconButton(
            icon: const Icon(Icons.self_improvement_outlined),
            tooltip: 'Mindful pause',
            onPressed: () => _showBreathingPause(context),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Reflection journal',
            onPressed: () => _showJournalSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Daily focus reminder',
            onPressed: () => _showReminderSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: isSignedIn ? 'Account' : 'Sign in',
            onPressed: () => _showAccountSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
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
                                selected: session.sessionType == type,
                                onSelected: (_) => timer.selectSession(type),
                                selectedColor: sessionColor.withValues(
                                  alpha: 0.32,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        session.isComplete
                            ? 'SESSION COMPLETE'
                            : session.sessionType.label.toUpperCase(),
                        style: TextStyle(
                          color: sessionColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        session.isComplete
                            ? session.completionMessage
                            : session.sessionType.encouragement,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (session.sessionType == SessionType.focus) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _editFocusTask(context, timer),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                            session.focusTask.isEmpty
                                ? 'Set a focus intention'
                                : session.focusTask,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showFocusQueueSheet(context, timer),
                          icon: const Icon(
                            Icons.format_list_bulleted_outlined,
                            size: 18,
                          ),
                          label: Text(
                            queueRemaining == 0
                                ? 'Open focus queue'
                                : 'Focus queue • $queueRemaining',
                          ),
                        ),
                        if (session.isRunning || session.parkedThoughtCount > 0)
                          TextButton.icon(
                            onPressed: () => session.isRunning
                                ? _captureDistraction(context, timer)
                                : _showDistractionSheet(context, timer),
                            icon: Icon(
                              session.isRunning
                                  ? Icons.add_task_outlined
                                  : Icons.bookmark_outline,
                              size: 18,
                            ),
                            label: Text(
                              session.isRunning
                                  ? 'Park a distraction${session.parkedThoughtCount == 0 ? '' : ' • ${session.parkedThoughtCount} saved'}'
                                  : 'Review ${session.parkedThoughtCount} parked thought${session.parkedThoughtCount == 1 ? '' : 's'}',
                            ),
                          ),
                      ],
                      const SizedBox(height: 30),
                      _TimerCountdown(
                        sessionColor: sessionColor,
                        formatTime: _formattedTime,
                        durationLabel: _durationLabel,
                      ),
                      const SizedBox(height: 28),
                      if (session.hasPendingResume)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: sessionColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                const Text(
                                  'Resume your saved session?',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Your timer was paused when FocusHaven reopened.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: timer.discardPendingSession,
                                        child: const Text('Start fresh'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: timer.resumePendingSession,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: sessionColor,
                                          foregroundColor: _ink,
                                        ),
                                        child: const Text('Resume'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (session.isComplete)
                        FilledButton.icon(
                          onPressed: timer.beginNextSession,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            session.sessionType == SessionType.focus
                                ? 'Take a break'
                                : 'Begin focus',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: sessionColor,
                            foregroundColor: _ink,
                            minimumSize: const Size(210, 54),
                          ),
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
                              onPressed: session.isRunning
                                  ? timer.pause
                                  : timer.start,
                              icon: Icon(
                                session.isRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                session.isRunning
                                    ? 'Pause'
                                    : 'Begin ${session.sessionType.label.toLowerCase()}',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: sessionColor,
                                foregroundColor: _ink,
                                minimumSize: const Size(172, 54),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () => _chooseCustomDuration(context, timer),
                        icon: const Icon(Icons.tune),
                        label: const Text('Custom duration'),
                        style: TextButton.styleFrom(
                          foregroundColor: sessionColor,
                        ),
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
                                value: '${summary.todayFocusMinutes}m',
                                label: 'today',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.local_fire_department_outlined,
                                value: '${summary.currentStreak}',
                                label: 'day streak',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.check_circle_outline,
                                value: '${summary.completedFocusSessions}',
                                label: 'completed',
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showMilestonesSheet(context, timer),
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Milestones'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.flag_outlined,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Daily focus goal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _chooseDailyGoal(context, timer),
                                      child: const Text('Change'),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_shortDurationLabel(timer.todayFocusSeconds)} of ${summary.dailyGoalMinutes} min',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: summary.dailyGoalProgress,
                                  minHeight: 9,
                                  borderRadius: BorderRadius.circular(99),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.10,
                                  ),
                                  color: summary.hasReachedDailyGoal
                                      ? secondaryColor
                                      : primaryColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summary.hasReachedDailyGoal
                                      ? 'Daily goal complete — wonderful work.'
                                      : '${((summary.dailyGoalMinutes * 60 - timer.todayFocusSeconds) / 60).ceil()} min remaining today',
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: summary.hasCompletedDailyChallenge
                                ? secondaryColor.withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      summary.hasCompletedDailyChallenge
                                          ? Icons.emoji_events_outlined
                                          : Icons.flag_outlined,
                                      color: summary.hasCompletedDailyChallenge
                                          ? secondaryColor
                                          : primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Daily challenge',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${summary.todayFocusSessions}/${summary.dailyChallengeTarget}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  summary.hasCompletedDailyChallenge
                                      ? 'Challenge complete — you showed up for yourself today.'
                                      : 'Complete ${summary.dailyChallengeTarget} focus sessions today.',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: summary.dailyChallengeProgress,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(99),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.10,
                                  ),
                                  color: summary.hasCompletedDailyChallenge
                                      ? secondaryColor
                                      : tertiaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent focus',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (focusHistory.isNotEmpty)
                              TextButton(
                                onPressed: () => _showFocusHistory(
                                  context,
                                  timer,
                                  focusHistory,
                                ),
                                child: const Text('View all'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (focusHistory.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Complete a focus session to begin your history.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        else
                          ...focusHistory
                              .take(3)
                              .map(
                                (session) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    session.focusTask ??
                                        _focusSessionLabel(
                                          session.durationSeconds,
                                        ),
                                  ),
                                  subtitle: session.focusTask == null
                                      ? null
                                      : Text(
                                          _focusSessionLabel(
                                            session.durationSeconds,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                  trailing: Text(
                                    _dateLabel(session.completedAt),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                              ),
                        if (focusHistory.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _confirmClearHistory(context, timer),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear focus history'),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final isPro = await IAPService.isProUser();
                                if (!context.mounted) return;
                                final message = !isSignedIn
                                    ? 'Sign in with Google to back up your focus data'
                                    : !isPro
                                    ? 'Upgrade to Pro to use cloud backup'
                                    : await context
                                          .read<CloudSyncService>()
                                          .syncFocusData(timer.cloudBackup)
                                    ? 'Focus data backed up securely'
                                    : 'Backup failed. Check your Firebase setup.';
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Back up'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final isPro = await IAPService.isProUser();
                                if (!context.mounted) return;
                                String message;
                                if (!isSignedIn) {
                                  message =
                                      'Sign in with Google to restore your focus data';
                                } else if (!isPro) {
                                  message =
                                      'Upgrade to Pro to restore cloud backup';
                                } else {
                                  final backup = await context
                                      .read<CloudSyncService>()
                                      .fetchFocusData();
                                  if (!context.mounted) return;
                                  message = backup == null
                                      ? 'No cloud backup found yet'
                                      : timer.restoreCloudBackup(backup)
                                      ? 'Focus data restored from cloud'
                                      : 'That cloud backup could not be restored';
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Restore'),
                            ),
                          ],
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

/// The only timer-screen subtree that rebuilds for each one-second tick.
class _TimerCountdown extends riverpod.ConsumerWidget {
  const _TimerCountdown({
    required this.sessionColor,
    required this.formatTime,
    required this.durationLabel,
  });

  final Color sessionColor;
  final String Function(int seconds) formatTime;
  final String Function(int seconds) durationLabel;

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final countdown = ref.watch(timerCountdownStateProvider);

    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 270,
            height: 270,
            child: CircularProgressIndicator(
              value: countdown.progress.clamp(0, 1),
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              color: sessionColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTime(countdown.secondsRemaining),
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                durationLabel(countdown.totalSessionSeconds),
                style: const TextStyle(
                  color: Colors.white60,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  const _Milestone(this.title, this.detail, this.unlocked);

  final String title;
  final String detail;
  final bool unlocked;
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
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBenefit extends StatelessWidget {
  const _ProBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _FocusQuestion {
  const _FocusQuestion({required this.prompt, required this.choices});

  final String prompt;
  final List<_FocusChoice> choices;
}

class _FocusChoice {
  const _FocusChoice(this.label, this.focusType);

  final String label;
  final String focusType;
}
