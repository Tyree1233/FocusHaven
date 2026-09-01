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
import '../l10n/focus_haven_localizations.dart';
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
import '../widgets/haven_journey_completion_connection_card.dart';
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
          SnackBar(content: Text(context.l10n.focusSummaryCopyError)),
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.focusSummaryCopied)));
  }

  String _sessionLabel(BuildContext context, SessionType type) =>
      switch (type) {
        SessionType.focus => context.l10n.sessionFocus,
        SessionType.shortBreak => context.l10n.sessionShortBreak,
        SessionType.longBreak => context.l10n.sessionLongBreak,
      };

  String _sessionStatus(BuildContext context, SessionType type) =>
      switch (type) {
        SessionType.focus => context.l10n.sessionStatusFocus,
        SessionType.shortBreak => context.l10n.sessionStatusShortBreak,
        SessionType.longBreak => context.l10n.sessionStatusLongBreak,
      };

  String _sessionEncouragement(BuildContext context, SessionType type) =>
      switch (type) {
        SessionType.focus => context.l10n.sessionFocusEncouragement,
        SessionType.shortBreak => context.l10n.sessionShortBreakEncouragement,
        SessionType.longBreak => context.l10n.sessionLongBreakEncouragement,
      };

  String _sessionCompletionMessage(BuildContext context, SessionType type) =>
      switch (type) {
        SessionType.focus => context.l10n.sessionFocusCompleteMessage,
        SessionType.shortBreak => context.l10n.sessionShortBreakCompleteMessage,
        SessionType.longBreak => context.l10n.sessionLongBreakCompleteMessage,
      };

  String _beginSessionLabel(BuildContext context, SessionType type) =>
      switch (type) {
        SessionType.focus => context.l10n.timerBeginFocus,
        SessionType.shortBreak => context.l10n.timerBeginShortBreak,
        SessionType.longBreak => context.l10n.timerBeginLongBreak,
      };

  String _durationLabel(BuildContext context, int seconds) {
    if (seconds < 60) {
      return context.l10n.timerDurationSecondsUpper(seconds);
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return context.l10n.timerDurationMinutesUpper(minutes);
    }
    return '${context.l10n.timerDurationMinutesUpper(minutes)} '
        '${context.l10n.timerDurationSecondsShortUpper(remainingSeconds)}';
  }

  String _focusSessionLabel(BuildContext context, int seconds) {
    if (seconds < 60) {
      return context.l10n.focusSessionSeconds(seconds);
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return context.l10n.focusSessionMinutes(minutes);
    }
    return context.l10n.focusSessionMinutesSeconds(minutes, remainingSeconds);
  }

  String _shortDurationLabel(BuildContext context, int seconds) {
    if (seconds < 60) return context.l10n.durationSecondsShort('$seconds');
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds == 0
        ? context.l10n.durationMinutesShort(minutes)
        : '${context.l10n.durationMinutesShort(minutes)} '
              '${context.l10n.durationSecondsShort('$remainingSeconds')}';
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now().toLocal();
    if (DateUtils.isSameDay(localDate, now)) return context.l10n.dateToday;
    if (DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      return context.l10n.dateYesterday;
    }
    return MaterialLocalizations.of(context).formatShortDate(localDate);
  }

  String _dashboardDateLabel(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now().toLocal();
    if (DateUtils.isSameDay(localDate, now)) return context.l10n.dateToday;
    if (DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      return context.l10n.dateYesterday;
    }
    return MaterialLocalizations.of(context).formatShortMonthDay(localDate);
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
        sessionLabel: _sessionLabel(context, timer.sessionType),
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

    final havenLoop = ref.read(havenLoopServiceProvider);
    final recoveryTicket = havenLoop.beginSmartResetRecovery();

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
      builder: (_) => SmartResetSheet(
        plan: plan,
        preservesSelectedTask: recoveryTicket != null,
      ),
    );
    if (!context.mounted) return;
    if (!timer.canOfferSmartReset) {
      if (recoveryTicket != null) {
        havenLoop.finishSmartResetRecovery(recoveryTicket);
      }
      return;
    }

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

    final preserved = recoveryTicket == null
        ? null
        : havenLoop.finishSmartResetRecovery(recoveryTicket);
    if (preserved == false && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.havenLoopRecoveryUnlinked)),
      );
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
        SnackBar(content: Text(context.l10n.privacyPolicyOpenFailed)),
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
      title: context.l10n.deleteCloudBackupTitle,
      message: context.l10n.deleteCloudBackupMessage,
      cancelLabel: context.l10n.deleteCloudBackupKeep,
      confirmLabel: context.l10n.deleteCloudBackupConfirm,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final deleted = await ref.read(cloudSyncServiceProvider).deleteFocusData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? context.l10n.deleteCloudBackupSucceeded
              : context.l10n.deleteCloudBackupFailed,
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
      title: context.l10n.deleteLocalDataTitle,
      message: context.l10n.deleteLocalDataMessage,
      cancelLabel: context.l10n.deleteLocalDataKeep,
      confirmLabel: context.l10n.deleteLocalDataConfirm,
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
      title: context.l10n.deleteAccountTitle,
      message: context.l10n.deleteAccountMessage,
      cancelLabel: context.l10n.deleteAccountKeep,
      confirmLabel: context.l10n.deleteAccountConfirm,
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
      title: context.l10n.focusHistoryClearTitle,
      message: context.l10n.focusHistoryClearMessage,
      cancelLabel: context.l10n.focusHistoryKeep,
      confirmLabel: context.l10n.focusHistoryClearConfirm,
      isDestructive: true,
    );
    if (shouldClear) {
      timer.clearFocusHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.focusHistoryCleared)),
        );
      }
    }
  }

  Future<void> _editFocusTask(BuildContext context, TimerService timer) async {
    if (!_canOpenOverlay(context)) return;
    final task = await TextEntryDialog.show(
      context,
      title: context.l10n.focusIntentionTitle,
      confirmLabel: context.l10n.actionSave,
      initialValue: timer.focusTask,
      hintText: context.l10n.focusIntentionHint,
      cancelLabel: null,
      clearLabel: context.l10n.actionClear,
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
      SnackBar(content: Text(context.l10n.havenPlanStarted(plan.focusMinutes))),
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
      title: context.l10n.focusQueueEditTitle,
      confirmLabel: context.l10n.focusQueueEditSave,
      initialValue: item.title,
      hintText: context.l10n.focusQueueTaskHint,
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
      builder: (sheetContext) => CompletedTasksSheet(
        dateLabel: (date) => _dateLabel(sheetContext, date),
      ),
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
        title: context.l10n.milestoneFirstStepTitle,
        detail: context.l10n.milestoneFirstStepDetail,
        unlocked: timer.completedFocusSessions >= 1,
      ),
      FocusMilestone(
        title: context.l10n.milestoneWeeklyRhythmTitle,
        detail: context.l10n.milestoneWeeklyRhythmDetail,
        unlocked: timer.weeklyFocusSessions >= 3,
      ),
      FocusMilestone(
        title: context.l10n.milestoneMomentumTitle,
        detail: context.l10n.milestoneMomentumDetail,
        unlocked: timer.completedFocusSessions >= 5,
      ),
      FocusMilestone(
        title: context.l10n.milestoneHalfHourTitle,
        detail: context.l10n.milestoneHalfHourDetail,
        unlocked: timer.totalFocusSeconds >= 30 * 60,
      ),
      FocusMilestone(
        title: context.l10n.milestoneCenturyTitle,
        detail: context.l10n.milestoneCenturyDetail,
        unlocked: timer.totalFocusSeconds >= 100 * 60,
      ),
      FocusMilestone(
        title: context.l10n.milestoneSteadyFlameTitle,
        detail: context.l10n.milestoneSteadyFlameDetail,
        unlocked: timer.currentStreak >= 3,
      ),
      FocusMilestone(
        title: context.l10n.milestoneDeepRootsTitle,
        detail: context.l10n.milestoneDeepRootsDetail,
        unlocked: timer.currentStreak >= 7,
      ),
      FocusMilestone(
        title: context.l10n.milestoneGoalGetterTitle,
        detail: context.l10n.milestoneGoalGetterDetail,
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
      title: context.l10n.dailyGoalDialogTitle,
      confirmLabel: context.l10n.dailyGoalSave,
      initialValue: timer.dailyGoalMinutes.toString(),
      hintText: context.l10n.dailyGoalMinutesHint,
      helperText: context.l10n.dailyGoalRangeHelp,
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
        dateLabel: (date) => _dateLabel(sheetContext, date),
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
        SnackBar(content: Text(context.l10n.havenWindowAccessReviewFailed)),
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
        SnackBar(content: Text(context.l10n.havenWindowRefreshFailed)),
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
          SnackBar(content: Text(context.l10n.havenWindowStaleHold)),
        );
      }
      return false;
    }

    final held = await ref
        .read(havenWindowHoldServiceProvider)
        .hold(currentSuggestion);
    if (!held && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.havenWindowHoldFailed)),
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
        SnackBar(content: Text(context.l10n.havenWindowReleaseFailed)),
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
          SnackBar(content: Text(context.l10n.havenWindowBeginReleaseFailed)),
        );
      }
      return false;
    }
    if (!timer.canStartHavenPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.havenWindowTimerChanged)),
      );
      return false;
    }

    timer.start();
    final started = timer.isRunning;
    if (started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.havenWindowFocusBegan)),
      );
    }
    return started;
  }

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final l10n = context.l10n;
    final timer = ref.read(timerServiceProvider);
    final session = ref.watch(timerSessionStateProvider);
    final havenLoop = ref.watch(havenLoopStateProvider);
    final completedFocusIdentity = timer.completedFocusIdentity;
    final focusHistory = ref.watch(timerFocusHistoryProvider);
    final summary = ref.watch(timerSummaryStateProvider);
    final havenJourney = ref.watch(havenJourneyStateProvider);
    final journeyCompletion = ref.watch(
      havenJourneyCompletionConnectionProvider,
    );
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
        tooltip: l10n.coachTitle,
        onPressed: () => _showCoachingSheet(context, ref),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(l10n.coachTitle),
      ),
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const ValueKey('openHavenActions'),
            icon: const Icon(Icons.bolt_outlined),
            tooltip: l10n.havenActionTitle,
            onPressed: () => _showHavenActionSheet(context, ref, timer),
          ),
          IconButton(
            icon: const Icon(Icons.self_improvement_outlined),
            tooltip: l10n.breathingTitle,
            onPressed: () => _showBreathingPause(context),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: l10n.journalTitle,
            onPressed: () => _showJournalSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: l10n.reminderDashboardTooltip,
            onPressed: () => _showReminderSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: isSignedIn
                ? l10n.accountDashboardTooltip
                : l10n.accountSignInDashboardTooltip,
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
                                label: Text(_sessionLabel(context, type)),
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
                            ? l10n.sessionComplete
                            : _sessionStatus(context, session.sessionType),
                        style: TextStyle(
                          color: sessionColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        session.isComplete
                            ? _sessionCompletionMessage(
                                context,
                                session.sessionType,
                              )
                            : _sessionEncouragement(
                                context,
                                session.sessionType,
                              ),
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
                                ? l10n.focusIntentionSet
                                : session.focusTask,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (havenLoop.hasSelectedTask &&
                            !session.isComplete) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.focusQueueLinked,
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
                                ? l10n.focusQueueOpen
                                : l10n.focusQueueCount(queueRemaining),
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('open-haven-ai-planner'),
                          onPressed: () =>
                              _showHavenPlannerSheet(context, ref, timer),
                          icon: const Icon(Icons.route_outlined, size: 18),
                          label: Text(l10n.havenPlannerTitle),
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
                            label: Text(l10n.havenPlanEntry),
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
                        durationLabel: (seconds) =>
                            _durationLabel(context, seconds),
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
                                Text(
                                  l10n.resumeSessionTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  l10n.resumeSessionDescription,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: timer.discardPendingSession,
                                        child: Text(
                                          l10n.resumeSessionStartFresh,
                                        ),
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
                                        child: Text(l10n.actionResume),
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
                                if (journeyCompletion != null) ...[
                                  const SizedBox(height: 12),
                                  HavenJourneyCompletionConnectionCard(
                                    connection: journeyCompletion,
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
                                    ? l10n.timerTakeBreak
                                    : l10n.timerBeginFocus,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: sessionColor,
                                foregroundColor: _ink,
                                minimumSize: const Size(210, 54),
                              ),
                            ),
                            if (!havenLoop.isInitialized)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  l10n.timerLinkedTaskRestoring,
                                  key: const ValueKey('haven-loop-restoring'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              )
                            else if (havenLoop.canResolveCompletion)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  l10n.timerTaskOutcomeRequired,
                                  key: const ValueKey(
                                    'haven-loop-resolution-required',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
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
                              tooltip: l10n.timerResetTooltip,
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
                                    ? l10n.actionPauseTimer
                                    : _beginSessionLabel(
                                        context,
                                        session.sessionType,
                                      ),
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
                        label: Text(l10n.timerCustomDuration),
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
                                value: l10n.statMinutesCompact(
                                  summary.todayFocusMinutes,
                                ),
                                label: l10n.statToday,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.local_fire_department_outlined,
                                value: '${summary.currentStreak}',
                                label: l10n.statDayStreak,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.check_circle_outline,
                                value: '${summary.completedFocusSessions}',
                                label: l10n.statCompleted,
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
                            label: Text(l10n.dashboardMilestones),
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
                                    Expanded(
                                      child: Text(
                                        l10n.dailyGoalTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _chooseDailyGoal(context, timer),
                                      child: Text(l10n.actionChange),
                                    ),
                                  ],
                                ),
                                Text(
                                  l10n.dailyGoalProgress(
                                    _shortDurationLabel(
                                      context,
                                      timer.todayFocusSeconds,
                                    ),
                                    l10n.durationMinutesShort(
                                      summary.dailyGoalMinutes,
                                    ),
                                  ),
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
                                      ? l10n.dailyGoalComplete
                                      : l10n.dailyGoalRemaining(
                                          ((summary.dailyGoalMinutes * 60 -
                                                      timer.todayFocusSeconds) /
                                                  60)
                                              .ceil(),
                                        ),
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
                                    Expanded(
                                      child: Text(
                                        l10n.dailyChallengeTitle,
                                        style: const TextStyle(
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
                                      ? l10n.dailyChallengeComplete
                                      : l10n.dailyChallengeTarget(
                                          summary.dailyChallengeTarget,
                                        ),
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
                                l10n.recentFocusTitle,
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
                                child: Text(l10n.actionViewAll),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (focusHistory.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.recentFocusEmpty,
                              style: const TextStyle(color: Colors.white60),
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
                                          context,
                                          session.durationSeconds,
                                        ),
                                  ),
                                  subtitle: session.focusTask == null
                                      ? null
                                      : Text(
                                          _focusSessionLabel(
                                            context,
                                            session.durationSeconds,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                  trailing: Text(
                                    _dashboardDateLabel(
                                      context,
                                      session.completedAt,
                                    ),
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
                              label: Text(l10n.focusHistoryClear),
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
