import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
import '../providers/app_providers.dart';

class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({super.key});

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet> {
  Map<int, String> _weekdayLabels(BuildContext context) => <int, String>{
    DateTime.monday: context.l10n.weekdayMondayShort,
    DateTime.tuesday: context.l10n.weekdayTuesdayShort,
    DateTime.wednesday: context.l10n.weekdayWednesdayShort,
    DateTime.thursday: context.l10n.weekdayThursdayShort,
    DateTime.friday: context.l10n.weekdayFridayShort,
    DateTime.saturday: context.l10n.weekdaySaturdayShort,
    DateTime.sunday: context.l10n.weekdaySundayShort,
  };

  late final Set<int> _selectedWeekdays;
  String? _activeAction;

  bool get _isActionInProgress => _activeAction != null;

  @override
  void initState() {
    super.initState();
    _selectedWeekdays = ref.read(reminderStateProvider).weekdays.toSet();
  }

  bool _beginAction(String action) {
    if (_isActionInProgress) return false;
    setState(() => _activeAction = action);
    return true;
  }

  void _finishAction() {
    if (mounted) setState(() => _activeAction = null);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleReminder(bool enabled, TimeOfDay currentTime) async {
    if (!_beginAction(enabled ? 'enable' : 'disable')) return;
    final l10n = context.l10n;
    try {
      final reminderService = ref.read(reminderServiceProvider);

      if (!enabled) {
        await reminderService.disableDailyReminder();
        return;
      }

      final selected = await showTimePicker(
        context: context,
        initialTime: currentTime,
      );
      if (selected == null || !mounted) return;

      final scheduled = await reminderService.setDailyReminder(
        selected,
        weekdays: _selectedWeekdays,
      );
      if (!mounted || scheduled) return;

      _showMessage(l10n.reminderAllowNotificationsSchedule);
    } catch (_) {
      _showMessage(l10n.reminderSettingsFailed);
    } finally {
      _finishAction();
    }
  }

  Future<void> _chooseTimeAndSchedule(TimeOfDay currentTime) async {
    if (!_beginAction('schedule')) return;
    final l10n = context.l10n;
    try {
      final selected = await showTimePicker(
        context: context,
        initialTime: currentTime,
      );
      if (selected == null || !mounted) return;

      final scheduled = await ref
          .read(reminderServiceProvider)
          .setDailyReminder(selected, weekdays: _selectedWeekdays);
      if (!mounted) return;

      final formattedTime = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(selected);
      _showMessage(
        scheduled
            ? l10n.reminderScheduledReceipt(formattedTime)
            : l10n.reminderAllowNotificationsSchedule,
      );
    } catch (_) {
      _showMessage(l10n.reminderSettingsFailed);
    } finally {
      _finishAction();
    }
  }

  Future<void> _sendTestNotification() async {
    if (!_beginAction('test')) return;
    final l10n = context.l10n;
    try {
      final notifications = ref.read(notificationServiceProvider);
      final permitted = await notifications.requestPermissions();
      if (!mounted) return;

      if (!permitted) {
        _showMessage(l10n.reminderAllowNotificationsTest);
        return;
      }

      await notifications.showTestNotification();
    } catch (_) {
      _showMessage(l10n.reminderTestFailed);
    } finally {
      _finishAction();
    }
  }

  void _toggleWeekday(int weekday, bool selected) {
    if (!selected && _selectedWeekdays.length == 1) return;

    setState(() {
      if (selected) {
        _selectedWeekdays.add(weekday);
      } else {
        _selectedWeekdays.remove(weekday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminderState = ref.watch(reminderStateProvider);
    final activeAction = _activeAction;
    final isBusy = activeAction != null;
    final weekdayLabels = _weekdayLabels(context);
    final scheduledDays = weekdayLabels.entries
        .where((entry) => reminderState.weekdays.contains(entry.key))
        .map((entry) => entry.value)
        .join(context.l10n.reminderDaySeparator);
    final formattedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(reminderState.time);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.reminderTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.reminderDescription,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  reminderState.isEnabled
                      ? Icons.event_available_outlined
                      : Icons.event_busy_outlined,
                ),
                title: Text(
                  reminderState.isEnabled
                      ? context.l10n.reminderScheduled
                      : context.l10n.reminderNotScheduled,
                ),
                subtitle: Text(
                  reminderState.isEnabled
                      ? context.l10n.reminderTimeAndDays(
                          formattedTime,
                          scheduledDays,
                        )
                      : formattedTime,
                ),
                trailing: Switch(
                  value: reminderState.isEnabled,
                  onChanged: isBusy
                      ? null
                      : (enabled) =>
                            _toggleReminder(enabled, reminderState.time),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.reminderRepeatOn,
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
                        selected: _selectedWeekdays.contains(entry.key),
                        onSelected: isBusy
                            ? null
                            : (selected) => _toggleWeekday(entry.key, selected),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.reminderDayGuidance,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _chooseTimeAndSchedule(reminderState.time),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  activeAction == 'schedule'
                      ? context.l10n.reminderSaving
                      : reminderState.isEnabled
                      ? context.l10n.reminderUpdateTime
                      : context.l10n.reminderChooseTime,
                ),
              ),
              TextButton.icon(
                onPressed: isBusy ? null : _sendTestNotification,
                icon: const Icon(Icons.notifications_outlined),
                label: Text(
                  activeAction == 'test'
                      ? context.l10n.reminderSendingTest
                      : context.l10n.reminderSendTest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
