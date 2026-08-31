import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/focus_milestone.dart';
import '../models/focus_session.dart';
import '../models/haven_plan.dart';
import '../models/haven_action.dart';
import '../models/haven_window_suggestion.dart';
import '../models/journal_entry.dart';
import '../providers/app_providers.dart';
import '../services/coaching_service.dart';
import '../services/focus_queue_service.dart';
import '../services/journal_service.dart';
import '../services/timer_service.dart';
import '../widgets/account_sheet.dart';
import '../widgets/cloud_backup_actions.dart';
import '../widgets/coaching_sheet.dart';
import '../widgets/completed_tasks_sheet.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/focus_queue_sheet.dart';
import '../widgets/focus_history_sheet.dart';
import '../widgets/focus_forecast_card.dart';
import '../widgets/focus_forecast_reflection_connection_card.dart';
import '../widgets/custom_duration_sheet.dart';
import '../widgets/reminder_sheet.dart';
import '../widgets/appearance_sheet.dart';
import '../widgets/distraction_parking_sheet.dart';
import '../widgets/focus_milestones_sheet.dart';
import '../widgets/focus_profile_sheet.dart';
import '../widgets/focus_session_reflection_card.dart';
import '../widgets/focus_shield_card.dart';
import '../widgets/guided_breathing_sheet.dart';
import '../widgets/haven_plan_sheet.dart';
import '../widgets/haven_planner_sheet.dart';
import '../widgets/haven_action_sheet.dart';
import '../widgets/haven_journey_card.dart';
import '../widgets/haven_loop_completion_card.dart';
import '../widgets/haven_rhythm_card.dart';
import '../widgets/haven_rhythm_reflection_connection_card.dart';
import '../widgets/haven_window_card.dart';
import '../widgets/journal_entry_dialog.dart';
import '../widgets/living_lantern_card.dart';
import '../widgets/pro_sheet.dart';
import '../widgets/reflection_journal_sheet.dart';
import '../widgets/smart_reset_sheet.dart';
import '../widgets/stat_card.dart';
import '../widgets/text_entry_dialog.dart';
import '../widgets/timer_countdown.dart';

class TimerScreen extends riverpod.ConsumerWidget {
  const TimerScreen({this.openExternalUrl, this.writeClipboard, super.key});

  /// Overrides external URL launching in tests and alternate host shells.
  final Future<bool> Function(Uri uri)? openExternalUrl;

  /// Overrides clipboard writes in tests and alternate host shells.
  final Future<void> Function(String text)? writeClipboard;

  static const _ink = Color(0xFF211442);
  static const _journalMoods = [
    'Calm',
    'Focused',
    'Tired',
    'Stressed',
    'Grateful',
  ];

  bool _canOpenOverlay(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent ?? false;

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
    final summary = timer.focusHistoryExport;
    try {
      final writer = writeClipboard;
      if (writer == null) {
        await Clipboard.setData(ClipboardData(text: summary));
      } else {
        await writer(summary);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Focus summary could not be copied right now.'),
          ),
        );
      }
      return;
    }
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
    final localDate = date.toLocal();
    final now = DateTime.now().toLocal();
    if (DateUtils.isSameDay(localDate, now)) return 'Today';
    if (DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
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
    return '${months[localDate.month - 1]} ${localDate.day}';
  }

  void _beginNextSession(TimerService timer) {
    if (!timer.isComplete) return;
    timer.beginNextSession();
  }

  Future<void> _chooseCustomDuration(
    BuildContext context,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CustomDurationSheet(
        sessionLabel: timer.sessionType.label,
        sessionColor: _sessionColor(context, timer.sessionType),
        initialDuration: Duration(seconds: timer.totalSessionSeconds),
        foregroundColor: _ink,
      ),
    );
    if (duration != null && duration.inSeconds > 0) {
      timer.setCustomDuration(duration.inMinutes, duration.inSeconds % 60);
    }
  }

  Future<void> _resetTimer(
    BuildContext context,
    riverpod.WidgetRef ref,
    TimerService timer,
  ) async {
    if (!timer.canOfferSmartReset) {
      timer.reset();
      return;
    }
    if (!_canOpenOverlay(context)) return;

    final wasRunning = timer.isRunning;
    if (wasRunning) timer.pause();
    if (!timer.canOfferSmartReset) return;

    final plan = ref
        .read(smartResetServiceProvider)
        .createPlan(
          plannedDurationSeconds: timer.activeFocusPlannedSeconds,
          focusedDurationSeconds: timer.activeFocusFocusedSeconds,
          recentEvents: ref.read(timerFocusEventsProvider),
        );
    final choice = await showModalBottomSheet<SmartResetChoice>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SmartResetSheet(plan: plan),
    );
    if (!context.mounted || !timer.canOfferSmartReset) return;

    switch (choice) {
      case SmartResetChoice.restart:
        timer.startSmartReset(plan.restartDurationSeconds);
        break;
      case SmartResetChoice.reset:
        timer.reset();
        break;
      case SmartResetChoice.keep:
      case null:
        if (wasRunning) timer.start();
        break;
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    const policyUrl =
        'https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html';
    final uri = Uri.parse(policyUrl);
    var opened = false;
    try {
      final launcher = openExternalUrl;
      opened = launcher == null
          ? await launchUrl(uri, mode: LaunchMode.externalApplication)
          : await launcher(uri);
    } catch (_) {
      // Platform launch failures use the same retryable message as a
      // launcher that reports it could not open the URL.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the privacy policy right now.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteCloudBackup(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete cloud backup?',
      message:
          'This permanently deletes the FocusHaven backup stored in your account. Your data on this device will stay here.',
      cancelLabel: 'Keep backup',
      confirmLabel: 'Delete backup',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final deleted = await ref.read(cloudSyncServiceProvider).deleteFocusData();
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

  Future<void> _confirmDeleteLocalData(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final timer = ref.read(timerServiceProvider);
    final journal = ref.read(journalServiceProvider);
    final coach = ref.read(coachingServiceProvider);
    final focusQueue = ref.read(focusQueueServiceProvider);
    final havenLoop = ref.read(havenLoopServiceProvider);
    final profile = ref.read(focusProfileServiceProvider);
    final themes = ref.read(themeServiceProvider);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete local data?',
      message:
          'This permanently removes your timer history, coaching conversation, journal entries, tasks, parked thoughts, goals, profile, and appearance choices from this device. Your cloud backup will not be deleted.',
      cancelLabel: 'Keep my data',
      confirmLabel: 'Delete local data',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final coachingCleared = await coach.clearLocalData();
    if (!coachingCleared) {
      throw StateError('Private coaching data was not completely cleared.');
    }
    await havenLoop.clearLocalData();
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

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete FocusHaven account?',
      message:
          'This permanently deletes your FocusHaven sign-in, cloud backup, and account-specific enhanced-coaching usage records. Your local focus data and store purchase history will stay on this device or with the store. You may be asked to sign in again to verify the request.',
      cancelLabel: 'Keep my account',
      confirmLabel: 'Delete account',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await ref
        .read(accountDeletionServiceProvider)
        .deleteAccount();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.deleted) {
      Navigator.of(context).pop();
    }
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _showReminderSheet(BuildContext context) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ReminderSheet(),
    );
  }

  Future<void> _showAccountSheet(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => AccountSheet(
        deleteAccount: () => _confirmDeleteAccount(sheetContext, ref),
        deleteCloudBackup: () => _confirmDeleteCloudBackup(sheetContext, ref),
        deleteLocalData: () => _confirmDeleteLocalData(sheetContext, ref),
        openPro: () => _showProSheet(sheetContext),
        openFocusProfile: () => _showFocusProfileSheet(sheetContext),
        openAppearance: () => _showThemeSheet(sheetContext),
        openPrivacyPolicy: () => _openPrivacyPolicy(sheetContext),
      ),
    );
  }

  Future<void> _showThemeSheet(BuildContext context) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AppearanceSheet(),
    );
  }

  Future<void> _showBreathingPause(BuildContext context) async {
    if (!_canOpenOverlay(context)) return;
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
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const FocusProfileSheet(),
    );
  }

  Future<void> _showProSheet(BuildContext context) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ProSheet(),
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final shouldClear = await ConfirmationDialog.show(
      context,
      title: 'Clear focus history?',
      message:
          'This removes all saved focus sessions on this device and resets your completed count and streak.',
      cancelLabel: 'Keep history',
      confirmLabel: 'Clear history',
      isDestructive: true,
    );
    if (shouldClear) {
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
    if (!_canOpenOverlay(context)) return;
    final task = await TextEntryDialog.show(
      context,
      title: 'What are you focusing on?',
      confirmLabel: 'Save',
      initialValue: timer.focusTask,
      hintText: 'Example: Finish the project proposal',
      cancelLabel: null,
      clearLabel: 'Clear',
      maxLength: 80,
    );
    if (task == null || !context.mounted) return;
    final container = riverpod.ProviderScope.containerOf(context);
    await container.read(havenLoopServiceProvider).setManualFocusTask(task);
  }

  Future<void> _showFocusQueueSheet(
    BuildContext context,
    TimerService timer,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => FocusQueueSheet(
        onTaskSelected: ref.read(havenLoopServiceProvider).selectQueueItem,
        onEditTask: (item) => _editFocusQueueTask(
          sheetContext,
          ref.read(focusQueueServiceProvider),
          item,
        ),
        onShowCompleted: () => _showCompletedTasksSheet(sheetContext),
      ),
    );
  }

  Future<void> _showHavenPlanSheet(
    BuildContext context,
    TimerService timer,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context) || !timer.canStartHavenPlan) {
      return;
    }
    final plan = await showModalBottomSheet<HavenPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const HavenPlanSheet(),
    );
    if (plan == null || !context.mounted) return;
    if (!timer.canStartHavenPlan) return;

    final queueItemId = plan.queueItemId;
    if (queueItemId != null) {
      final selected = await ref
          .read(havenLoopServiceProvider)
          .selectQueueItemById(queueItemId);
      if (!selected || !context.mounted) return;
    }
    timer.setCustomMinutes(plan.focusMinutes);
    timer.start();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Haven Plan started: ${plan.focusMinutes} minutes of focus.',
        ),
      ),
    );
  }

  Future<void> _showHavenPlannerSheet(
    BuildContext context,
    riverpod.WidgetRef ref,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => HavenPlannerSheet(
        timerService: timer,
        focusQueueService: ref.read(focusQueueServiceProvider),
        plannerService: ref.read(havenPlannerServiceProvider),
      ),
    );
  }

  Future<void> _editFocusQueueTask(
    BuildContext context,
    FocusQueueService queue,
    FocusQueueItem item,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final updated = await TextEntryDialog.show(
      context,
      title: 'Edit task',
      confirmLabel: 'Save',
      initialValue: item.title,
      hintText: 'What needs your attention?',
      maxLength: 100,
      hideCounter: true,
    );
    if (updated != null) {
      await queue.rename(item.id, updated);
    }
  }

  Future<void> _showCompletedTasksSheet(BuildContext context) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CompletedTasksSheet(dateLabel: _dateLabel),
    );
  }

  Future<void> _captureDistraction(
    BuildContext context,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final thought = await TextEntryDialog.show(
      context,
      title: 'Park this thought',
      confirmLabel: 'Save thought',
      hintText: 'Example: Reply to Jordan after this session',
      helperText: 'Save it, then return to your focus.',
      maxLength: 140,
    );
    if (thought != null) {
      timer.captureDistraction(thought);
    }
  }

  Future<void> _showDistractionSheet(
    BuildContext context,
    TimerService timer,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DistractionParkingSheet.withHistory(
        readActiveThoughts: () =>
            ref.read(parkedThoughtStateProvider).activeThoughts,
        readCompletedThoughts: () =>
            ref.read(parkedThoughtStateProvider).completedThoughts,
        addThought: timer.captureDistraction,
        renameThought: timer.renameParkedThought,
        completeThought: timer.completeParkedThought,
        reopenThought: timer.reopenParkedThought,
        removeThoughtById: timer.removeParkedThought,
        clearThoughts: timer.clearDistractions,
        clearCompletedThoughts: timer.clearCompletedParkedThoughts,
        foregroundColor: _ink,
      ),
    );
  }

  Future<void> _showMilestonesSheet(
    BuildContext context,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final milestones = [
      FocusMilestone(
        title: 'First step',
        detail: 'Complete your first focus session.',
        unlocked: timer.completedFocusSessions >= 1,
      ),
      FocusMilestone(
        title: 'Weekly rhythm',
        detail: 'Complete 3 focus sessions in seven days.',
        unlocked: timer.weeklyFocusSessions >= 3,
      ),
      FocusMilestone(
        title: 'Momentum',
        detail: 'Complete 5 focus sessions in total.',
        unlocked: timer.completedFocusSessions >= 5,
      ),
      FocusMilestone(
        title: 'Half-hour haven',
        detail: 'Reach 30 total minutes of focus.',
        unlocked: timer.totalFocusSeconds >= 30 * 60,
      ),
      FocusMilestone(
        title: 'Century club',
        detail: 'Reach 100 total minutes of focus.',
        unlocked: timer.totalFocusSeconds >= 100 * 60,
      ),
      FocusMilestone(
        title: 'Steady flame',
        detail: 'Build a 3-day focus streak.',
        unlocked: timer.currentStreak >= 3,
      ),
      FocusMilestone(
        title: 'Deep roots',
        detail: 'Build a 7-day focus streak.',
        unlocked: timer.currentStreak >= 7,
      ),
      FocusMilestone(
        title: 'Goal getter',
        detail: 'Reach your daily focus goal.',
        unlocked: timer.hasReachedDailyGoal,
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => FocusMilestonesSheet(milestones: milestones),
    );
  }

  Future<void> _showFocusHistory(
    BuildContext context,
    TimerService timer,
    List<FocusSession> focusHistory,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => FocusHistorySheet(
        completedSessions: timer.completedFocusSessions,
        weeklyFocusSeconds: timer.weeklyFocusSeconds,
        weeklyFocusSessions: timer.weeklyFocusSessions,
        lastSevenDaysFocusSeconds: List<int>.unmodifiable(
          timer.lastSevenDaysFocusSeconds,
        ),
        sessions: List<FocusSession>.unmodifiable(focusHistory),
        onCopySummary: () => _copyFocusHistory(sheetContext, timer),
      ),
    );
  }

  Future<void> _chooseDailyGoal(
    BuildContext context,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final value = await TextEntryDialog.show(
      context,
      title: 'Set daily focus goal',
      confirmLabel: 'Save goal',
      initialValue: timer.dailyGoalMinutes.toString(),
      hintText: 'Minutes per day',
      helperText: 'Choose between 5 and 480 minutes',
      keyboardType: TextInputType.number,
      textCapitalization: TextCapitalization.none,
    );
    final minutes = value == null ? null : int.tryParse(value);
    if (minutes != null) {
      timer.setDailyGoalMinutes(minutes);
    }
  }

  Future<void> _createJournalEntry(
    BuildContext context,
    JournalState journalState,
    JournalService journal,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final draft = await JournalEntryDialog.show(
      context,
      initialMood: _journalMoods.first,
      initialReflection: '',
      prompt: journalState.dailyPrompt,
      moods: _journalMoods,
    );
    if (draft == null) return;

    await journal.addEntry(mood: draft.mood, reflection: draft.reflection);
  }

  Future<void> _editJournalEntry(
    BuildContext context,
    JournalEntry entry,
    JournalState journalState,
    JournalService journal,
  ) async {
    if (!_canOpenOverlay(context)) return;
    final draft = await JournalEntryDialog.show(
      context,
      initialMood: entry.mood,
      initialReflection: entry.reflection,
      prompt: journalState.dailyPrompt,
      moods: _journalMoods,
    );
    if (draft == null) return;

    await journal.updateEntry(
      createdAt: entry.createdAt,
      mood: draft.mood,
      reflection: draft.reflection,
    );
  }

  Future<void> _showJournalSheet(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ReflectionJournalSheet(
        dateLabel: _dateLabel,
        onCreateEntry: (dialogContext) => _createJournalEntry(
          dialogContext,
          ref.read(journalStateProvider),
          ref.read(journalServiceProvider),
        ),
        onEditEntry: (dialogContext, entry) => _editJournalEntry(
          dialogContext,
          entry,
          ref.read(journalStateProvider),
          ref.read(journalServiceProvider),
        ),
      ),
    );
  }

  CoachingContext _buildCoachingContext(riverpod.WidgetRef ref) {
    final timer = ref.read(timerServiceProvider);
    final queueState = ref.read(focusQueueStateProvider);
    final journalState = ref.read(journalStateProvider);
    final parkedThoughtState = ref.read(parkedThoughtStateProvider);
    return CoachingContext(
      focusTask: timer.focusTask,
      focusProfile: ref.read(focusProfileTypeProvider),
      todayFocusMinutes: timer.todayFocusMinutes,
      dailyGoalMinutes: timer.dailyGoalMinutes,
      queueRemaining: queueState.activeItems.length,
      nextQueueTask: queueState.activeItems.isEmpty
          ? null
          : queueState.activeItems.first.title,
      recentMood: journalState.mostCommonRecentMood,
      parkedThoughtCount: parkedThoughtState.activeThoughts.length,
      isTimerRunning: timer.isRunning,
    );
  }

  Future<void> _showCoachingSheet(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          CoachingSheet(contextBuilder: () => _buildCoachingContext(ref)),
    );
  }

  Future<void> _showHavenActionSheet(
    BuildContext context,
    riverpod.WidgetRef ref,
    TimerService timer,
  ) async {
    if (!_canOpenOverlay(context)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => HavenActionSheet(
        timerService: timer,
        focusQueueService: ref.read(focusQueueServiceProvider),
        voiceTranscriptionService: ref.read(voiceTranscriptionServiceProvider),
        onOpenSurface: (surface) async {
          if (!context.mounted) return;
          switch (surface) {
            case HavenActionSurface.focusQueue:
              return _showFocusQueueSheet(context, timer, ref);
            case HavenActionSurface.havenPlan:
              return _showHavenPlanSheet(context, timer, ref);
            case HavenActionSurface.smartReset:
              if (!timer.canOfferSmartReset) return;
              return _resetTimer(context, ref, timer);
            case HavenActionSurface.localCoach:
              return _showCoachingSheet(context, ref);
            case HavenActionSurface.settings:
              return _showAccountSheet(context, ref);
          }
        },
      ),
    );
  }

  Future<bool> _requestHavenWindowAccess(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    final connected = await ref
        .read(havenWindowPlatformControllerProvider)
        .requestReadOnlyAccess();
    if (!connected && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calendar access could not be reviewed right now. Nothing was connected.',
          ),
        ),
      );
    }
    return connected;
  }

  Future<bool> _refreshHavenWindowAvailability(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    final refreshed = await ref
        .read(havenWindowPlatformControllerProvider)
        .refreshAvailability();
    if (!refreshed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calendar availability could not be refreshed. No schedule or timer was changed.',
          ),
        ),
      );
    }
    return refreshed;
  }

  Future<bool> _holdHavenWindow(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    final currentSuggestion = ref.refresh(havenWindowSuggestionProvider);
    if (!currentSuggestion.hasOpening) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This window is no longer current enough to hold. Refresh only if you want to check again.',
            ),
          ),
        );
      }
      return false;
    }

    final held = await ref
        .read(havenWindowHoldServiceProvider)
        .hold(currentSuggestion);
    if (!held && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This window could not be held. No calendar event or reminder was created.',
          ),
        ),
      );
    }
    return held;
  }

  Future<bool> _releaseHavenWindowHold(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    final released = await ref.read(havenWindowHoldServiceProvider).release();
    if (!released && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The private reminder could not be released right now. No calendar event was changed.',
          ),
        ),
      );
    }
    return released;
  }

  Future<bool> _beginArrivedHavenWindow(
    BuildContext context,
    riverpod.WidgetRef ref,
  ) async {
    final timer = ref.read(timerServiceProvider);
    if (!timer.canStartHavenPlan) return false;

    final released = await ref.read(havenWindowHoldServiceProvider).release();
    if (!released || !context.mounted) {
      if (!released && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Focus did not begin because the private hold could not be released.',
            ),
          ),
        );
      }
      return false;
    }
    if (!timer.canStartHavenPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The timer changed, so this Haven Window was allowed to pass.',
          ),
        ),
      );
      return false;
    }

    timer.start();
    final started = timer.isRunning;
    if (started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus began by your choice.')),
      );
    }
    return started;
  }

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final timer = ref.read(timerServiceProvider);
    final session = ref.watch(timerSessionStateProvider);
    final havenLoop = ref.watch(havenLoopStateProvider);
    final completedFocusIdentity = timer.completedFocusIdentity;
    final focusHistory = ref.watch(timerFocusHistoryProvider);
    final summary = ref.watch(timerSummaryStateProvider);
    final havenJourney = ref.watch(havenJourneyStateProvider);
    final havenRhythm = ref.watch(havenRhythmInsightProvider);
    final rhythmReflection = ref.watch(havenRhythmReflectionConnectionProvider);
    final forecastReflection = ref.watch(
      focusForecastReflectionConnectionProvider,
    );
    final focusForecast = ref.watch(focusForecastProvider);
    final havenWindow = ref.watch(havenWindowSuggestionProvider);
    final calendarAvailability = ref.watch(privateCalendarAvailabilityProvider);
    final havenWindowHold = ref.watch(havenWindowHoldStateProvider);
    final canBeginFreshFocus = ref.watch(timerCanBeginFreshFocusProvider);
    final havenWindowController = ref.watch(
      havenWindowPlatformControllerProvider,
    );
    final livingLantern = ref.watch(livingLanternStateProvider);
    final focusShield = ref.watch(focusShieldStateProvider);
    final focusShieldController = ref.watch(
      focusShieldPlatformControllerProvider,
    );
    final isSignedIn = ref.watch(authIsSignedInProvider);
    final queueRemaining = ref.watch(focusQueueRemainingCountProvider);
    final parkedThoughtState = ref.watch(parkedThoughtStateProvider);
    final activeThoughtCount = parkedThoughtState.activeThoughts.length;
    final completedThoughtCount = parkedThoughtState.completedThoughts.length;
    final hasParkedThoughts =
        activeThoughtCount > 0 || completedThoughtCount > 0;
    final sessionColor = _sessionColor(context, session.sessionType);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Focus Coach',
        onPressed: () => _showCoachingSheet(context, ref),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('Coach'),
      ),
      appBar: AppBar(
        title: const Text('FocusHaven'),
        actions: [
          IconButton(
            key: const ValueKey('openHavenActions'),
            icon: const Icon(Icons.bolt_outlined),
            tooltip: 'Haven actions',
            onPressed: () => _showHavenActionSheet(context, ref, timer),
          ),
          IconButton(
            icon: const Icon(Icons.self_improvement_outlined),
            tooltip: 'Mindful pause',
            onPressed: () => _showBreathingPause(context),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Reflection journal',
            onPressed: () => _showJournalSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Daily focus reminder',
            onPressed: () => _showReminderSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: isSignedIn ? 'Account' : 'Sign in',
            onPressed: () => _showAccountSheet(context, ref),
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
                                onSelected: (selected) {
                                  if (selected) timer.selectSession(type);
                                },
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
                      const SizedBox(height: 18),
                      LivingLanternCard(state: livingLantern),
                      const SizedBox(height: 12),
                      FocusShieldCard(
                        state: focusShield,
                        onAction: focusShieldController.isStarted
                            ? (action) {
                                focusShieldController.performAction(action);
                              }
                            : null,
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
                        if (havenLoop.hasSelectedTask &&
                            !session.isComplete) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Linked to Focus Queue • you keep control',
                            key: const ValueKey('haven-loop-linked-task'),
                            style: TextStyle(
                              color: sessionColor.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: () =>
                              _showFocusQueueSheet(context, timer, ref),
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
                        TextButton.icon(
                          key: const ValueKey('open-haven-ai-planner'),
                          onPressed: () =>
                              _showHavenPlannerSheet(context, ref, timer),
                          icon: const Icon(Icons.route_outlined, size: 18),
                          label: const Text('Plan a goal'),
                        ),
                        if (timer.canStartHavenPlan)
                          TextButton.icon(
                            key: const ValueKey('open-haven-plan'),
                            onPressed: () =>
                                _showHavenPlanSheet(context, timer, ref),
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                            ),
                            label: const Text('Plan my next session'),
                          ),
                        if (session.isRunning || hasParkedThoughts)
                          TextButton.icon(
                            onPressed: () => session.isRunning
                                ? _captureDistraction(context, timer)
                                : _showDistractionSheet(context, timer, ref),
                            icon: Icon(
                              session.isRunning
                                  ? Icons.add_task_outlined
                                  : Icons.bookmark_outline,
                              size: 18,
                            ),
                            label: Text(
                              session.isRunning
                                  ? 'Park a distraction${activeThoughtCount == 0 ? '' : ' • $activeThoughtCount saved'}'
                                  : activeThoughtCount == 0
                                  ? 'Review $completedThoughtCount completed thought${completedThoughtCount == 1 ? '' : 's'}'
                                  : 'Review $activeThoughtCount parked thought${activeThoughtCount == 1 ? '' : 's'}${completedThoughtCount == 0 ? '' : ' • $completedThoughtCount completed'}',
                            ),
                          ),
                      ],
                      const SizedBox(height: 30),
                      TimerCountdown(
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
                        Column(
                          children: [
                            if (session.sessionType == SessionType.focus) ...[
                              if (havenLoop.canResolveCompletion &&
                                  havenLoop.selectedItem != null) ...[
                                HavenLoopCompletionCard(
                                  taskTitle: havenLoop.selectedItem!.title,
                                  onMarkComplete: ref
                                      .read(havenLoopServiceProvider)
                                      .markSelectedTaskComplete,
                                  onKeepForLater: ref
                                      .read(havenLoopServiceProvider)
                                      .keepSelectedTaskForLater,
                                ),
                                const SizedBox(height: 14),
                              ] else if (havenLoop.isInitialized &&
                                  completedFocusIdentity != null) ...[
                                FocusSessionReflectionCard(
                                  selected: session.completedFocusSessionFit,
                                  onSelected: (sessionFit) {
                                    timer.reflectOnCompletedFocus(
                                      completedFocusIdentity,
                                      sessionFit,
                                    );
                                  },
                                ),
                                if (rhythmReflection != null) ...[
                                  const SizedBox(height: 12),
                                  HavenRhythmReflectionConnectionCard(
                                    connection: rhythmReflection,
                                  ),
                                ],
                                if (forecastReflection != null) ...[
                                  const SizedBox(height: 12),
                                  FocusForecastReflectionConnectionCard(
                                    connection: forecastReflection,
                                  ),
                                ],
                                const SizedBox(height: 14),
                              ],
                            ],
                            FilledButton.icon(
                              onPressed:
                                  !havenLoop.isInitialized ||
                                      havenLoop.canResolveCompletion
                                  ? null
                                  : () => _beginNextSession(timer),
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
                            ),
                            if (!havenLoop.isInitialized)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Checking for a linked Focus Queue task…',
                                  key: ValueKey('haven-loop-restoring'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            else if (havenLoop.canResolveCompletion)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Choose the task outcome above before moving on.',
                                  key: ValueKey(
                                    'haven-loop-resolution-required',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                          ],
                        )
                      else
                        Wrap(
                          key: const ValueKey('timer-actions'),
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            IconButton.outlined(
                              key: const ValueKey('timer-reset-action'),
                              onPressed: () => _resetTimer(context, ref, timer),
                              tooltip: 'Reset timer',
                              icon: const Icon(Icons.replay),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('timer-primary-action'),
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
                              child: StatCard(
                                icon: Icons.today_outlined,
                                value: '${summary.todayFocusMinutes}m',
                                label: 'today',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.local_fire_department_outlined,
                                value: '${summary.currentStreak}',
                                label: 'day streak',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.check_circle_outline,
                                value: '${summary.completedFocusSessions}',
                                label: 'completed',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        HavenJourneyCard(state: havenJourney),
                        const SizedBox(height: 14),
                        HavenRhythmCard(insight: havenRhythm),
                        const SizedBox(height: 14),
                        FocusForecastCard(forecast: focusForecast),
                        const SizedBox(height: 14),
                        HavenWindowCard(
                          suggestion: havenWindow,
                          availabilityStatus: calendarAvailability.status,
                          isPlatformStarted: havenWindowController.isStarted,
                          isHeld: havenWindowHold.isHeld,
                          hasArrived: havenWindowHold.hasArrived,
                          heldStartsAtUtc: havenWindowHold.startsAtUtc,
                          heldEndsAtUtc: havenWindowHold.endsAtUtc,
                          isHoldUpdating: havenWindowHold.isUpdating,
                          onRequestReadOnlyAccess:
                              havenWindowController.isStarted
                              ? () => _requestHavenWindowAccess(context, ref)
                              : null,
                          onRefreshAvailability: havenWindowController.isStarted
                              ? () => _refreshHavenWindowAvailability(
                                  context,
                                  ref,
                                )
                              : null,
                          onHoldWindow:
                              havenWindowController.isStarted &&
                                  calendarAvailability.status ==
                                      PrivateCalendarAvailabilityStatus.ready &&
                                  havenWindow.hasOpening
                              ? () => _holdHavenWindow(context, ref)
                              : null,
                          onReleaseHold: havenWindowHold.isHeld
                              ? () => _releaseHavenWindowHold(context, ref)
                              : null,
                          onBeginFocus:
                              havenWindowHold.hasArrived && canBeginFreshFocus
                              ? () => _beginArrivedHavenWindow(context, ref)
                              : null,
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
                        CloudBackupActions(
                          isSignedIn: isSignedIn,
                          backup: timer.cloudBackup,
                          restoreBackup: timer.restoreCloudBackup,
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
